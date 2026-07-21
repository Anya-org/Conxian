import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { describe, expect, it } from "vitest";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const simnetPlanPath = path.join(repoRoot, "deployments/default.simnet-plan.yaml");
const releaseArtifactPaths = [
  "deployments/full-system.testnet-plan.yaml",
  "deployments/full-system.mainnet-plan.yaml",
  "deployments/mainnet-manifest-v1.yaml",
  "deployments/mainnet-release-plan.yaml",
].map((relativePath) => path.join(repoRoot, relativePath));

const alexProductionNames = /\b(?:alex-adapter|alex-reserve-pool|alex-swap-helper)\b/i;
const localOnlyIntegrationPath = /contracts\/integrations\/(?:simnet|stubs)\//;

function readArtifact(filePath: string): string {
  return readFileSync(filePath, "utf8");
}

function extractContractPublishPaths(content: string): Array<{ line: number; path: string }> {
  const paths: Array<{ line: number; path: string }> = [];
  let publishIndent = -1;

  for (const [index, line] of content.split("\n").entries()) {
    const publishMatch = line.match(/^(\s*)-\s+contract-publish:\s*$/);
    if (publishMatch) {
      publishIndent = publishMatch[1].length;
      continue;
    }

    if (publishIndent < 0) continue;

    const trimmed = line.trim();
    const indent = line.match(/^\s*/)?.[0].length ?? 0;
    if (trimmed && indent <= publishIndent && !trimmed.startsWith("#")) {
      publishIndent = -1;
      continue;
    }

    const pathMatch = line.match(/^\s+path:\s*(\S+)\s*$/);
    if (pathMatch) {
      paths.push({
        line: index + 1,
        path: pathMatch[1].replace(/^['"]|['"]$/g, ""),
      });
    }
  }

  return paths;
}

describe("ALEX release wiring guard", () => {
  it("keeps the ALEX adapter and helper/reserve stubs available only to simnet", () => {
    const simnetPlan = readArtifact(simnetPlanPath);

    for (const [name, localPath] of [
      ["alex-adapter", "contracts/integrations/simnet/alex-adapter.clar"],
      ["alex-reserve-pool", "contracts/integrations/stubs/alex-reserve-pool.clar"],
      ["alex-swap-helper", "contracts/integrations/stubs/alex-swap-helper-v1-03.clar"],
    ]) {
      expect(
        simnetPlan,
        `default.simnet-plan.yaml must publish ${name} for local simulation`,
      ).toContain(`contract-name: ${name}`);
      expect(
        simnetPlan,
        `default.simnet-plan.yaml must keep ${name} on its local path`,
      ).toContain(`path: ${localPath}`);
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

  it("verifies every release contract-publish path exists in the repository", () => {
    for (const artifactPath of releaseArtifactPaths) {
      const relativePath = path.relative(repoRoot, artifactPath);
      const publishPaths = extractContractPublishPaths(readArtifact(artifactPath));

      for (const entry of publishPaths) {
        expect(
          existsSync(path.join(repoRoot, entry.path)),
          `${relativePath}:${entry.line} references missing contract-publish path ${entry.path}`,
        ).toBe(true);
      }
    }
  });
});
