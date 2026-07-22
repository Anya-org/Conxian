// @vitest-environment node
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const repoRoot = resolve(".");

function read(relativePath: string): string {
  return readFileSync(resolve(repoRoot, relativePath), "utf8");
}

describe("deployment verification drift guards", () => {
  it("keeps testnet from automatically invoking mainnet", () => {
    const workflow = read(".github/workflows/deploy-testnet.yml");

    expect(workflow).not.toContain("promote-to-mainnet");
    expect(workflow).not.toContain("gh workflow run deploy-mainnet.yml");
    expect(workflow).not.toContain("DEPLOY_MAINNET");
  });

  it("requires the verifier and evidence manifest in both deployment workflows", () => {
    for (const workflowPath of [
      ".github/workflows/deploy-testnet.yml",
      ".github/workflows/deploy-mainnet.yml",
    ]) {
      const workflow = read(workflowPath);
      const normalizedWorkflow = workflow.toLowerCase();
      expect(workflow).toContain("evidence_manifest");
      expect(workflow).toContain("scripts/verify-deployment-evidence.ts");
      expect(workflow).toContain("Confirmed receipt evidence is required");
      expect(normalizedWorkflow).toContain(
        "plans, workflow success, and broadcast-only ids are not evidence",
      );
      expect(workflow).toContain("no deployment is verified");
    }
  });

  it("keeps mainnet explicit and manual", () => {
    const workflow = read(".github/workflows/deploy-mainnet.yml");

    expect(workflow).toContain("workflow_dispatch:");
    expect(workflow).toContain("inputs.confirm == 'DEPLOY_MAINNET'");
    expect(workflow).toContain("environment: mainnet");
  });

  it("does not let the broadcast-only helper claim verified deployment", () => {
    const script = read("scripts/deploy-testnet.ts");

    expect(script).toContain("Broadcast complete; no deployment is verified.");
    expect(script).toContain("scripts/verify-deployment-evidence.ts");
    expect(script).not.toContain("Deployment complete!");
  });

  it("keeps the runbook and documentation state explicit about the unresolved gate", () => {
    const runbook = read("docs/DEPLOYMENT_EVIDENCE_RUNBOOK.md");
    const documentationState = read("docs/DOCUMENTATION_STATE.md");

    for (const issueNumber of ["#527", "#528", "#529", "#530"]) {
      expect(runbook).toContain(issueNumber);
    }
    expect(runbook).toContain("does not claim partnership deployment readiness");
    expect(documentationState).toContain("CON-1539");
    expect(documentationState).toContain("no deployment readiness is claimed");
  });
});
