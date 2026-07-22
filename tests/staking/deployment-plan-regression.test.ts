import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

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

function contractNames(path: string): string[] {
  const text = readFileSync(resolve(repoRoot, path), "utf8");
  return [...text.matchAll(/contract-name:\s+([a-z0-9-]+)/g)].map((match) => match[1]);
}

describe("issue 501 deployment plans", () => {
  it.each(plans)("contains the issue-501 contracts in dependency order: %s", (plan) => {
    const names = contractNames(plan);

    for (const contract of issue501Contracts) {
      expect(names, `${plan} is missing ${contract}`).toContain(contract);
    }

    expect(names.indexOf("stacking-traits")).toBeLessThan(names.indexOf("native-stacking-operator"));
    expect(names.indexOf("stacking-traits")).toBeLessThan(names.indexOf("dual-stacking-orchestrator"));
  });
});
