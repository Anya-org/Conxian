import { beforeEach, describe, expect, it } from "bun:test";
import {
  getControlPlaneHealth,
  getPromotionEvidenceV1,
  getRuntimeChainStatusV1,
  listAuditEvents,
  listRuntimeChainsV1,
} from "./index";
import { submitGovernanceDecisionV1 } from "./governance";
import { requestReleaseApprovalV1, submitReleaseDecisionV1 } from "./release-governance";
import {
  AdminRuntimeConfigError,
  AdminRuntimeRequestError,
  configureAdminRuntimeClient,
  resetAdminRuntimeClientConfig,
} from "./runtime-client";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
    },
  });
}

describe("client-sdk runtime-backed workflows", () => {
  beforeEach(() => {
    resetAdminRuntimeClientConfig();
  });

  it("fails closed when runtime configuration is missing", async () => {
    await expect(
      requestReleaseApprovalV1({
        artifactId: "rel_1",
        requestedBy: "operator_1",
      }),
    ).rejects.toBeInstanceOf(AdminRuntimeConfigError);

    await expect(
      submitReleaseDecisionV1({
        artifactId: "rel_1",
        decision: "approve",
        actorId: "operator_1",
      }),
    ).rejects.toBeInstanceOf(AdminRuntimeConfigError);

    await expect(
      submitGovernanceDecisionV1({
        actionId: "gov_1",
        decision: "reject",
        actorId: "operator_2",
      }),
    ).rejects.toBeInstanceOf(AdminRuntimeConfigError);
  });

  it("passes through runtime mutation responses without forcing accepted=true", async () => {
    configureAdminRuntimeClient({
      runtimeBaseUrl: "https://runtime.internal",
      fetchImpl: async () =>
        jsonResponse({
          accepted: false,
          requestId: "req_runtime",
          auditEventId: "audit_runtime",
          message: "Approval blocked by policy gate.",
        }),
    });

    const response = await requestReleaseApprovalV1({
      artifactId: "rel_2",
      requestedBy: "operator_3",
      notes: "policy check",
    });

    expect(response.accepted).toBe(false);
    expect(response.requestId).toBe("req_runtime");
    expect(response.message).toBe("Approval blocked by policy gate.");
  });

  it("surfaces runtime error envelopes for mutation failures", async () => {
    configureAdminRuntimeClient({
      runtimeBaseUrl: "https://runtime.internal",
      fetchImpl: async () =>
        jsonResponse(
          {
            error: {
              code: "POLICY_DENIED",
              message: "Dual-control approval required",
              traceId: "trace_123",
              retryable: false,
            },
          },
          403,
        ),
    });

    await expect(
      submitGovernanceDecisionV1({
        actionId: "gov_2",
        decision: "approve",
        actorId: "operator_4",
      }),
    ).rejects.toMatchObject<Partial<AdminRuntimeRequestError>>({
      name: "AdminRuntimeRequestError",
      status: 403,
      runtimeError: {
        code: "POLICY_DENIED",
        message: "Dual-control approval required",
        retryable: false,
      },
    });
  });

  it("targets canonical read endpoints and preserves path encoding", async () => {
    const calls: Array<{ input: string; init?: RequestInit }> = [];
    const responses = [
      jsonResponse({
        status: "ready",
        message: "runtime healthy",
        trustTier: "proofVerified",
        evidenceLevel: "verified",
        lastUpdated: "2026-06-08T00:00:00.000Z",
      }),
      jsonResponse({ events: [] }),
      jsonResponse({ chains: [] }),
      jsonResponse({
        chain: {
          id: "bitcoin-mainnet",
          chain: "bitcoin/mainnet",
          status: "ready",
          trustTier: "proofVerified",
          evidenceLevel: "verified",
          driftStatus: "clear",
          lastUpdated: "2026-06-08T00:00:00.000Z",
        },
      }),
      jsonResponse({
        releaseId: "release/2026.06",
        status: "degraded",
        trustTier: "observerOnly",
        evidenceLevel: "partial",
        summary: "Awaiting final attestation",
        lastUpdated: "2026-06-08T00:00:00.000Z",
      }),
    ];

    configureAdminRuntimeClient({
      runtimeBaseUrl: "https://runtime.internal/",
      fetchImpl: async (input, init) => {
        calls.push({ input: String(input), init });
        const next = responses.shift();
        if (!next) {
          throw new Error("Unexpected extra fetch call");
        }
        return next;
      },
    });

    await getControlPlaneHealth();
    await listAuditEvents();
    await listRuntimeChainsV1();
    await getRuntimeChainStatusV1("bitcoin/mainnet");
    await getPromotionEvidenceV1("release/2026.06");

    expect(calls.map((call) => call.input)).toEqual([
      "https://runtime.internal/admin/v1/runtime/health",
      "https://runtime.internal/admin/v1/audit-events",
      "https://runtime.internal/admin/v1/chains",
      "https://runtime.internal/admin/v1/chains/bitcoin%2Fmainnet/status",
      "https://runtime.internal/admin/v1/promotion-evidence/release%2F2026.06",
    ]);

    expect(calls.every((call) => call.init?.method === "GET")).toBe(true);
  });
});
