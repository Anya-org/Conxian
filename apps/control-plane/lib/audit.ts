import type { AuditActionEvent, AuditEventCategory, AuditOutcome } from "@conxian/schemas";

export function createAuditActionEvent(input: {
  category: AuditEventCategory;
  actor: string;
  summary: string;
  relatedEntityId: string;
  actionType: string;
  outcome: AuditOutcome;
}): AuditActionEvent {
  return {
    id: `audit_${input.relatedEntityId}_${Date.now()}`,
    category: input.category,
    actor: input.actor,
    summary: input.summary,
    timestamp: new Date().toISOString(),
    relatedEntityId: input.relatedEntityId,
    actionType: input.actionType,
    outcome: input.outcome,
  };
}
