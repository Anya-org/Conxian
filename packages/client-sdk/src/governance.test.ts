import { beforeEach, describe, expect, it } from "bun:test";
import { submitGovernanceDecisionV1 } from "./governance";
import {
  AdminRuntimeConfigError,
  AdminRuntimeRequestError,
  configureAdminRuntimeClient,
  resetAdminRuntimeClientConfig,
} from "./runtime-client";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

describe("governance SDK", () => {
  beforeEach(() => {
    resetAdminRuntimeClientConfig();
  });

  it("posts governance decisions to the canonical endpoint", async () => {
    let capturedUrl = "";
    let capturedBody: unknown;

    configureAdminRuntimeClient({
      runtimeBaseUrl: "https://runtime.internal",
      fetchImpl: async (input, init) => {
        capturedUrl = String(input);
        capturedBody = JSON.parse(init!.body as string);
        return jsonResponse({
          accepted: true,
          message: "Decision recorded",
          auditEventId: "audit_gov_01",
          decisionId: "dec_gov_01",
        });
      },
    });

    const response = await submitGovernanceDecisionV1({
      actionId: "gov_42",
      decision: "reject",
      actorId: "operator_x",
      notes: "Violates policy A.7",
    });

    expect(capturedUrl).toBe("https://runtime.internal/admin/v1/governance/decision");
    expect(capturedBody).toMatchObject({
      actionId: "gov_42",
      decision: "reject",
      actorId: "operator_x",
      notes: "Violates policy A.7",
    });
    expect(response.decisionId).toBe("dec_gov_01");
    expect(response.accepted).toBe(true);
  });

  it("surfaces config error when runtime is not configured", async () => {
    await expect(
      submitGovernanceDecisionV1({
        actionId: "gov_1",
        decision: "approve",
        actorId: "op_1",
      }),
    ).rejects.toBeInstanceOf(AdminRuntimeConfigError);
  });

  it("surfaces structured error for non-2xx responses", async () => {
    configureAdminRuntimeClient({
      runtimeBaseUrl: "https://runtime.internal",
      fetchImpl: async () =>
        jsonResponse(
          {
            error: {
              code: "GOVERNANCE_LOCKED",
              message: "Governance is locked for this cycle",
              traceId: "trace_gov_lock",
              retryable: false,
            },
          },
          423,
        ),
    });

    await expect(
      submitGovernanceDecisionV1({
        actionId: "gov_2",
        decision: "approve",
        actorId: "op_2",
      }),
    ).rejects.toMatchObject<Partial<AdminRuntimeRequestError>>({
      name: "AdminRuntimeRequestError",
      status: 423,
      runtimeError: {
        code: "GOVERNANCE_LOCKED",
        message: "Governance is locked for this cycle",
      },
    });
  });

  it("handles non-JSON error responses gracefully", async () => {
    configureAdminRuntimeClient({
      runtimeBaseUrl: "https://runtime.internal",
      fetchImpl: async () =>
        new Response("Internal Server Error", {
          status: 500,
          headers: { "content-type": "text/plain" },
        }),
    });

    await expect(
      submitGovernanceDecisionV1({
        actionId: "gov_3",
        decision: "approve",
        actorId: "op_3",
      }),
    ).rejects.toMatchObject<Partial<AdminRuntimeRequestError>>({
      name: "AdminRuntimeRequestError",
      status: 500,
      runtimeError: undefined,
    });
  });

  it("allows per-request override of runtimeBaseUrl", async () => {
    let capturedUrl = "";

    configureAdminRuntimeClient({
      runtimeBaseUrl: "https://default.internal",
      fetchImpl: async (input) => {
        capturedUrl = String(input);
        return jsonResponse({
          accepted: true,
          message: "ok",
          auditEventId: "audit_x",
          decisionId: "dec_x",
        });
      },
    });

    await submitGovernanceDecisionV1(
      { actionId: "gov_4", decision: "approve", actorId: "op_4" },
      { runtimeBaseUrl: "https://override.internal" },
    );

    expect(capturedUrl).toBe("https://override.internal/admin/v1/governance/decision");
  });
});
