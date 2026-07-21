import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { describe, expect, it } from "vitest";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const simnetPlanPath = path.join(repoRoot, "deployments/default.simnet-plan.yaml");
const activeReleaseArtifactPaths = [
  "deployments/full-system.testnet-plan.yaml",
  "deployments/full-system.mainnet-plan.yaml",
  "deployments/mainnet-manifest-v1.yaml",
].map((relativePath) => path.join(repoRoot, relativePath));
const legacyReleaseArtifactPath = path.join(repoRoot, "deployments/mainnet-release-plan.yaml");
const releaseArtifactPaths = [...activeReleaseArtifactPaths, legacyReleaseArtifactPath];

const alexProductionNames = /\b(?:alex-adapter|alex-reserve-pool|alex-swap-helper|swap-helper-v1-03)\b/i;
const localOnlyIntegrationPath = /contracts\/integrations\/(?:simnet|stubs)\//;

function readArtifact(filePath: string): string {
  return readFileSync(filePath, "utf8");
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

describe("ALEX release wiring guard", () => {
  it("keeps the ALEX adapter and helper/reserve stubs available only to simnet", () => {
    const simnetPlan = readArtifact(simnetPlanPath);
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

  it("keeps the legacy mainnet release artifact explicitly disabled and empty", () => {
    const artifact = readArtifact(legacyReleaseArtifactPath);

    expect(artifact).toContain("name: Legacy Mainnet Release Plan (disabled; no-op)");
    expect(artifact).toMatch(/^plan:\n  batches: \[\]\s*$/m);
    expect(extractContractPublishEntries(artifact)).toHaveLength(0);
  });
});
