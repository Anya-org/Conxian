export type GovernanceActionStatus = "draft" | "pending" | "approved" | "rejected" | "changes_requested";
export type ReleaseArtifactStatus = "draft" | "in_review" | "approved" | "published" | "rejected";
export type EnvironmentVerificationStatus = "pending" | "verified" | "restricted";
export type AuditEventCategory = "release" | "policy" | "environment" | "governance";
export type AuditOutcome = "accepted" | "rejected" | "pending";
export type WorkflowDecision = "approve" | "reject" | "request_changes";

export interface GovernanceAction {
  id: string;
  title: string;
  status: GovernanceActionStatus;
  owner: string;
  updatedAt: string;
}

export interface AuditEvent {
  id: string;
  category: AuditEventCategory;
  actor: string;
  summary: string;
  timestamp: string;
}

export interface AuditActionEvent extends AuditEvent {
  relatedEntityId: string;
  actionType: string;
  outcome: AuditOutcome;
}

export interface EnvironmentRecord {
  id: string;
  name: string;
  classification: "local" | "staging" | "production" | "restricted";
  owner: string;
  verificationStatus: EnvironmentVerificationStatus;
}

export interface IdentityRecord {
  id: string;
  subject: string;
  source: string;
  status: "active" | "pending" | "revoked";
}

export interface ReleaseArtifact {
  id: string;
  name: string;
  status: ReleaseArtifactStatus;
  owner: string;
  updatedAt: string;
}

export interface TreasuryEvent {
  id: string;
  eventType: string;
  amount: string;
  asset: string;
  timestamp: string;
}

export interface HealthStatus {
  status: "bootstrap-ready" | "degraded";
  message: string;
}

export interface ReleaseApprovalRequest {
  artifactId: string;
  requestedBy: string;
  notes?: string;
}

export interface ReleaseDecisionRequest {
  artifactId: string;
  decision: WorkflowDecision;
  actorId: string;
  notes?: string;
}

export interface GovernanceDecision {
  actionId: string;
  decision: WorkflowDecision;
  actorId: string;
  notes?: string;
}

export interface WorkflowMutationResponse {
  accepted: boolean;
  message: string;
  auditEventId: string;
}

export interface ReleaseApprovalResponse extends WorkflowMutationResponse {
  requestId: string;
}

export interface ReleaseDecisionResponse extends WorkflowMutationResponse {
  decisionId: string;
}

export interface GovernanceDecisionResponse extends WorkflowMutationResponse {
  decisionId: string;
}

export type AdminRuntimeStatus = "ready" | "degraded" | "blocked" | "unknown";
export type AdminTrustTier = "nativeObservation" | "proofVerified" | "attesterVerified" | "observerOnly" | "unknown";
export type AdminEvidenceLevel = "none" | "partial" | "strong" | "verified" | "unknown";
export type AttestationStatus = "fresh" | "stale" | "expired" | "unknown";
export type DriftStatus = "clear" | "warning" | "drifted" | "blocked" | "unknown";
export type SafetyModeState = "enabled" | "disabled" | "unknown";

export interface AdminApiError {
  code: string;
  message: string;
  traceId?: string;
  retryable: boolean;
  details?: Record<string, unknown>;
}

export interface AdminApiErrorEnvelope {
  error: AdminApiError;
}

export interface RuntimeHealthResponse {
  status: AdminRuntimeStatus;
  message: string;
  trustTier: AdminTrustTier;
  evidenceLevel: AdminEvidenceLevel;
  lastUpdated: string;
}

export interface RuntimeReadinessResponse {
  status: AdminRuntimeStatus;
  ready: boolean;
  blockers: string[];
  trustTier: AdminTrustTier;
  evidenceLevel: AdminEvidenceLevel;
  lastUpdated: string;
}

export interface ChainRuntimeRecord {
  id: string;
  status: AdminRuntimeStatus;
  trustTier: AdminTrustTier;
  evidenceLevel: AdminEvidenceLevel;
  lastUpdated: string;
}

export interface ChainsResponse {
  chains: ChainRuntimeRecord[];
}

export interface ChainRuntimeStatus extends ChainRuntimeRecord {
  chain: string;
  driftStatus: DriftStatus;
  latestBlockRef?: string;
  finalityClass?: string;
}

export interface ChainStatusResponse {
  chain: ChainRuntimeStatus;
}

export interface AttestationRecord {
  id: string;
  chain: string;
  status: AttestationStatus;
  trustTier: AdminTrustTier;
  evidenceLevel: AdminEvidenceLevel;
  lastUpdated: string;
}

export interface AttestationsResponse {
  attestations: AttestationRecord[];
}

export interface AttestationDetail extends AttestationRecord {
  proofType: string;
  issuedAt: string;
  expiresAt?: string;
  subjectId?: string;
}

export interface AttestationResponse {
  attestation: AttestationDetail;
}

export interface DriftRecord {
  id: string;
  status: DriftStatus;
  summary: string;
  trustTier: AdminTrustTier;
  evidenceLevel: AdminEvidenceLevel;
  lastUpdated: string;
}

export interface DriftResponse {
  status: AdminRuntimeStatus;
  drifts: DriftRecord[];
  trustTier: AdminTrustTier;
  evidenceLevel: AdminEvidenceLevel;
  lastUpdated: string;
}

export interface SafetyModeResponse {
  status: AdminRuntimeStatus;
  mode: SafetyModeState;
  reason: string;
  trustTier: AdminTrustTier;
  evidenceLevel: AdminEvidenceLevel;
  lastUpdated: string;
}

export interface SafetyModeAckRequest {
  acknowledgedBy: string;
  reason: string;
}

export interface SafetyModeAckResponse extends WorkflowMutationResponse {
  ackId: string;
  status: AdminRuntimeStatus;
  acknowledgedAt: string;
}

export interface PromotionEvidenceResponse {
  releaseId: string;
  status: AdminRuntimeStatus;
  trustTier: AdminTrustTier;
  evidenceLevel: AdminEvidenceLevel;
  summary: string;
  lastUpdated: string;
}

export interface RuntimeEnvironmentRecord extends EnvironmentRecord {
  status: AdminRuntimeStatus;
  trustTier: AdminTrustTier;
  evidenceLevel: AdminEvidenceLevel;
  lastUpdated: string;
}

export interface EnvironmentsResponse {
  environments: RuntimeEnvironmentRecord[];
}

export interface AuditEventsResponse {
  events: AuditEvent[];
}

export interface ReleaseArtifactsResponse {
  releases: ReleaseArtifact[];
}

export interface GovernanceActionsResponse {
  governanceActions: GovernanceAction[];
}
