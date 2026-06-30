import { describe, expect, it } from "bun:test";
import type {
  AdminApiError,
  AdminApiErrorEnvelope,
  AuditActionEvent,
  ChainRuntimeRecord,
  ChainRuntimeStatus,
  ChainsResponse,
  DriftRecord,
  DriftResponse,
  DriftStatus,
  GovernanceDecision,
  GovernanceDecisionResponse,
  PromotionEvidenceResponse,
  ReleaseApprovalRequest,
  ReleaseApprovalResponse,
  RuntimeEnvironmentRecord,
  RuntimeHealthResponse,
  RuntimeReadinessResponse,
  SafetyModeAckResponse,
  WorkflowMutationResponse,
} from "./index";

describe("@conxian/schemas admin runtime contracts", () => {
  it("AdminApiError enforces all required fields including optional traceId", () => {
    const error: AdminApiError = {
      code: "POLICY_DENIED",
      message: "Dual-control approval required",
      traceId: "trace_abc",
      retryable: false,
    };
    const envelope: AdminApiErrorEnvelope = { error };
    expect(envelope.error.code).toBe("POLICY_DENIED");
    expect(envelope.error.message).toBe("Dual-control approval required");
    expect(envelope.error.traceId).toBe("trace_abc");
    expect(envelope.error.retryable).toBe(false);
    expect(envelope.error.details).toBeUndefined();
  });

  it("RuntimeHealthResponse carries all evidence classification fields", () => {
    const health: RuntimeHealthResponse = {
      status: "ready",
      message: "runtime healthy",
      trustTier: "proofVerified",
      evidenceLevel: "verified",
      lastUpdated: "2026-06-08T00:00:00.000Z",
    };
    expect(health.status).toBe("ready");
    expect(health.trustTier).toBe("proofVerified");
    expect(health.evidenceLevel).toBe("verified");
    expect(health.lastUpdated).toBe("2026-06-08T00:00:00.000Z");
  });

  it("RuntimeReadinessResponse exposes blockers and readiness flag", () => {
    const readiness: RuntimeReadinessResponse = {
      status: "degraded",
      ready: false,
      blockers: ["attestation-expired", "drift-warning"],
      trustTier: "observerOnly",
      evidenceLevel: "partial",
      lastUpdated: "2026-06-08T00:00:00.000Z",
    };
    expect(readiness.ready).toBe(false);
    expect(readiness.blockers).toHaveLength(2);
    expect(readiness.blockers).toContain("drift-warning");
  });

  it("SafetyModeAckResponse extends WorkflowMutationResponse with ack fields", () => {
    const ack: SafetyModeAckResponse = {
      accepted: true,
      message: "Safety mode acknowledged",
      auditEventId: "audit_safety",
      ackId: "ack_001",
      status: "degraded",
      acknowledgedAt: "2026-06-08T00:00:00.000Z",
    };
    expect(ack.ackId).toBe("ack_001");
    expect(ack.accepted).toBe(true);
    expect(ack.acknowledgedAt).toBe("2026-06-08T00:00:00.000Z");
  });

  it("PromotionEvidenceResponse carries release gating metadata", () => {
    const evidence: PromotionEvidenceResponse = {
      releaseId: "release/2026.06",
      status: "ready",
      trustTier: "proofVerified",
      evidenceLevel: "verified",
      summary: "All gates passed",
      lastUpdated: "2026-06-08T00:00:00.000Z",
    };
    expect(evidence.releaseId).toBe("release/2026.06");
    expect(evidence.status).toBe("ready");
    expect(evidence.trustTier).toBe("proofVerified");
  });

  it("RuntimeEnvironmentRecord extends EnvironmentRecord with runtime metadata", () => {
    const env: RuntimeEnvironmentRecord = {
      id: "env_prod",
      name: "production",
      classification: "production",
      owner: "ops",
      verificationStatus: "verified",
      status: "ready",
      trustTier: "proofVerified",
      evidenceLevel: "verified",
      lastUpdated: "2026-06-08T00:00:00.000Z",
    };
    expect(env.id).toBe("env_prod");
    expect(env.classification).toBe("production");
    expect(env.verificationStatus).toBe("verified");
    expect(env.status).toBe("ready");
  });

  it("ChainRuntimeStatus includes optional chain identity and drift tracking", () => {
    const chain: ChainRuntimeStatus = {
      id: "bitcoin-mainnet",
      chain: "bitcoin/mainnet",
      status: "ready",
      trustTier: "proofVerified",
      evidenceLevel: "verified",
      driftStatus: "clear",
      latestBlockRef: "00000000000000000002a1b2c3d4e5f6",
      finalityClass: "bitcoin-6-confirmations",
      lastUpdated: "2026-06-08T00:00:00.000Z",
    };
    expect(chain.id).toBe("bitcoin-mainnet");
    expect(chain.chain).toBe("bitcoin/mainnet");
    expect(chain.driftStatus).toBe("clear");
    expect(chain.latestBlockRef).toBeDefined();
    expect(chain.finalityClass).toBeDefined();
  });

  it("ChainsResponse wraps an array of ChainRuntimeRecord", () => {
    const chain: ChainRuntimeRecord = {
      id: "stacks-mainnet",
      status: "ready",
      trustTier: "proofVerified",
      evidenceLevel: "verified",
      lastUpdated: "2026-06-08T00:00:00.000Z",
    };
    const resp: ChainsResponse = { chains: [chain] };
    expect(resp.chains).toHaveLength(1);
    expect(resp.chains[0]!.id).toBe("stacks-mainnet");
  });

  it("WorkflowMutationResponse is the base for release/governance responses", () => {
    const base: WorkflowMutationResponse = {
      accepted: true,
      message: "ok",
      auditEventId: "audit_01",
    };
    expect(base.accepted).toBe(true);
    expect(base.auditEventId).toBe("audit_01");
  });

  it("ReleaseApprovalRequest/Response carry approval lifecycle data", () => {
    const req: ReleaseApprovalRequest = {
      artifactId: "rel_abc",
      requestedBy: "operator_1",
      notes: "urgent hotfix",
    };
    expect(req.artifactId).toBe("rel_abc");
    expect(req.notes).toBe("urgent hotfix");

    const resp: ReleaseApprovalResponse = {
      accepted: false,
      message: "Blocked by policy",
      auditEventId: "audit_02",
      requestId: "req_01",
    };
    expect(resp.accepted).toBe(false);
    expect(resp.requestId).toBe("req_01");
  });

  it("GovernanceDecision maps to GovernanceDecisionResponse", () => {
    const decision: GovernanceDecision = {
      actionId: "gov_abc",
      decision: "approve",
      actorId: "operator_2",
    };
    expect(decision.decision).toBe("approve");

    const resp: GovernanceDecisionResponse = {
      accepted: true,
      message: "Governance action approved",
      auditEventId: "audit_03",
      decisionId: "dec_01",
    };
    expect(resp.decisionId).toBe("dec_01");
    expect(resp.accepted).toBe(true);
  });

  it("AuditActionEvent extends AuditEvent with action-specific outcome", () => {
    const event: AuditActionEvent = {
      id: "audit_04",
      category: "governance",
      actor: "operator_3",
      summary: "Approved release",
      timestamp: "2026-06-08T00:00:00.000Z",
      relatedEntityId: "rel_abc",
      actionType: "approve",
      outcome: "accepted",
    };
    expect(event.id).toBe("audit_04");
    expect(event.relatedEntityId).toBe("rel_abc");
    expect(event.outcome).toBe("accepted");
  });

  it("DriftRecord surfaces drift severity and evidence levels", () => {
    const drift: DriftRecord = {
      id: "drift_01",
      status: "warning",
      summary: "Block height deviates by 3",
      trustTier: "proofVerified",
      evidenceLevel: "strong",
      lastUpdated: "2026-06-08T00:00:00.000Z",
    };
    expect(drift.status).toBe("warning");
    expect(drift.summary).toBe("Block height deviates by 3");
    expect(drift.evidenceLevel).toBe("strong");
  });

  it("DriftResponse bundles drift records with overall status", () => {
    const resp: DriftResponse = {
      status: "degraded",
      trustTier: "observerOnly",
      evidenceLevel: "partial",
      lastUpdated: "2026-06-08T00:00:00.000Z",
      drifts: [
        {
          id: "drift_001",
          status: "warning",
          summary: "Confirmation lag detected",
          trustTier: "observerOnly",
          evidenceLevel: "partial",
          lastUpdated: "2026-06-08T00:00:00.000Z",
        },
      ],
    };
    expect(resp.drifts).toHaveLength(1);
    expect(resp.drifts[0]!.id).toBe("drift_001");
    expect(resp.status).toBe("degraded");
  });
});
