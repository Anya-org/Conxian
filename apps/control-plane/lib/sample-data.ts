import type { AuditEvent, EnvironmentRecord, GovernanceAction, ReleaseArtifact } from "@conxian/schemas";

export const sampleReleaseArtifacts: ReleaseArtifact[] = [
  {
    id: "artifact_control_plane_foundation",
    name: "Control-plane foundation",
    status: "draft",
    owner: "conxian-business",
    updatedAt: new Date().toISOString(),
  },
  {
    id: "artifact_release_governance_module",
    name: "Release governance module",
    status: "in_review",
    owner: "conxian-business",
    updatedAt: new Date().toISOString(),
  },
];

export const sampleAuditEvents: AuditEvent[] = [
  {
    id: "evt_bootstrap_release_review",
    category: "release",
    actor: "system",
    summary: "Bootstrap release-governance workflow defined",
    timestamp: new Date().toISOString(),
  },
  {
    id: "evt_architecture_boundary_recorded",
    category: "governance",
    actor: "system",
    summary: "Control-plane and runtime boundary recorded in architecture docs",
    timestamp: new Date().toISOString(),
  },
];

export const sampleGovernanceActions: GovernanceAction[] = [
  {
    id: "gov_dual_control_policy",
    title: "Adopt dual-control approvals for high-risk promotions",
    status: "pending",
    owner: "conxian-business",
    updatedAt: new Date().toISOString(),
  },
  {
    id: "gov_admin_runtime_contract_v1",
    title: "Approve admin/runtime contract v1",
    status: "draft",
    owner: "conxian-nexus",
    updatedAt: new Date().toISOString(),
  },
];

export const sampleEnvironments: EnvironmentRecord[] = [
  {
    id: "env_local",
    name: "local",
    classification: "local",
    owner: "engineering",
    verificationStatus: "verified",
  },
  {
    id: "env_staging",
    name: "staging",
    classification: "staging",
    owner: "platform",
    verificationStatus: "pending",
  },
  {
    id: "env_production",
    name: "production",
    classification: "production",
    owner: "operations",
    verificationStatus: "restricted",
  },
];
