import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { canonicalDeploymentPlan } from "./setup-test-env";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
// The test wrapper snapshots this file before Simnet starts. Direct runs use
// setup-test-env's pre-initialization snapshot instead of the mutable worktree.
const immutableCanonicalPlanPath = process.env.CONXIAN_CANONICAL_SIMNET_PLAN_PATH;
const canonicalSimnetPlanPath =
  immutableCanonicalPlanPath && existsSync(immutableCanonicalPlanPath)
    ? immutableCanonicalPlanPath
    : undefined;
const releasePlanGeneratorPath = path.join(repoRoot, "scripts/gen-deployment-plans.py");
const activeReleaseArtifactPaths = [
  "deployments/full-system.testnet-plan.yaml",
  "deployments/full-system.mainnet-plan.yaml",
  "deployments/mainnet-manifest-v1.yaml",
].map((relativePath) => path.join(repoRoot, relativePath));
const generatedReleaseArtifactPaths = activeReleaseArtifactPaths.slice(0, 2);
const legacyReleaseArtifactPath = path.join(repoRoot, "deployments/mainnet-release-plan.yaml");
const releaseArtifactPaths = [...activeReleaseArtifactPaths, legacyReleaseArtifactPath];
const issue506ProductionContracts = [
  ["auto-compounder", "contracts/yield/auto-compounder.clar"],
  ["cxd-staking", "contracts/yield/cxd-staking.clar"],
] as const;

const alexProductionNames = /\b(?:alex-adapter|alex-reserve-pool|alex-swap-helper|swap-helper-v1-03)\b/i;
const localOnlyIntegrationPath = /contracts\/integrations\/(?:simnet|stubs)\//;

function readArtifact(filePath: string): string {
  return readFileSync(filePath, "utf8");
}

function readCanonicalSimnetPlan(): string {
  return canonicalSimnetPlanPath === undefined
    ? canonicalDeploymentPlan
    : readArtifact(canonicalSimnetPlanPath);
}

type PublishEntry = {
  line: number;
  indent: number;
  contractName?: string;
  path?: string;
};

function stripQuotes(value: string): string {
  return value.replace(/^['"]|['"]$/g, "");
}

function extractContractPublishEntries(content: string): PublishEntry[] {
  const entries: PublishEntry[] = [];
  let currentEntry: PublishEntry | undefined;

  for (const [index, line] of content.split("\n").entries()) {
    const publishMatch = line.match(
      /^(\s*)-\s+(?:contract-publish:|transaction-type:\s+emulated-contract-publish)\s*$/,
    );
    if (publishMatch) {
      if (currentEntry) entries.push(currentEntry);
      currentEntry = { line: index + 1, indent: publishMatch[1].length };
      continue;
    }

    if (!currentEntry) continue;

    const trimmed = line.trim();
    const indent = line.match(/^\s*/)?.[0].length ?? 0;
    if (trimmed && indent <= currentEntry.indent && !trimmed.startsWith("#")) {
      entries.push(currentEntry);
      currentEntry = undefined;
      continue;
    }

    const nameMatch = line.match(/^\s+contract-name:\s*(\S+)\s*$/);
    if (nameMatch) currentEntry.contractName = stripQuotes(nameMatch[1]);

    const pathMatch = line.match(/^\s+path:\s*(\S+)\s*$/);
    if (pathMatch) currentEntry.path = stripQuotes(pathMatch[1]);
  }

  if (currentEntry) entries.push(currentEntry);
  return entries;
}

function extractManifestPhases(content: string): Map<string, number> {
  const phaseLines = content.split("\n").flatMap((line, index) => {
    const match = line.match(/^\s+- id:\s*(\d+)\s*$/);
    return match ? [{ line: index + 1, phase: Number(match[1]) }] : [];
  });

  return new Map(
    extractContractPublishEntries(content).flatMap((entry) => {
      const priorPhases = phaseLines.filter((candidate) => candidate.line < entry.line);
      const phase = priorPhases[priorPhases.length - 1]?.phase;
      return entry.contractName === undefined || phase === undefined
        ? []
        : [[entry.contractName, phase] as const];
    }),
  );
}

describe("ALEX release wiring guard", () => {
  it("keeps the ALEX adapter and helper/reserve stubs available only to simnet", () => {
    const simnetPlan = readCanonicalSimnetPlan();
    const simnetPublishes = extractContractPublishEntries(simnetPlan);

    for (const [name, localPath] of [
      ["alex-adapter", "contracts/integrations/simnet/alex-adapter.clar"],
      ["alex-reserve-pool", "contracts/integrations/stubs/alex-reserve-pool.clar"],
      ["alex-swap-helper", "contracts/integrations/stubs/alex-swap-helper-v1-03.clar"],
    ]) {
      expect(
        simnetPublishes.some((entry) => entry.contractName === name && entry.path === localPath),
        `default.simnet-plan.yaml must pair ${name} with ${localPath} in the same publish transaction/block`,
      ).toBe(true);
      expect(
        existsSync(path.join(repoRoot, localPath)),
        `simnet fixture for ${name} is missing at ${localPath}`,
      ).toBe(true);
    }
  });

  it("keeps production artifacts free of local integration paths and ALEX wiring", () => {
    for (const artifactPath of releaseArtifactPaths) {
      const relativePath = path.relative(repoRoot, artifactPath);
      const artifact = readArtifact(artifactPath);

      expect(
        artifact,
        `${relativePath} must not publish simnet or stub integration paths`,
      ).not.toMatch(localOnlyIntegrationPath);
      expect(
        artifact,
        `${relativePath} must not publish, call, or register a gated ALEX contract`,
      ).not.toMatch(alexProductionNames);
    }
  });

  it("requires publish paths in active release artifacts and verifies each path exists", () => {
    for (const artifactPath of activeReleaseArtifactPaths) {
      const relativePath = path.relative(repoRoot, artifactPath);
      const publishEntries = extractContractPublishEntries(readArtifact(artifactPath));
      const publishPaths = publishEntries.filter(
        (entry): entry is PublishEntry & { path: string } => Boolean(entry.path),
      );

      expect(
        publishPaths.length,
        `${relativePath} must contain at least one contract-publish path`,
      ).toBeGreaterThan(0);

      for (const entry of publishPaths) {
        expect(
          existsSync(path.join(repoRoot, entry.path)),
          `${relativePath}:${entry.line} references missing contract-publish path ${entry.path}`,
        ).toBe(true);
      }
    }
  });

  it("keeps both Issue #506 production contracts present and dependency-ordered", () => {
    for (const artifactPath of activeReleaseArtifactPaths) {
      const relativePath = path.relative(repoRoot, artifactPath);
      const publishEntries = extractContractPublishEntries(readArtifact(artifactPath));

      for (const [contractName, contractPath] of issue506ProductionContracts) {
        expect(
          publishEntries.some((entry) => entry.contractName === contractName && entry.path === contractPath),
          `${relativePath} must keep Issue #506 contract ${contractName} paired with ${contractPath}`,
        ).toBe(true);
      }

      const present = issue506ProductionContracts.map(([contractName]) =>
        publishEntries.some((entry) => entry.contractName === contractName),
      );
      expect(
        present[0],
        `${relativePath} must not include only one of the paired Issue #506 production contracts`,
      ).toBe(present[1]);
    }

    const manifestPath = path.join(repoRoot, "deployments/mainnet-manifest-v1.yaml");
    const phases = extractManifestPhases(readArtifact(manifestPath));
    expect(phases.get("cxd-staking")).toBeGreaterThan(phases.get("cxd-token") ?? -1);
    expect(phases.get("cxd-staking")).toBeGreaterThan(phases.get("regulatory-adapter") ?? -1);
  });

  it("keeps generated release plans in sync without writing to the worktree", () => {
    const beforeCheck = new Map(
      generatedReleaseArtifactPaths
        .map((artifactPath) => [artifactPath, readArtifact(artifactPath)]),
    );
    const temporaryDirectory = mkdtempSync(path.join(tmpdir(), "conxian-alex-release-"));
    const temporarySimnetPlanPath = path.join(temporaryDirectory, "default.simnet-plan.yaml");
    writeFileSync(temporarySimnetPlanPath, readCanonicalSimnetPlan());

    const result = (() => {
      try {
        return spawnSync(
          "python3",
          [releasePlanGeneratorPath, "--check", "--simnet-plan", temporarySimnetPlanPath],
          { cwd: repoRoot, encoding: "utf8" },
        );
      } finally {
        rmSync(temporaryDirectory, { recursive: true, force: true });
      }
    })();

    expect(
      result.error,
      `generator check could not start: ${result.error?.message ?? "unknown error"}`,
    ).toBeUndefined();
    expect(
      result.status,
      `generator check failed:\n${result.stdout}\n${result.stderr}`,
    ).toBe(0);

    for (const [artifactPath, beforeContents] of beforeCheck) {
      expect(
        readArtifact(artifactPath),
        `${path.relative(repoRoot, artifactPath)} changed while running generator --check`,
      ).toBe(beforeContents);
    }
  });

  it("keeps the legacy mainnet release artifact explicitly disabled and empty", () => {
    const artifact = readArtifact(legacyReleaseArtifactPath);

    expect(artifact).toContain("name: Legacy Mainnet Release Plan (disabled; no-op)");
    expect(artifact).toMatch(/^plan:\n  batches: \[\]\s*$/m);
    expect(extractContractPublishEntries(artifact)).toHaveLength(0);
  });
});
