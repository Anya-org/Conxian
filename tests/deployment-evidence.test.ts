// @vitest-environment node
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { addressFromVersionHash, addressToString, AddressVersion } from "@stacks/transactions";
import { afterAll, describe, expect, it, vi } from "vitest";
import {
  DeploymentVerificationError,
  readDeploymentPlan,
  sha256File,
  type DeploymentEvidence,
  verifyDeploymentEvidence,
} from "../scripts/deployment/verify-evidence";

const DEPLOYER = "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P";
const CONTRACT_ID = `${DEPLOYER}.alpha`;
const PUBLISH_TXID = `0x${"a".repeat(64)}`;
const CALL_TXID = `0x${"b".repeat(64)}`;
const EXTRA_CALL_TXID = `0x${"c".repeat(64)}`;
const FIXED_TIME = new Date("2026-07-22T12:00:00.000Z");
const CALL_ARG_HEX = "0x0100000000000000000000000000000001";
const tempDirectory = mkdtempSync(join(tmpdir(), "conxian-deployment-evidence-"));
const PLAN_PATH = join(tempDirectory, "mini-plan.yaml");

function planYaml(options: {
  network?: "testnet" | "mainnet";
  deployer?: string;
  includeSecondCall?: boolean;
} = {}): string {
  const network = options.network ?? "testnet";
  const deployer = options.deployer ?? DEPLOYER;
  const contractId = `${deployer}.alpha`;
  const secondCall = options.includeSecondCall
    ? `
        - contract-call:
            contract-id: ${contractId}
            expected-sender: ${deployer}
            method: initialize
            parameters:
              - u1`
    : "";
  return `network: ${network}
deployer: ${deployer}
plan:
  batches:
    - id: 0
      transactions:
        - contract-publish:
            contract-name: alpha
            expected-sender: ${deployer}
            path: contracts/alpha.clar
        - contract-call:
            contract-id: ${contractId}
            expected-sender: ${deployer}
            method: initialize
            parameters:
              - u1${secondCall}
`;
}

function writePlan(path: string, options: Parameters<typeof planYaml>[0] = {}): void {
  writeFileSync(path, planYaml(options), "utf8");
}

const PUBLISH_ENTRY = `        - contract-publish:
            contract-name: alpha
            expected-sender: ${DEPLOYER}
            path: contracts/alpha.clar`;
const CALL_ENTRY = `        - contract-call:
            contract-id: ${CONTRACT_ID}
            expected-sender: ${DEPLOYER}
            method: initialize
            parameters:
              - u1`;

function planWithEntries(entries: string[]): string {
  return `network: testnet
deployer: ${DEPLOYER}
plan:
  batches:
    - id: 0
      transactions:
${entries.join("\n")}
`;
}

writePlan(PLAN_PATH);

afterAll(() => rmSync(tempDirectory, { recursive: true, force: true }));

function txPayload(
  txid: string,
  kind: "contract-publish" | "contract-call",
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    tx_id: txid,
    sender_address: DEPLOYER,
    canonical: true,
    is_unanchored: false,
    tx_status: "success",
    tx_type: kind === "contract-publish" ? "smart_contract" : "contract_call",
    block_hash: `0x${"c".repeat(64)}`,
    block_height: 123,
    burn_block_hash: `0x${"d".repeat(64)}`,
    burn_block_height: 456,
    block_time_iso: FIXED_TIME.toISOString(),
    burn_block_time_iso: FIXED_TIME.toISOString(),
    ...(kind === "contract-publish"
      ? { smart_contract: { contract_id: CONTRACT_ID } }
      : {
          contract_call: {
            contract_id: CONTRACT_ID,
            function_name: "initialize",
            function_signature: "(define-public (initialize (amount uint128)) (response bool uint128))",
            function_args: [
              {
                name: "amount",
                type: "uint128",
                hex: CALL_ARG_HEX,
                repr: "u1",
              },
            ],
          },
        }),
    ...overrides,
  };
}

function richInterfaceBody(): Record<string, unknown> {
  return {
    functions: [
      {
        name: "get-name",
        access: "read_only",
        args: [],
        outputs: { type: "(response (string-ascii 32) uint128)" },
        description: "Rich Hiro interface function shape",
      },
      {
        name: "initialize",
        access: "public",
        args: [{ name: "amount", type: "uint128" }],
        outputs: { type: "(response bool uint128)" },
      },
      {
        name: "private-helper",
        access: "private",
        args: [],
        outputs: { type: "bool" },
      },
    ],
    variables: [],
    maps: [],
  };
}

function mockHiroFetch(
  overrides: {
    publish?: Record<string, unknown>;
    call?: Record<string, unknown>;
    readOnly?: Record<string, unknown>;
    readOnlyStatus?: number;
    readOnlyThrows?: boolean;
    readOnlyHangs?: boolean;
    readOnlyBodyHangs?: boolean;
    publishStatus?: number;
    interfaceStatus?: number;
    interfaceBody?: Record<string, unknown>;
    additionalTransactions?: Array<{
      txid: string;
      kind: "contract-publish" | "contract-call";
      overrides?: Record<string, unknown>;
    }>;
  } = {},
): typeof fetch {
  const transactions = new Map<string, Record<string, unknown>>([
    [PUBLISH_TXID, txPayload(PUBLISH_TXID, "contract-publish", overrides.publish)],
    [CALL_TXID, txPayload(CALL_TXID, "contract-call", overrides.call)],
  ]);
  for (const transaction of overrides.additionalTransactions ?? []) {
    transactions.set(transaction.txid, txPayload(transaction.txid, transaction.kind, transaction.overrides));
  }

  return vi.fn(async (input: string | URL, init?: RequestInit) => {
    const url = new URL(String(input));
    if (url.pathname.includes("/v2/contracts/call-read/")) {
      if (overrides.readOnlyHangs) {
        return await new Promise<Response>((_resolve, reject) => {
          const signal = init?.signal;
          const timer = setTimeout(() => reject(new Error("mock read-only timeout")), 60_000);
          const onAbort = () => {
            clearTimeout(timer);
            reject(new DOMException("Aborted", "AbortError"));
          };
          signal?.addEventListener("abort", onAbort, { once: true });
        });
      }
      if (overrides.readOnlyThrows) throw new Error("provider unavailable");
      if (overrides.readOnlyBodyHangs) {
        return {
          status: overrides.readOnlyStatus ?? 200,
          json: () => new Promise<unknown>(() => {}),
        } as Response;
      }
      return new Response(JSON.stringify(overrides.readOnly ?? { okay: true, result: "0x03" }), {
        status: overrides.readOnlyStatus ?? 200,
      });
    }
    const txid = [...transactions.keys()].find((candidate) => url.pathname.endsWith(candidate));
    if (txid !== undefined) {
      const body = transactions.get(txid);
      return new Response(JSON.stringify(body), {
        status: txid === PUBLISH_TXID ? overrides.publishStatus ?? 200 : 200,
      });
    }
    if (url.pathname.includes("/v2/contracts/interface/")) {
      return new Response(JSON.stringify(overrides.interfaceBody ?? richInterfaceBody()), {
        status: overrides.interfaceStatus ?? 200,
      });
    }
    return new Response(JSON.stringify({ error: "unexpected endpoint" }), { status: 500 });
  }) as typeof fetch;
}

function baseEvidence(): DeploymentEvidence {
  return {
    schemaVersion: "1",
    evidenceStatus: "broadcast",
    coverage: "partial",
    generatedAt: FIXED_TIME.toISOString(),
    sourceCommit: "e".repeat(40),
    network: "testnet",
    deployer: DEPLOYER,
    plan: {
      path: "mini-plan.yaml",
      sha256: sha256File(PLAN_PATH),
    },
    claims: {
      scope: "checked-addresses",
      globalNonexistence: false,
    },
    contractPublications: [
      {
        kind: "contract-publish",
        planPosition: { batchId: 0, transactionIndex: 0 },
        contractName: "alpha",
        contractId: CONTRACT_ID,
        expectedSender: DEPLOYER,
        txid: PUBLISH_TXID,
      },
    ],
    contractCalls: [
      {
        kind: "contract-call",
        planPosition: { batchId: 0, transactionIndex: 1 },
        contractId: CONTRACT_ID,
        functionName: "initialize",
        expectedSender: DEPLOYER,
        txid: CALL_TXID,
      },
    ],
    interfaces: [
      {
        contractId: CONTRACT_ID,
        requiredFunctions: [
          { name: "get-name", access: "read_only" },
          { name: "initialize", access: "public" },
        ],
      },
    ],
    readOnlyChecks: [
      {
        network: "testnet",
        contractId: CONTRACT_ID,
        sender: DEPLOYER,
        functionName: "get-name",
        arguments: [],
        expectedOkay: true,
        expectedResultHex: "0x03",
      },
    ],
  };
}

async function expectVerificationError(
  evidence: unknown,
  fetcher: typeof fetch,
  code: string,
  options: Partial<Parameters<typeof verifyDeploymentEvidence>[1]> = {},
): Promise<void> {
  const result = await verifyDeploymentEvidence(evidence as DeploymentEvidence, {
    network: "testnet",
    deployer: DEPLOYER,
    baseUrl: "http://hiro.test",
    planPath: PLAN_PATH,
    fetcher,
    now: () => FIXED_TIME,
    ...options,
  });
  expect(result.ok).toBe(false);
}

describe("deployment evidence verification", () => {
  it("parses every effective testnet plan entry and blocks the unresolved mainnet identity", () => {
    const testnetPlan = readDeploymentPlan(join(import.meta.dirname, "../deployments/full-system.testnet-plan.yaml"));
    expect(testnetPlan.entries).toHaveLength(246);
    expect(testnetPlan.entries.filter((entry) => entry.kind === "contract-publish")).toHaveLength(220);
    expect(testnetPlan.entries.filter((entry) => entry.kind === "contract-call")).toHaveLength(26);

    const riskOrchestrationCalls = testnetPlan.entries.flatMap((entry) =>
      entry.kind === "contract-call" &&
      (entry.contractId.endsWith(".risk-unit") || entry.contractId.endsWith(".agent-risk"))
        ? [{ contractId: entry.contractId, functionName: entry.functionName }]
        : [],
    );
    expect(riskOrchestrationCalls).toEqual([
      { contractId: `${testnetPlan.deployer}.risk-unit`, functionName: "initialize" },
      { contractId: `${testnetPlan.deployer}.risk-unit`, functionName: "set-ops-engine" },
      { contractId: `${testnetPlan.deployer}.agent-risk`, functionName: "initialize" },
      { contractId: `${testnetPlan.deployer}.agent-risk`, functionName: "set-risk-unit" },
    ]);

    expect(() => readDeploymentPlan(join(import.meta.dirname, "../deployments/full-system.mainnet-plan.yaml"))).toThrowError(
      expect.objectContaining({ code: "network-mismatch" }),
    );
  });

  it("fails closed on unsupported, multiple, and malformed transaction entries", () => {
    const unsupportedPath = join(tempDirectory, "unsupported-kind-plan.yaml");
    writeFileSync(unsupportedPath, planWithEntries(["        - contract-deploy: true"]), "utf8");
    expect(() => readDeploymentPlan(unsupportedPath)).toThrowError(
      expect.objectContaining({
        code: "PLAN_MALFORMED",
        message: expect.stringContaining("0:0"),
      }),
    );

    const emptyEntryPath = join(tempDirectory, "empty-transaction-plan.yaml");
    writeFileSync(emptyEntryPath, planWithEntries(["        - {}"]), "utf8");
    expect(() => readDeploymentPlan(emptyEntryPath)).toThrowError(
      expect.objectContaining({
        code: "PLAN_MALFORMED",
        message: expect.stringContaining("0:0"),
      }),
    );

    const extraKindPath = join(tempDirectory, "extra-kind-plan.yaml");
    writeFileSync(
      extraKindPath,
      planWithEntries([
        `        - contract-publish:
            contract-name: alpha
            expected-sender: ${DEPLOYER}
          transaction-type: unsupported`,
      ]),
      "utf8",
    );
    expect(() => readDeploymentPlan(extraKindPath)).toThrowError(
      expect.objectContaining({
        code: "PLAN_MALFORMED",
        message: expect.stringContaining("0:0"),
      }),
    );

    const multipleKindsPath = join(tempDirectory, "multiple-kinds-plan.yaml");
    writeFileSync(
      multipleKindsPath,
      planWithEntries([
        `        - contract-publish:
            contract-name: alpha
            expected-sender: ${DEPLOYER}
          contract-call:
            contract-id: ${CONTRACT_ID}
            expected-sender: ${DEPLOYER}
            method: initialize
            parameters:
              - u1`,
      ]),
      "utf8",
    );
    expect(() => readDeploymentPlan(multipleKindsPath)).toThrowError(
      expect.objectContaining({
        code: "PLAN_MALFORMED",
        message: expect.stringContaining("0:0"),
      }),
    );

    const malformedPath = join(tempDirectory, "malformed-transaction-plan.yaml");
    writeFileSync(malformedPath, planWithEntries(["        - contract-call: []"]), "utf8");
    expect(() => readDeploymentPlan(malformedPath)).toThrowError(
      expect.objectContaining({
        code: "PLAN_MALFORMED",
        message: expect.stringContaining("0:0"),
      }),
    );
  });

  it("preserves exact source ordinals when an entry is inserted", () => {
    const insertedPath = join(tempDirectory, "inserted-entry-plan.yaml");
    writeFileSync(insertedPath, planWithEntries([PUBLISH_ENTRY, CALL_ENTRY, CALL_ENTRY]), "utf8");

    const plan = readDeploymentPlan(insertedPath);
    expect(plan.entries.map((entry) => `${entry.planPosition.batchId}:${entry.planPosition.transactionIndex}`)).toEqual([
      "0:0",
      "0:1",
      "0:2",
    ]);
  });

  it("confirms complete plan evidence with nullable burn hash and rich Hiro interfaces", async () => {
    const fetcher = mockHiroFetch({ publish: { burn_block_hash: null } });
    const result = await verifyDeploymentEvidence(baseEvidence(), {
      network: "testnet",
      deployer: DEPLOYER,
      baseUrl: "http://hiro.test",
      planPath: PLAN_PATH,
      fetcher,
      now: () => FIXED_TIME,
    });

    expect(result.ok).toBe(true);
    expect(result.network).toBe("testnet");
    expect(result.deployer).toBe(DEPLOYER);
    expect(result.contracts).toHaveLength(1);

    const readOnlyCall = (fetcher as ReturnType<typeof vi.fn>).mock.calls.find(([input]) =>
      String(input).includes("/v2/contracts/call-read/"),
    );
    expect(readOnlyCall).toBeDefined();
    expect(JSON.parse((readOnlyCall?.[1] as RequestInit).body as string)).toEqual({
      sender: DEPLOYER,
      arguments: [],
    });
  });

  it("keeps pending retryable and classifies aborted transactions as terminal", async () => {
    const resultPending = await verifyDeploymentEvidence(baseEvidence(), {
      network: "testnet",
      deployer: DEPLOYER,
      baseUrl: "http://hiro.test",
      planPath: PLAN_PATH,
      fetcher: mockHiroFetch({ publish: { tx_status: "pending" } }),
      now: () => FIXED_TIME,
    });
    expect(resultPending.ok).toBe(false);
    expect(resultPending.failures.some(
      (f) => f.classification === "transaction-pending" || f.classification === "transaction-unconfirmed",
    )).toBe(true);

    const resultAborted = await verifyDeploymentEvidence(baseEvidence(), {
      network: "testnet",
      deployer: DEPLOYER,
      baseUrl: "http://hiro.test",
      planPath: PLAN_PATH,
      fetcher: mockHiroFetch({ publish: { tx_status: "abort_by_response" } }),
      now: () => FIXED_TIME,
    });
    expect(resultAborted.ok).toBe(false);
    expect(resultAborted.failures.some((f) => f.classification === "transaction-failed")).toBe(true);
  });

  it("fails closed on read-only API, malformed, failed, missing, and mismatched responses", async () => {
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ readOnly: { okay: false, cause: "RuntimeCheck(ReadOnlyFunctionFailure)" } }),
      "READ_ONLY_API_ERROR",
    );
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ readOnly: { okay: true } }),
      "READ_ONLY_MALFORMED_RESPONSE",
    );
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ readOnly: { okay: true, result: "0x04" } }),
      "READ_ONLY_MISMATCH",
    );
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ readOnlyStatus: 404 }),
      "READ_ONLY_NOT_FOUND",
    );
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ readOnlyStatus: 503 }),
      "READ_ONLY_HTTP_ERROR",
    );
  });

  it("classifies read-only provider failures and bounded request timeouts", async () => {
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ readOnlyThrows: true }),
      "READ_ONLY_REQUEST_FAILED",
    );
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ readOnlyHangs: true }),
      "READ_ONLY_TIMEOUT",
      { requestTimeoutMs: 1 },
    );
    const bodyTimeoutResult = await verifyDeploymentEvidence(baseEvidence(), {
      network: "testnet",
      deployer: DEPLOYER,
      baseUrl: "http://hiro.test",
      planPath: PLAN_PATH,
      fetcher: mockHiroFetch({ readOnlyBodyHangs: true }),
      now: () => FIXED_TIME,
      requestTimeoutMs: 1,
    });
    expect(bodyTimeoutResult.ok).toBe(false);
    expect(bodyTimeoutResult.failures.some((f) => f.classification === "read-only-api-error" || f.classification === "read-only-mismatch" || f.classification === "transaction-api-error")).toBe(true);
  });

  it("requires the exact live read-only function and access classification", async () => {
    const unknownFunction = baseEvidence();
    unknownFunction.readOnlyChecks![0].functionName = "not-in-interface";
    const unknownFetcher = mockHiroFetch();
    await expectVerificationError(unknownFunction, unknownFetcher, "READ_ONLY_FUNCTION_MISSING");
    expect(
      (unknownFetcher as ReturnType<typeof vi.fn>).mock.calls.some(([input]) =>
        String(input).includes("/v2/contracts/call-read/"),
      ),
    ).toBe(false);

    const publicFunction = baseEvidence();
    publicFunction.readOnlyChecks![0].functionName = "initialize";
    const publicFetcher = mockHiroFetch();
    await expectVerificationError(publicFunction, publicFetcher, "READ_ONLY_FUNCTION_NOT_READ_ONLY");
    expect(
      (publicFetcher as ReturnType<typeof vi.fn>).mock.calls.some(([input]) =>
        String(input).includes("/v2/contracts/call-read/"),
      ),
    ).toBe(false);

    const countMismatch = baseEvidence();
    countMismatch.readOnlyChecks![0].arguments = [CALL_ARG_HEX];
    const countFetcher = mockHiroFetch();
    await expectVerificationError(countMismatch, countFetcher, "READ_ONLY_ARGUMENT_COUNT_MISMATCH");
    expect(
      (countFetcher as ReturnType<typeof vi.fn>).mock.calls.some(([input]) =>
        String(input).includes("/v2/contracts/call-read/"),
      ),
    ).toBe(false);
  });

  it("accepts a canonical contract principal as a read-only sender", async () => {
    const evidence = baseEvidence();
    evidence.readOnlyChecks![0].sender = CONTRACT_ID;
    const fetcher = mockHiroFetch();
    const result = await verifyDeploymentEvidence(evidence, {
      network: "testnet",
      deployer: DEPLOYER,
      baseUrl: "http://hiro.test",
      planPath: PLAN_PATH,
      fetcher,
      now: () => FIXED_TIME,
    });
    expect(result.ok).toBe(true);
    const readOnlyCall = (fetcher as ReturnType<typeof vi.fn>).mock.calls.find(([input]) =>
      String(input).includes("/v2/contracts/call-read/"),
    );
    expect(readOnlyCall).toBeDefined();
    expect(JSON.parse((readOnlyCall?.[1] as RequestInit).body as string).sender).toBe(CONTRACT_ID);
  });

  it("rejects malformed or wrong-network contract-principal read-only senders before network calls", async () => {
    const malformed = baseEvidence();
    malformed.readOnlyChecks![0].sender = `${DEPLOYER}.bad.name`;
    const malformedFetcher = mockHiroFetch();
    await expectVerificationError(malformed, malformedFetcher, "MALFORMED_EVIDENCE");
    expect(malformedFetcher).not.toHaveBeenCalled();

    const wrongNetwork = baseEvidence();
    wrongNetwork.readOnlyChecks![0].sender = "SP2JXKMSH007NPYAQHKJPQMAQYAD90NQGTVJVQ02B.alpha";
    const wrongNetworkFetcher = mockHiroFetch();
    await expectVerificationError(wrongNetwork, wrongNetworkFetcher, "NETWORK_DEPLOYER_MISMATCH");
    expect(wrongNetworkFetcher).not.toHaveBeenCalled();
  });

  it("binds each read-only check to the plan, evidence network, and canonical sender", async () => {
    const uncovered = baseEvidence();
    uncovered.readOnlyChecks![0].contractId = `${DEPLOYER}.uncovered`;
    const uncoveredFetcher = mockHiroFetch();
    await expectVerificationError(uncovered, uncoveredFetcher, "READ_ONLY_PLAN_MISMATCH");
    expect(uncoveredFetcher).not.toHaveBeenCalled();

    const wrongNetwork = baseEvidence();
    wrongNetwork.readOnlyChecks![0].network = "mainnet";
    const wrongNetworkFetcher = mockHiroFetch();
    await expectVerificationError(wrongNetwork, wrongNetworkFetcher, "READ_ONLY_NETWORK_MISMATCH");
    expect(wrongNetworkFetcher).not.toHaveBeenCalled();

    const wrongSender = baseEvidence();
    wrongSender.readOnlyChecks![0].sender = "ST1MTCGFNPSA2CC81F2C8HASNACV3P42RF3TRSRSH";
    const wrongSenderFetcher = mockHiroFetch();
    await expectVerificationError(wrongSender, wrongSenderFetcher, "READ_ONLY_SENDER_MISMATCH");
    expect(wrongSenderFetcher).not.toHaveBeenCalled();
  });

  it("rejects noncanonical transactions, wrong identities, and argument mismatches", async () => {
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ publish: { canonical: false } }),
      "TRANSACTION_NOT_CANONICAL",
    );
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ publish: { smart_contract: { contract_id: `${DEPLOYER}.wrong` } } }),
      "IDENTITY_MISMATCH",
    );
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ call: { contract_call: { contract_id: CONTRACT_ID, function_name: "initialize", function_args: [{ name: "amount", type: "uint128", hex: "0x0100000000000000000000000000000002", repr: "u2" }] } } }),
      "ARGUMENT_MISMATCH",
    );
  });

  it("strips Hiro API keys from arbitrary override hosts", async () => {
    const fetcher = mockHiroFetch({ publish: { burn_block_hash: null } });
    await verifyDeploymentEvidence(baseEvidence(), {
      network: "testnet",
      deployer: DEPLOYER,
      baseUrl: "http://override.invalid",
      apiKey: "do-not-forward",
      planPath: PLAN_PATH,
      fetcher,
      now: () => FIXED_TIME,
    });

    for (const call of (fetcher as ReturnType<typeof vi.fn>).mock.calls) {
      const init = call[1] as RequestInit;
      expect((init.headers as Record<string, string>)["x-hiro-api-key"]).toBeUndefined();
    }
  });

  it("accepts valid variable-length standard principal versions and rejects a testnet mainnet identity", () => {
    const testnetMultiSig = addressToString(addressFromVersionHash(AddressVersion.TestnetMultiSig, "0".repeat(40)));
    const multiSigPlanPath = join(tempDirectory, "multisig-plan.yaml");
    writePlan(multiSigPlanPath, { deployer: testnetMultiSig });
    expect(readDeploymentPlan(multiSigPlanPath).deployer).toBe(testnetMultiSig);

    const invalid = baseEvidence();
    invalid.network = "mainnet";
    invalid.deployer = testnetMultiSig;
    expect(() => readDeploymentPlan(join(tempDirectory, "mainnet-plan.yaml"))).toThrowError(
      expect.objectContaining({ code: "network-mismatch" }),
    );
    return expectVerificationError(invalid, mockHiroFetch(), "NETWORK_DEPLOYER_MISMATCH", {
      network: "mainnet",
      deployer: testnetMultiSig,
    });
  });

  it("requires one-to-one complete plan coverage and stable ordinal identity", async () => {
    const missing = baseEvidence();
    missing.contractCalls = [];
    await expectVerificationError(missing, mockHiroFetch(), "PLAN_EVIDENCE_MISMATCH");

    const extra = baseEvidence();
    extra.contractCalls.push({
      kind: "contract-call",
      planPosition: { batchId: 1, transactionIndex: 0 },
      contractId: CONTRACT_ID,
      functionName: "initialize",
      expectedSender: DEPLOYER,
      txid: `0x${"f".repeat(64)}`,
    });
    await expectVerificationError(extra, mockHiroFetch(), "PLAN_EVIDENCE_MISMATCH");

    const duplicate = baseEvidence();
    duplicate.contractCalls.push({ ...duplicate.contractCalls[0], txid: `0x${"f".repeat(64)}` });
    await expectVerificationError(duplicate, mockHiroFetch(), "DUPLICATE_PLAN_ENTRY");

    const reordered = baseEvidence();
    reordered.contractPublications[0].planPosition = { batchId: 0, transactionIndex: 1 };
    reordered.contractCalls[0].planPosition = { batchId: 0, transactionIndex: 0 };
    await expectVerificationError(reordered, mockHiroFetch(), "PLAN_EVIDENCE_MISMATCH");
  });

  it("does not collapse duplicate method-name calls when ordinals differ", async () => {
    const duplicateCallPlanPath = join(tempDirectory, "duplicate-call-plan.yaml");
    writePlan(duplicateCallPlanPath, { includeSecondCall: true });
    const evidence = baseEvidence();
    evidence.plan.sha256 = sha256File(duplicateCallPlanPath);
    evidence.contractCalls.push({
      ...evidence.contractCalls[0],
      planPosition: { batchId: 0, transactionIndex: 2 },
      txid: EXTRA_CALL_TXID,
    });

    const result = await verifyDeploymentEvidence(evidence, {
      network: "testnet",
      deployer: DEPLOYER,
      baseUrl: "http://hiro.test",
      planPath: duplicateCallPlanPath,
      fetcher: mockHiroFetch({ additionalTransactions: [{ txid: EXTRA_CALL_TXID, kind: "contract-call" }] }),
      now: () => FIXED_TIME,
    });
    expect(result.ok).toBe(true);
    expect(result.contracts).toHaveLength(1);
  });

  it("rejects missing interfaces and unsupported raw interface payloads", async () => {
    await expectVerificationError(baseEvidence(), mockHiroFetch({ interfaceStatus: 404 }), "INTERFACE_NOT_FOUND");
    await expectVerificationError(baseEvidence(), mockHiroFetch({ interfaceBody: { functions: [{ name: "initialize", access: "public", args: "invalid" }] } }), "UNSUPPORTED_API_PAYLOAD");
  });

  it("enforces required plan and function-name rules before network calls", async () => {
    const malformed = baseEvidence();
    malformed.contractCalls[0].functionName = "not a clarity name";
    await expectVerificationError(malformed, mockHiroFetch(), "MALFORMED_EVIDENCE");

    const unlabeledBroadcast = baseEvidence();
    delete unlabeledBroadcast.coverage;
    await expectVerificationError(unlabeledBroadcast, mockHiroFetch(), "MALFORMED_EVIDENCE");

    const noPlan = baseEvidence();
    await expectVerificationError(noPlan, mockHiroFetch(), "PLAN_REQUIRED", { planPath: undefined });
  });
});
