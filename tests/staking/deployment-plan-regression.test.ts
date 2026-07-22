import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { validateIssue501RuntimePlan } from "../issue501-plan-validation";

const repoRoot = resolve(__dirname, "../..");
const issue501Contracts = [
  "stacking-traits",
  "native-stacking-operator",
  "dual-stacking-orchestrator",
];
const plans = [
  "deployments/default.simnet-plan.yaml",
  "deployments/full-system.testnet-plan.yaml",
  "deployments/full-system.mainnet-plan.yaml",
];

function planText(path: string): string {
  return readFileSync(resolve(repoRoot, path), "utf8");
}

function contractNames(path: string): string[] {
  const text = planText(path);
  return [...text.matchAll(/contract-name:\s+([a-z0-9-]+)/g)].map((match) => match[1]);
}

function contractEntry(path: string, name: string): string {
  const text = planText(path);
  const entries = [...text.matchAll(/^\s*contract-name:\s+([a-z0-9-]+)\s*$/gm)];
  const index = entries.findIndex((entry) => entry[1] === name);
  if (index < 0) throw new Error(`${path} is missing ${name}`);
  const start = entries[index].index ?? 0;
  const end = entries[index + 1]?.index ?? text.length;
  return text.slice(start, end);
}

describe("issue 501 deployment plans", () => {
  it.each(plans)("contains the issue-501 contracts in dependency order: %s", (plan) => {
    const names = contractNames(plan);

    for (const contract of issue501Contracts) {
      expect(names, `${plan} is missing ${contract}`).toContain(contract);
    }

    expect(names.indexOf("stacking-traits")).toBeLessThan(names.indexOf("native-stacking-operator"));
    expect(names.indexOf("stacking-traits")).toBeLessThan(names.indexOf("dual-stacking-orchestrator"));

    for (const contract of issue501Contracts) {
      expect(contractEntry(plan, contract), `${plan} ${contract} must use Clarity 4`)
        .toMatch(/clarity-version:\s+4/);
      if (plan !== plans[0]) {
        expect(contractEntry(plan, contract), `${plan} ${contract} must use epoch 3.0`)
          .toMatch(/epoch:\s+3\.0/);
      }
    }
  });

  it("generates release clarity versions from the active Clarinet manifest", () => {
    const generator = readFileSync(resolve(repoRoot, "scripts/gen-deployment-plans.py"), "utf8");
    expect(generator).toContain("load_manifest_clarity_versions");
    expect(generator).toContain('repo_root / "Clarinet.toml"');
  });

  it("checks SDK runtime artifact compatibility without pinning stale SDK versions", () => {
    const sdkPlan = planText(plans[0]).replace(/clarity-version:\s+4/g, "clarity-version: 1");
    expect(() => validateIssue501RuntimePlan(sdkPlan)).not.toThrow();

    expect(() => validateIssue501RuntimePlan(sdkPlan.replace(
      "contract-name: stacking-traits",
      "contract-name: unrelated-trait",
    ))).toThrow("missing issue-501 contract");

    expect(() => validateIssue501RuntimePlan([
      "contract-name: native-stacking-operator",
      "contract-name: stacking-traits",
      "contract-name: dual-stacking-orchestrator",
    ].join("\n"))).toThrow("orders stacking-traits after native-stacking-operator");
  });
});
