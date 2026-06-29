import { beforeEach, describe, expect, it } from "bun:test";
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
    headers: { "content-type": "application/json" },
  });
}

describe("release-governance SDK", () => {
  beforeEach(() => {
    resetAdminRuntimeClientConfig();
  });

  describe("requestReleaseApprovalV1", () => {
    it("posts approval requests to the canonical endpoint", async () => {
      let capturedUrl = "";
      let capturedBody: unknown;

      configureAdminRuntimeClient({
        runtimeBaseUrl: "https://runtime.internal",
        fetchImpl: async (input, init) => {
          capturedUrl = String(input);
          capturedBody = JSON.parse(init!.body as string);
          return jsonResponse({
            accepted: true,
            message: "Approval requested",
            auditEventId: "audit_rel_01",
            requestId: "req_rel_01",
          });
        },
      });

      const response = await requestReleaseApprovalV1({
        artifactId: "rel_v2.1",
        requestedBy: "release-manager",
        notes: "Hotfix for CON-1400",
      });

      expect(capturedUrl).toBe("https://runtime.internal/admin/v1/releases/request-approval");
      expect(capturedBody).toMatchObject({
        artifactId: "rel_v2.1",
        requestedBy: "release-manager",
        notes: "Hotfix for CON-1400",
      });
      expect(response.requestId).toBe("req_rel_01");
      expect(response.accepted).toBe(true);
    });

    it("rejects with config error when unconfigured", async () => {
      await expect(
        requestReleaseApprovalV1({
          artifactId: "rel_1",
          requestedBy: "op_1",
        }),
      ).rejects.toBeInstanceOf(AdminRuntimeConfigError);
    });

    it("surfaces error envelopes from the runtime", async () => {
      configureAdminRuntimeClient({
        runtimeBaseUrl: "https://runtime.internal",
        fetchImpl: async () =>
          jsonResponse(
            {
              error: {
                code: "RELEASE_WINDOW_CLOSED",
                message: "Release window is not open",
                traceId: "trace_rel_window",
                retryable: true,
              },
            },
            409,
          ),
      });

      await expect(
        requestReleaseApprovalV1({
          artifactId: "rel_2",
          requestedBy: "op_2",
        }),
      ).rejects.toMatchObject<Partial<AdminRuntimeRequestError>>({
        name: "AdminRuntimeRequestError",
        status: 409,
        runtimeError: {
          code: "RELEASE_WINDOW_CLOSED",
          retryable: true,
        },
      });
    });
  });

  describe("submitReleaseDecisionV1", () => {
    it("posts release decisions to the canonical endpoint", async () => {
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
            auditEventId: "audit_dec_01",
            decisionId: "dec_rel_01",
          });
        },
      });

      const response = await submitReleaseDecisionV1({
        artifactId: "rel_v2.1",
        decision: "approve",
        actorId: "gatekeeper",
        notes: "All gates green",
      });

      expect(capturedUrl).toBe("https://runtime.internal/admin/v1/releases/decision");
      expect(capturedBody).toMatchObject({
        artifactId: "rel_v2.1",
        decision: "approve",
        actorId: "gatekeeper",
        notes: "All gates green",
      });
      expect(response.decisionId).toBe("dec_rel_01");
    });

    it("rejects with config error when unconfigured", async () => {
      await expect(
        submitReleaseDecisionV1({
          artifactId: "rel_1",
          decision: "reject",
          actorId: "op_1",
        }),
      ).rejects.toBeInstanceOf(AdminRuntimeConfigError);
    });

    it("surfaces runtime errors for policy denials", async () => {
      configureAdminRuntimeClient({
        runtimeBaseUrl: "https://runtime.internal",
        fetchImpl: async () =>
          jsonResponse(
            {
              error: {
                code: "DUAL_CONTROL_REQUIRED",
                message: "Second approver required",
                traceId: "trace_dual",
                retryable: false,
                details: { requiredApprovers: 2, present: 1 },
              },
            },
            403,
          ),
      });

      await expect(
        submitReleaseDecisionV1({
          artifactId: "rel_3",
          decision: "approve",
          actorId: "op_3",
        }),
      ).rejects.toMatchObject<Partial<AdminRuntimeRequestError>>({
        name: "AdminRuntimeRequestError",
        status: 403,
        runtimeError: {
          code: "DUAL_CONTROL_REQUIRED",
          details: { requiredApprovers: 2, present: 1 },
        },
      });
    });
  });
});
