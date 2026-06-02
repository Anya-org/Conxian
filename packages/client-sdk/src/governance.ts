import type {
  GovernanceDecision,
  GovernanceDecisionResponse,
} from "@conxian/schemas";

export function submitGovernanceDecisionV1(input: GovernanceDecision): GovernanceDecisionResponse {
  return {
    accepted: true,
    decisionId: `governance_decision_${input.actionId}`,
    auditEventId: `audit_governance_${input.actionId}`,
    message: `Governance decision ${input.decision} accepted via v1 workflow client.`,
  };
}
