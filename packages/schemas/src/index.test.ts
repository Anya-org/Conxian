import { describe, expect, it } from "bun:test";
import type {
  AdminApiErrorEnvelope,
  AttestationDetail,
  ChainRuntimeStatus,
  DriftResponse,
  PromotionEvidenceResponse,
  RuntimeEnvironmentRecord,
  RuntimeHealthResponse,
  RuntimeReadinessResponse,
  SafetyModeAckResponse,
} from "./index";

const runtimeHealthShape = {
  status: "ready",
  message: "runtime healthy",
  trustTier: "proofVerified",
  evidenceLevel: "verified",
  lastUpdated: "2026-06-08T00:00:00.000Z",
} satisfies RuntimeHealthResponse;

const runtimeReadinessShape = {
  status: "degraded",
  ready: false,
  blockers: ["attestation stale"],
  trustTier: "attesterVerified",
  evidenceLevel: "partial",
  lastUpdated: "2026-06-08T00:00:00.000Z",
} satisfies RuntimeReadinessResponse;

const chainStatusShape = {
  id: "bitcoin-mainnet",
  chain: "bitcoin/mainnet",
  status: "ready",
  trustTier: "proofVerified",
  evidenceLevel: "verified",
  driftStatus: "clear",
  latestBlockRef: "0000000000000001",
  finalityClass: "economic-finality",
  lastUpdated: "2026-06-08T00:00:00.000Z",
} satisfies ChainRuntimeStatus;

const attestationShape = {
  id: "att_001",
  chain: "bitcoin/mainnet",
  status: "fresh",
  trustTier: "proofVerified",
  evidenceLevel: "verified",
  proofType: "zk-proof",
  issuedAt: "2026-06-08T00:00:00.000Z",
  expiresAt: "2026-06-08T01:00:00.000Z",
  subjectId: "release_001",
  lastUpdated: "2026-06-08T00:00:00.000Z",
} satisfies AttestationDetail;

const driftShape = {
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
} satisfies DriftResponse;

const safetyAckShape = {
  accepted: true,
  message: "Acknowledgement recorded",
  auditEventId: "audit_001",
  ackId: "ack_001",
  status: "degraded",
  acknowledgedAt: "2026-06-08T00:00:00.000Z",
} satisfies SafetyModeAckResponse;

const promotionEvidenceShape = {
  releaseId: "release_001",
  status: "blocked",
  trustTier: "unknown",
  evidenceLevel: "none",
  summary: "Missing attestations",
  lastUpdated: "2026-06-08T00:00:00.000Z",
} satisfies PromotionEvidenceResponse;

const runtimeEnvironmentShape = {
  id: "env_prod",
  name: "production",
  classification: "production",
  owner: "platform-team",
  verificationStatus: "verified",
  status: "ready",
  trustTier: "proofVerified",
  evidenceLevel: "verified",
  lastUpdated: "2026-06-08T00:00:00.000Z",
} satisfies RuntimeEnvironmentRecord;

const adminErrorShape = {
  error: {
    code: "AUTHZ_DENIED",
    message: "Operator is not allowed to perform this action",
    traceId: "trace_001",
    retryable: false,
    details: {
      actorId: "operator_1",
    },
  },
} satisfies AdminApiErrorEnvelope;

describe("@conxian/schemas admin runtime contracts", () => {
  it("includes explicit error envelope fields", () => {
    expect(adminErrorShape.error.code).toBe("AUTHZ_DENIED");
    expect(adminErrorShape.error.retryable).toBe(false);
  });

  it("tracks runtime/read-model evidence classifications", () => {
    expect(runtimeHealthShape).toMatchObject({
      status: "ready",
      trustTier: "proofVerified",
      evidenceLevel: "verified",
    });

    expect(runtimeReadinessShape.blockers).toEqual(["attestation stale"]);
    expect(chainStatusShape.driftStatus).toBe("clear");
    expect(attestationShape.proofType).toBe("zk-proof");
    expect(driftShape.drifts[0]?.status).toBe("warning");
  });

  it("covers safety-mode ack, promotion evidence, and environments", () => {
    expect(safetyAckShape.ackId).toBe("ack_001");
    expect(promotionEvidenceShape.status).toBe("blocked");
    expect(runtimeEnvironmentShape.classification).toBe("production");
  });
});
