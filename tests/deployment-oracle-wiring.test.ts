// @vitest-environment node
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { parseDocument } from "yaml";

const DEPLOYER = "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P";
const SOURCE_PRICE_SCALE = "u8";
const ORACLE_AGGREGATOR = `${DEPLOYER}.oracle-aggregator`;
const TWAP_ORACLE = `${DEPLOYER}.twap-oracle`;
const ORACLE_FACADE = `${DEPLOYER}.oracle`;
const LIQUIDITY_MANAGER = `${DEPLOYER}.liquidity-manager`;
const WRONG_SENDER = "ST00000000000000000000000000000000000000000";
const REPO_ROOT = join(import.meta.dirname, "..");
const GENERATOR_PATH = join(REPO_ROOT, "scripts/gen-deployment-plans.py");
const SIMNET_PLAN_SOURCE = execFileSync(
  "git",
  ["show", "HEAD:deployments/default.simnet-plan.yaml"],
  { cwd: REPO_ROOT, encoding: "utf8" },
);

const FORBIDDEN_SOURCE_INDEPENDENT_METHODS = new Set([
  "set-source-authorized",
  "submit-price",
  "set-price",
  "register-asset",
  "update-price-observation",
]);

type RawPublish = {
  "contract-name": string;
  "expected-sender": string;
};

type RawCall = {
  "contract-id": string;
  "expected-sender": string;
  method: string;
  parameters: string[];
  cost?: number;
};

type RawTransaction = {
  "contract-publish"?: RawPublish;
  "contract-call"?: RawCall;
};

type RawBatch = {
  id: number;
  transactions: RawTransaction[];
};

type RawPlan = {
  network: "testnet" | "mainnet";
  deployer: string;
  plan: {
    batches: RawBatch[];
  };
};

type CallRecord = RawCall & {
  batchId: number;
  transactionIndex: number;
};

const PLAN_PATHS = [
  join(import.meta.dirname, "../deployments/full-system.testnet-plan.yaml"),
  join(import.meta.dirname, "../deployments/full-system.mainnet-plan.yaml"),
];

function readPlan(path: string): RawPlan {
  const document = parseDocument(readFileSync(path, "utf8"), { uniqueKeys: true });
  if (document.errors.length > 0) {
    throw new Error(`generated plan is not valid YAML: ${path}`);
  }
  return document.toJS() as RawPlan;
}

function collectCalls(plan: RawPlan): CallRecord[] {
  const calls: CallRecord[] = [];
  for (const batch of plan.plan.batches) {
    for (const [transactionIndex, transaction] of batch.transactions.entries()) {
      if (transaction["contract-call"] !== undefined) {
        calls.push({
          ...transaction["contract-call"],
          batchId: batch.id,
          transactionIndex,
        });
      }
    }
  }
  return calls;
}

function collectPublishes(plan: RawPlan): Array<RawPublish & { batchId: number; transactionIndex: number }> {
  const publishes: Array<RawPublish & { batchId: number; transactionIndex: number }> = [];
  for (const batch of plan.plan.batches) {
    for (const [transactionIndex, transaction] of batch.transactions.entries()) {
      if (transaction["contract-publish"] !== undefined) {
        publishes.push({
          ...transaction["contract-publish"],
          batchId: batch.id,
          transactionIndex,
        });
      }
    }
  }
  return publishes;
}

function position(record: { batchId: number; transactionIndex: number }): [number, number] {
  return [record.batchId, record.transactionIndex];
}

function isBefore(left: { batchId: number; transactionIndex: number }, right: { batchId: number; transactionIndex: number }): boolean {
  const [leftBatch, leftIndex] = position(left);
  const [rightBatch, rightIndex] = position(right);
  return leftBatch < rightBatch || (leftBatch === rightBatch && leftIndex < rightIndex);
}

function clonePlan(plan: RawPlan): RawPlan {
  return JSON.parse(JSON.stringify(plan)) as RawPlan;
}

function locateCall(plan: RawPlan, contractId: string, method: string): {
  batch: RawBatch;
  transactionIndex: number;
  call: RawCall;
} {
  for (const batch of plan.plan.batches) {
    const transactionIndex = batch.transactions.findIndex(
      (transaction) => transaction["contract-call"]?.["contract-id"] === contractId
        && transaction["contract-call"]?.method === method,
    );
    if (transactionIndex !== -1) {
      const call = batch.transactions[transactionIndex]["contract-call"];
      if (call !== undefined) {
        return { batch, transactionIndex, call };
      }
    }
  }
  throw new Error(`could not locate ${contractId}.${method}`);
}

const PYTHON_VALIDATOR_HARNESS = `
import importlib.util
import json
import sys

spec = importlib.util.spec_from_file_location("gen_deployment_plans", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

try:
    module.validate_oracle_wiring(json.load(sys.stdin))
except Exception as exc:
    print(str(exc), file=sys.stderr)
    raise SystemExit(1)
`;

function runPythonValidator(plan: RawPlan) {
  return spawnSync(
    "python3",
    ["-c", PYTHON_VALIDATOR_HARNESS, GENERATOR_PATH],
    {
      cwd: REPO_ROOT,
      input: JSON.stringify(plan),
      encoding: "utf8",
    },
  );
}

function expectValidatorReject(plan: RawPlan, message: string): void {
  const result = runPythonValidator(plan);
  expect(result.error).toBeUndefined();
  expect(result.status, result.stderr).toBe(1);
  expect(result.stderr).toContain(message);
}

describe("generated deployment oracle wiring", () => {
  it.each(PLAN_PATHS)("keeps the source-independent oracle profile safe: %s", (planPath) => {
    const plan = readPlan(planPath);
    const calls = collectCalls(plan);
    const publishes = collectPublishes(plan);
    const finalBatchId = plan.plan.batches.at(-1)?.id;

    expect(plan.deployer).toBe(DEPLOYER);
    expect(finalBatchId).toBeTypeOf("number");

    const scaleCalls = calls.filter((call) => call.method === "set-price-decimals");
    expect(scaleCalls).toHaveLength(2);
    expect(scaleCalls.map((call) => call["contract-id"])).toEqual([ORACLE_AGGREGATOR, TWAP_ORACLE]);
    expect(scaleCalls.map((call) => call.parameters)).toEqual([
      [SOURCE_PRICE_SCALE],
      [SOURCE_PRICE_SCALE],
    ]);

    const setOracleCalls = calls.filter((call) => call.method === "set-oracle");
    expect(setOracleCalls).toHaveLength(1);
    expect(setOracleCalls[0]["contract-id"]).toBe(LIQUIDITY_MANAGER);
    expect(setOracleCalls[0].parameters).toEqual([`'${ORACLE_FACADE}'`]);

    const oracleWiringCalls = [...scaleCalls, ...setOracleCalls];
    expect(oracleWiringCalls.every((call) => call["expected-sender"] === DEPLOYER)).toBe(true);
    expect(oracleWiringCalls.every((call) => call.batchId === finalBatchId)).toBe(true);
    expect(isBefore(scaleCalls[0], scaleCalls[1])).toBe(true);
    expect(isBefore(scaleCalls[1], setOracleCalls[0])).toBe(true);

    const oraclePublish = publishes.filter((publish) => publish["contract-name"] === "oracle");
    expect(oraclePublish).toHaveLength(1);
    expect(oraclePublish[0]["expected-sender"]).toBe(DEPLOYER);
    expect(isBefore(oraclePublish[0], setOracleCalls[0])).toBe(true);

    const forbiddenCalls = calls.filter((call) => FORBIDDEN_SOURCE_INDEPENDENT_METHODS.has(call.method));
    expect(forbiddenCalls).toEqual([]);
  });

  it.each(PLAN_PATHS)("accepts the checked-in plan through the Python validator: %s", (planPath) => {
    const result = runPythonValidator(readPlan(planPath));

    expect(result.error).toBeUndefined();
    expect(result.status, result.stderr).toBe(0);
  });

  it("rejects mutated oracle wiring plans through the Python validator", () => {
    const baseline = readPlan(PLAN_PATHS[0]);

    const missingScale = clonePlan(baseline);
    const scaleToRemove = locateCall(missingScale, ORACLE_AGGREGATOR, "set-price-decimals");
    scaleToRemove.batch.transactions.splice(scaleToRemove.transactionIndex, 1);
    expectValidatorReject(missingScale, "exactly one ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P.oracle-aggregator.set-price-decimals");

    const missingSetOracle = clonePlan(baseline);
    const setOracleToRemove = locateCall(missingSetOracle, LIQUIDITY_MANAGER, "set-oracle");
    setOracleToRemove.batch.transactions.splice(setOracleToRemove.transactionIndex, 1);
    expectValidatorReject(missingSetOracle, "exactly one ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P.liquidity-manager.set-oracle");

    const duplicateScale = clonePlan(baseline);
    const scaleToDuplicate = locateCall(duplicateScale, TWAP_ORACLE, "set-price-decimals");
    const duplicateScaleFinalBatch = duplicateScale.plan.batches[duplicateScale.plan.batches.length - 1];
    if (duplicateScaleFinalBatch === undefined) {
      throw new Error("baseline plan has no final batch");
    }
    duplicateScaleFinalBatch.transactions.splice(
      scaleToDuplicate.transactionIndex + 1,
      0,
      { "contract-call": { ...scaleToDuplicate.call } },
    );
    expectValidatorReject(duplicateScale, "exactly one ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P.twap-oracle.set-price-decimals call; found 2");

    const wrongScale = clonePlan(baseline);
    locateCall(wrongScale, ORACLE_AGGREGATOR, "set-price-decimals").call.parameters = ["u6"];
    expectValidatorReject(wrongScale, "parameters mismatch for ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P.oracle-aggregator.set-price-decimals");

    const wrongSender = clonePlan(baseline);
    locateCall(wrongSender, LIQUIDITY_MANAGER, "set-oracle").call["expected-sender"] = WRONG_SENDER;
    expectValidatorReject(wrongSender, "sender mismatch for ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P.liquidity-manager.set-oracle");

    const wrongBatch = clonePlan(baseline);
    const setOracleToMove = locateCall(wrongBatch, LIQUIDITY_MANAGER, "set-oracle");
    const [setOracleTransaction] = setOracleToMove.batch.transactions.splice(setOracleToMove.transactionIndex, 1);
    wrongBatch.plan.batches[0].transactions.push(setOracleTransaction);
    expectValidatorReject(wrongBatch, "must be in final batch");

    const wrongOrder = clonePlan(baseline);
    const finalBatch = wrongOrder.plan.batches[wrongOrder.plan.batches.length - 1];
    if (finalBatch === undefined) {
      throw new Error("baseline plan has no final batch");
    }
    const firstScale = locateCall(wrongOrder, ORACLE_AGGREGATOR, "set-price-decimals");
    const secondScale = locateCall(wrongOrder, TWAP_ORACLE, "set-price-decimals");
    [finalBatch.transactions[firstScale.transactionIndex], finalBatch.transactions[secondScale.transactionIndex]] = [
      finalBatch.transactions[secondScale.transactionIndex],
      finalBatch.transactions[firstScale.transactionIndex],
    ];
    expectValidatorReject(wrongOrder, "oracle wiring calls are out of order");

    const noncanonicalPrincipal = clonePlan(baseline);
    locateCall(noncanonicalPrincipal, LIQUIDITY_MANAGER, "set-oracle").call.parameters = [`'${ORACLE_AGGREGATOR}'`];
    expectValidatorReject(noncanonicalPrincipal, "parameters mismatch for ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P.liquidity-manager.set-oracle");

    const forbiddenProviderMethod = clonePlan(baseline);
    const forbiddenMethodFinalBatch = forbiddenProviderMethod.plan.batches[forbiddenProviderMethod.plan.batches.length - 1];
    if (forbiddenMethodFinalBatch === undefined) {
      throw new Error("baseline plan has no final batch");
    }
    forbiddenMethodFinalBatch.transactions.push({
      "contract-call": {
        "contract-id": ORACLE_AGGREGATOR,
        "expected-sender": DEPLOYER,
        method: "submit-price",
        parameters: ["u1"],
        cost: 10000,
      },
    });
    expectValidatorReject(forbiddenProviderMethod, "must not configure providers, submit prices");
  });

  it("executes the generator check against the checked-in plans", () => {
    const temporaryDirectory = mkdtempSync(join(tmpdir(), "conxian-oracle-wiring-"));
    const simnetPlanPath = join(temporaryDirectory, "default.simnet-plan.yaml");

    try {
      writeFileSync(simnetPlanPath, SIMNET_PLAN_SOURCE);
      const result = spawnSync("python3", [GENERATOR_PATH, "--check", "--simnet-plan", simnetPlanPath], {
        cwd: REPO_ROOT,
        encoding: "utf8",
      });

      expect(result.error).toBeUndefined();
      expect(result.status, `${result.stdout}\n${result.stderr}`).toBe(0);
      expect(result.stdout).toContain("Checked-in release plans match a fresh generator run.");
    } finally {
      rmSync(temporaryDirectory, { recursive: true, force: true });
    }
  });
});
