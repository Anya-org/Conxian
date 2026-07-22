// @vitest-environment node
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const repoRoot = resolve(".");

function read(relativePath: string): string {
  return readFileSync(resolve(repoRoot, relativePath), "utf8");
}

function parseWorkflow(relativePath: string): Record<string, any> {
  const output = execFileSync(
    "ruby",
    [
      "-ryaml",
      "-rjson",
      "-e",
      'puts JSON.generate(YAML.load_file(ARGV.fetch(0)))',
      resolve(repoRoot, relativePath),
    ],
    { encoding: "utf8" },
  );
  const parsed = JSON.parse(output) as Record<string, any>;
  return {
    ...parsed,
    on: parsed.on ?? parsed["true"] ?? parsed[true as unknown as string],
  };
}

describe("deployment verification drift guards", () => {
  it("preserves automatic testnet deployment on push to dev without promotion", () => {
    const workflow = read(".github/workflows/deploy-testnet.yml");
    const parsed = parseWorkflow(".github/workflows/deploy-testnet.yml");

    expect(parsed.on.push.branches).toContain("dev");
    expect(workflow).not.toContain("promote-to-mainnet");
    expect(workflow).not.toContain("gh workflow run deploy-mainnet.yml");
    expect(workflow).not.toContain("evidence_manifest");
    expect(workflow).toContain("verification pending");
    expect(workflow).toContain("verify-deployment-evidence.yml");
  });

  it("keeps deployment and evidence verification as separate phases", () => {
    const testnet = read(".github/workflows/deploy-testnet.yml");
    const mainnet = read(".github/workflows/deploy-mainnet.yml");
    const verifier = read(".github/workflows/verify-deployment-evidence.yml");

    for (const workflow of [testnet, mainnet]) {
      expect(workflow).not.toContain("scripts/verify-deployment-evidence.ts");
      expect(workflow).toContain("verification pending");
      expect(workflow).toContain("deployment-attempt.json");
      expect(workflow).toContain("JSON.parse");
      expect(workflow).not.toContain("grep -q");
    }

    expect(verifier).toContain("scripts/verify-deployment-evidence.ts");
    expect(verifier).toContain("--expected-network");
    expect(verifier).toContain("--expected-deployer");
    expect(verifier).toContain("--expected-git-commit");
    expect(verifier).toContain("--expected-plan-path");
    expect(verifier).toContain("--expected-plan-sha256");
    expect(verifier).toContain("declared evidence entries verified");
    expect(verifier).toContain("complete plan coverage is not claimed");
  });

  it("adds per-network concurrency and bounded job timeouts", () => {
    const testnet = parseWorkflow(".github/workflows/deploy-testnet.yml");
    const mainnet = parseWorkflow(".github/workflows/deploy-mainnet.yml");
    const verifier = parseWorkflow(".github/workflows/verify-deployment-evidence.yml");

    expect(testnet.concurrency["cancel-in-progress"]).toBe(false);
    expect(mainnet.concurrency["cancel-in-progress"]).toBe(false);
    expect(verifier.concurrency["cancel-in-progress"]).toBe(false);
    expect(testnet.jobs.validate["timeout-minutes"]).toBeGreaterThan(0);
    expect(testnet.jobs["deploy-testnet"]["timeout-minutes"]).toBeGreaterThan(0);
    expect(mainnet.jobs["validate-confirmation"]["timeout-minutes"]).toBeGreaterThan(0);
    expect(mainnet.jobs["validate-protocol"]["timeout-minutes"]).toBeGreaterThan(0);
    expect(mainnet.jobs["deploy-mainnet"]["timeout-minutes"]).toBeGreaterThan(0);
    expect(verifier.jobs.verify["timeout-minutes"]).toBeGreaterThan(0);
  });

  it("makes an incorrect mainnet confirmation an explicit failure", () => {
    const workflow = read(".github/workflows/deploy-mainnet.yml");

    expect(workflow).toContain("validate-confirmation");
    expect(workflow).toContain("requires confirm=DEPLOY_MAINNET");
    expect(workflow).not.toContain("if: ${{ inputs.confirm == 'DEPLOY_MAINNET' }}");
    expect(workflow).toContain("workflow_dispatch:");
    expect(workflow).toContain("environment: mainnet");
    expect(workflow).toContain("deployer:");
    expect(workflow).toContain("Canonical SP... mainnet deployer");
    expect(workflow).toContain("Validate mainnet plan principals");
  });

  it("keeps the broadcast helper distinguishable from verification", () => {
    const script = read("scripts/deploy-testnet.ts");

    expect(script).toContain('"broadcast-complete"');
    expect(script).toContain('verification: "pending"');
    expect(script).toContain("--json");
    expect(script).toContain("REQUEST_TIMEOUT_MS");
    expect(script).toContain("No deployment is verified");
    expect(script).not.toContain("Deployment complete!");
  });

  it("keeps the evidence schema, example, and runbook aligned", () => {
    const schema = JSON.parse(read("deployment/evidence/schema/v1/deployment-evidence.schema.json")) as any;
    const example = JSON.parse(read("deployment/evidence/examples/testnet.example.json")) as any;
    const runbook = read("docs/DEPLOYMENT_EVIDENCE_RUNBOOK.md");
    const documentationState = read("docs/DOCUMENTATION_STATE.md");

    expect(schema.required).toEqual(expect.arrayContaining(["network", "deployer", "evidence", "contracts"]));
    expect(schema.$defs.evidenceMetadata.required).toEqual(
      expect.arrayContaining(["source", "capturedAt", "gitCommit", "planPath", "planSha256"]),
    );
    expect(example.evidence).toEqual(expect.objectContaining({
      source: "confirmed-receipts",
      gitCommit: expect.any(String),
      planPath: expect.any(String),
      planSha256: expect.any(String),
    }));
    expect(runbook).toContain("declared evidence entries verified");
    expect(runbook).toContain("complete plan coverage");
    for (const issueNumber of ["#527", "#528", "#529", "#530"]) {
      expect(runbook).toContain(issueNumber);
    }
    expect(runbook).toContain("does not claim partnership deployment readiness");
    expect(documentationState).toContain("CON-1539");
    expect(documentationState).toContain("no deployment readiness is claimed");
  });
});
