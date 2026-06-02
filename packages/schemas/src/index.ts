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
