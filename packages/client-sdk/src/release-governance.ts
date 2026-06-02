import type {
  ReleaseApprovalRequest,
  ReleaseApprovalResponse,
  ReleaseDecisionRequest,
  ReleaseDecisionResponse,
} from "@conxian/schemas";

export function requestReleaseApprovalV1(input: ReleaseApprovalRequest): ReleaseApprovalResponse {
  return {
    accepted: true,
    requestId: `req_${input.artifactId}`,
    auditEventId: `audit_${input.artifactId}`,
    message: "Release approval request accepted via v1 workflow client.",
  };
}

export function submitReleaseDecisionV1(input: ReleaseDecisionRequest): ReleaseDecisionResponse {
  return {
    accepted: true,
    decisionId: `release_decision_${input.artifactId}`,
    auditEventId: `audit_release_${input.artifactId}`,
    message: `Release decision ${input.decision} accepted via v1 workflow client.`,
  };
}
