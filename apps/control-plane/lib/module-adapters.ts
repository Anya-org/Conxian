import {
  listAuditEvents,
  listEnvironments,
  listGovernanceActions,
  listReleaseArtifacts,
} from "@conxian/client-sdk";
import type { AuditEvent, EnvironmentRecord, GovernanceAction, ReleaseArtifact } from "@conxian/schemas";
import {
  sampleAuditEvents,
  sampleEnvironments,
  sampleGovernanceActions,
  sampleReleaseArtifacts,
} from "./sample-data";

function withFallback<T>(items: T[], fallback: T[]): T[] {
  return items.length > 0 ? items : fallback;
}

export function getReleaseGovernanceData(): ReleaseArtifact[] {
  return withFallback(listReleaseArtifacts(), sampleReleaseArtifacts);
}

export function getAuditData(): AuditEvent[] {
  return withFallback(listAuditEvents(), sampleAuditEvents);
}

export function getPolicyApprovalData(): GovernanceAction[] {
  return withFallback(listGovernanceActions(), sampleGovernanceActions);
}

export function getEnvironmentData(): EnvironmentRecord[] {
  return withFallback(listEnvironments(), sampleEnvironments);
}
