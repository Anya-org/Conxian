// @vitest-environment node
import { describe, expect, it, vi } from "vitest";
import {
  DeploymentVerificationError,
  type DeploymentEvidence,
  verifyDeploymentEvidence,
} from "../scripts/deployment/verify-evidence";

const DEPLOYER = "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P";
const CONTRACT_ID = `${DEPLOYER}.alpha`;
const PUBLISH_TXID = `0x${"a".repeat(64)}`;
const CALL_TXID = `0x${"b".repeat(64)}`;
const FIXED_TIME = new Date("2026-07-22T12:00:00.000Z");

function txPayload(
  txid: string,
  kind: "contract-publish" | "contract-call",
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  const payload: Record<string, unknown> = {
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
      : { contract_call: { contract_id: CONTRACT_ID, function_name: "initialize" } }),
    ...overrides,
  };
  return payload;
}

function baseEvidence(): DeploymentEvidence {
  return {
    schemaVersion: "1",
    evidenceStatus: "broadcast",
    generatedAt: FIXED_TIME.toISOString(),
    sourceCommit: "e".repeat(40),
    network: "testnet",
    deployer: DEPLOYER,
    plan: {
      path: "deployments/full-system.testnet-plan.yaml",
      sha256: "f".repeat(64),
    },
    claims: {
      scope: "checked-addresses",
      globalNonexistence: false,
    },
    contractPublications: [
      {
        kind: "contract-publish",
        contractName: "alpha",
        contractId: CONTRACT_ID,
        expectedSender: DEPLOYER,
        txid: PUBLISH_TXID,
      },
    ],
    contractCalls: [
      {
        kind: "contract-call",
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
  };
}

function mockHiroFetch(
  overrides: {
    publish?: Record<string, unknown>;
    call?: Record<string, unknown>;
    publishStatus?: number;
    interfaceStatus?: number;
    interfaceBody?: Record<string, unknown>;
  } = {},
): typeof fetch {
  return vi.fn(async (input: string | URL) => {
    const url = new URL(String(input));
    if (url.pathname.endsWith(PUBLISH_TXID)) {
      return new Response(JSON.stringify(txPayload(PUBLISH_TXID, "contract-publish", overrides.publish)), {
        status: overrides.publishStatus ?? 200,
      });
    }
    if (url.pathname.endsWith(CALL_TXID)) {
      return new Response(JSON.stringify(txPayload(CALL_TXID, "contract-call", overrides.call)), { status: 200 });
    }
    if (url.pathname.includes("/v2/contracts/interface/")) {
      return new Response(
        JSON.stringify(
          overrides.interfaceBody ?? {
            functions: [
              { name: "get-name", access: "read_only" },
              { name: "initialize", access: "public" },
            ],
          },
        ),
        { status: overrides.interfaceStatus ?? 200 },
      );
    }
    return new Response(JSON.stringify({ error: "unexpected endpoint" }), { status: 500 });
  }) as typeof fetch;
}

async function expectVerificationError(
  evidence: unknown,
  fetcher: typeof fetch,
  code: string,
): Promise<void> {
  try {
    await verifyDeploymentEvidence(evidence, {
      network: "testnet",
      deployer: DEPLOYER,
      baseUrl: "http://hiro.test",
      fetcher,
      now: () => FIXED_TIME,
    });
    throw new Error("expected verification to fail");
  } catch (error) {
    expect(error).toBeInstanceOf(DeploymentVerificationError);
    expect((error as DeploymentVerificationError).code).toBe(code);
  }
}

describe("deployment evidence verification", () => {
  it("confirms canonical publication, configuration call, and interface evidence", async () => {
    const result = await verifyDeploymentEvidence(baseEvidence(), {
      network: "testnet",
      deployer: DEPLOYER,
      baseUrl: "http://hiro.test",
      fetcher: mockHiroFetch(),
      now: () => FIXED_TIME,
    });

    expect(result.evidenceStatus).toBe("confirmed");
    expect(result.verifiedAt).toBe(FIXED_TIME.toISOString());
    expect(result.contractPublications[0].apiEvidence?.canonical).toBe(true);
    expect(result.contractPublications[0].apiEvidence?.blockHeight).toBe(123);
    expect(result.contractCalls[0].apiEvidence?.functionName).toBe("initialize");
    expect(result.interfaces[0].interfaceEvidence?.httpStatus).toBe(200);
  });

  it("rejects broadcast-only evidence while a transaction is pending", async () => {
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ publish: { tx_status: "pending" } }),
      "TRANSACTION_NOT_CONFIRMED",
    );
  });

  it("rejects aborted and noncanonical transactions", async () => {
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ publish: { tx_status: "abort_by_response" } }),
      "TRANSACTION_NOT_CONFIRMED",
    );
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ publish: { canonical: false } }),
      "TRANSACTION_NOT_CANONICAL",
    );
  });

  it("rejects wrong contract and function identities", async () => {
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ publish: { smart_contract: { contract_id: `${DEPLOYER}.wrong` } } }),
      "IDENTITY_MISMATCH",
    );
    await expectVerificationError(
      baseEvidence(),
      mockHiroFetch({ call: { contract_call: { contract_id: CONTRACT_ID, function_name: "wrong" } } }),
      "FUNCTION_MISMATCH",
    );
  });

  it("rejects missing interfaces and unsupported interface payloads", async () => {
    await expectVerificationError(baseEvidence(), mockHiroFetch({ publishStatus: 404 }), "TRANSACTION_NOT_FOUND");
    await expectVerificationError(baseEvidence(), mockHiroFetch({ interfaceStatus: 404 }), "INTERFACE_NOT_FOUND");
    await expectVerificationError(baseEvidence(), mockHiroFetch({ interfaceBody: {} }), "UNSUPPORTED_API_PAYLOAD");
  });

  it("rejects malformed txids and network/deployer mismatches before network calls", async () => {
    const malformed = baseEvidence();
    malformed.contractPublications[0].txid = "";
    await expectVerificationError(malformed, mockHiroFetch(), "MALFORMED_EVIDENCE");

    const wrongNetwork = baseEvidence();
    wrongNetwork.network = "mainnet";
    await expectVerificationError(wrongNetwork, mockHiroFetch(), "NETWORK_DEPLOYER_MISMATCH");
  });
});
