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
const generatorResult = spawnSync("python3", ["scripts/gen-deployment-plans.py", "--check"], {
  stdio: "inherit",
});
const after = hashPlan();

let failed = false;
if (before !== after) {
  console.error(`Focused deployment evidence tests mutated ${planPath}.`);
  console.error(`before=${before}`);
  console.error(`after=${after}`);
  failed = true;
}
if (result.error) {
  console.error(`Focused deployment evidence tests failed to start: ${result.error.message}`);
  failed = true;
} else if (result.status !== 0) {
  failed = true;
}
if (generatorResult.error) {
  console.error(`Deployment plan generator check failed to start: ${generatorResult.error.message}`);
  failed = true;
} else if (generatorResult.status !== 0) {
  failed = true;
}

if (failed) process.exitCode = 1;
