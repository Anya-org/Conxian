import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const planPath = "deployments/default.simnet-plan.yaml";

function hashPlan() {
  return createHash("sha256").update(readFileSync(planPath)).digest("hex");
}

const before = hashPlan();
const result = spawnSync(
  "npx",
  ["vitest", "run", "--config", "vitest.deployment-evidence.config.ts", "--pool=threads"],
  { stdio: "inherit" },
);
const after = hashPlan();

if (before !== after) {
  console.error(`Focused deployment evidence tests mutated ${planPath}.`);
  console.error(`before=${before}`);
  console.error(`after=${after}`);
  process.exitCode = 1;
} else if (result.status !== 0) {
  process.exitCode = result.status ?? 1;
}
