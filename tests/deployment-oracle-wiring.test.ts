// @vitest-environment node
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { parseDocument } from "yaml";

const DEPLOYER = "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P";
const SOURCE_PRICE_SCALE = "u8";
const ORACLE_AGGREGATOR = `${DEPLOYER}.oracle-aggregator`;
const TWAP_ORACLE = `${DEPLOYER}.twap-oracle`;
const ORACLE_FACADE = `${DEPLOYER}.oracle`;
const LIQUIDITY_MANAGER = `${DEPLOYER}.liquidity-manager`;

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
});
