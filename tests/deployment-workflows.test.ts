// @vitest-environment node
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { parseDocument } from "yaml";
import { describe, expect, it } from "vitest";

const repoRoot = join(import.meta.dirname, "..");
const testnetWorkflowPath = join(repoRoot, ".github/workflows/deploy-testnet.yml");
const mainnetWorkflowPath = join(repoRoot, ".github/workflows/deploy-mainnet.yml");

function readWorkflow(path: string): string {
  return readFileSync(path, "utf8");
}

describe("deployment workflow safety gates", () => {
  it("parses both workflows as YAML and contains no Clarinet broadcast step", () => {
    for (const path of [testnetWorkflowPath, mainnetWorkflowPath]) {
      const source = readWorkflow(path);
      const document = parseDocument(source, { uniqueKeys: true });
      expect(document.errors, path).toHaveLength(0);
      expect(source).not.toContain("clarinet deployments apply");
      expect(source).not.toMatch(/DEPLOY(?:ER)?_(?:PRIVKEY|MNEMONIC)/);
      expect(source).toContain("plan-only");
      expect(source).toContain("blocked before signing");
      expect(source).toContain("issue #531");
      expect(source).toContain("test:release-plan-validation");
    }
  });

  it("keeps testnet push/manual paths preflight-only and gates explicit non-dry requests", () => {
    const source = readWorkflow(testnetWorkflowPath);
    expect(source).toContain("branches:\n      - dev");
    expect(source).toContain("workflow_dispatch:");
    expect(source).toContain("default: true");
    expect(source).toContain("expected_plan_sha256");
    expect(source).toContain("github.event_name == 'workflow_dispatch' && inputs.dry_run == false");
    expect(source).toContain("No mnemonic, signer, broadcast, or deployment proof was used");
  });

  it("keeps mainnet manual-only, exact-confirmed, hash-checked, and identity-blocked", () => {
    const source = readWorkflow(mainnetWorkflowPath);
    expect(source).toContain("workflow_dispatch:");
    expect(source).not.toMatch(/^\s+push:/m);
    expect(source).toContain('required: true');
    expect(source).toContain('inputs.confirm == \'DEPLOY_MAINNET\'');
    expect(source).toContain("expected_plan_sha256");
    expect(source).toContain("deployments/full-system.mainnet-plan.sha256");
    expect(source).toContain("SP*|SM*");
    expect(source).toContain("Current mainnet plan identity is unresolved");
    expect(source).toContain("if: ${{ !inputs.dry_run }}");
    expect(source).toContain("automatic");
  });
});
