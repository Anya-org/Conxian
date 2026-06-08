export * from "./release-governance";
export * from "./governance";
export * from "./runtime-client";

import type {
  AttestationDetail,
  AttestationRecord,
  AttestationResponse,
  AttestationsResponse,
  AuditEvent,
  AuditEventsResponse,
  ChainRuntimeRecord,
  ChainRuntimeStatus,
  ChainStatusResponse,
  ChainsResponse,
  DriftResponse,
  EnvironmentsResponse,
  GovernanceAction,
  GovernanceActionsResponse,
  PromotionEvidenceResponse,
  ReleaseArtifact,
  ReleaseArtifactsResponse,
  RuntimeEnvironmentRecord,
  RuntimeHealthResponse,
  RuntimeReadinessResponse,
  SafetyModeAckRequest,
  SafetyModeAckResponse,
  SafetyModeResponse,
} from "@conxian/schemas";
import type { AdminRuntimeRequestOptions } from "./runtime-client";
import { getAdminRuntimeJson, postAdminRuntimeJson } from "./runtime-client";

function unwrapListPayload<T, TKey extends string>(payload: T[] | { [K in TKey]: T[] }, key: TKey): T[] {
  if (Array.isArray(payload)) {
    return payload;
  }

  return payload[key];
}

function unwrapChainStatusPayload(payload: ChainRuntimeStatus | ChainStatusResponse): ChainRuntimeStatus {
  if ("id" in payload) {
    return payload;
  }

  return payload.chain;
}

function unwrapAttestationPayload(payload: AttestationDetail | AttestationResponse): AttestationDetail {
  return "attestation" in payload ? payload.attestation : payload;
}

export function getControlPlaneHealth(options?: AdminRuntimeRequestOptions): Promise<RuntimeHealthResponse> {
  return getAdminRuntimeJson<RuntimeHealthResponse>("/admin/v1/runtime/health", options);
}

export const getRuntimeHealthV1 = getControlPlaneHealth;

export function getRuntimeReadinessV1(options?: AdminRuntimeRequestOptions): Promise<RuntimeReadinessResponse> {
  return getAdminRuntimeJson<RuntimeReadinessResponse>("/admin/v1/runtime/readiness", options);
}

export async function listReleaseArtifacts(options?: AdminRuntimeRequestOptions): Promise<ReleaseArtifact[]> {
  const payload = await getAdminRuntimeJson<ReleaseArtifact[] | ReleaseArtifactsResponse>("/admin/v1/releases", options);
  return unwrapListPayload(payload, "releases");
}

export async function listAuditEvents(options?: AdminRuntimeRequestOptions): Promise<AuditEvent[]> {
  const payload = await getAdminRuntimeJson<AuditEvent[] | AuditEventsResponse>("/admin/v1/audit-events", options);
  return unwrapListPayload(payload, "events");
}

export async function listGovernanceActions(options?: AdminRuntimeRequestOptions): Promise<GovernanceAction[]> {
  const payload = await getAdminRuntimeJson<GovernanceAction[] | GovernanceActionsResponse>(
    "/admin/v1/governance-actions",
    options,
  );
  return unwrapListPayload(payload, "governanceActions");
}

export async function listEnvironments(options?: AdminRuntimeRequestOptions): Promise<RuntimeEnvironmentRecord[]> {
  const payload = await getAdminRuntimeJson<RuntimeEnvironmentRecord[] | EnvironmentsResponse>(
    "/admin/v1/environments",
    options,
  );
  return unwrapListPayload(payload, "environments");
}

export const listEnvironmentsV1 = listEnvironments;
export const listAuditEventsV1 = listAuditEvents;

export async function listRuntimeChainsV1(options?: AdminRuntimeRequestOptions): Promise<ChainRuntimeRecord[]> {
  const payload = await getAdminRuntimeJson<ChainRuntimeRecord[] | ChainsResponse>("/admin/v1/chains", options);
  return unwrapListPayload(payload, "chains");
}

export async function getRuntimeChainStatusV1(
  chain: string,
  options?: AdminRuntimeRequestOptions,
): Promise<ChainRuntimeStatus> {
  const payload = await getAdminRuntimeJson<ChainRuntimeStatus | ChainStatusResponse>(
    `/admin/v1/chains/${encodeURIComponent(chain)}/status`,
    options,
  );
  return unwrapChainStatusPayload(payload);
}

export async function listAttestationsV1(options?: AdminRuntimeRequestOptions): Promise<AttestationRecord[]> {
  const payload = await getAdminRuntimeJson<AttestationRecord[] | AttestationsResponse>("/admin/v1/attestations", options);
  return unwrapListPayload(payload, "attestations");
}

export async function getAttestationV1(
  attestationId: string,
  options?: AdminRuntimeRequestOptions,
): Promise<AttestationDetail> {
  const payload = await getAdminRuntimeJson<AttestationDetail | AttestationResponse>(
    `/admin/v1/attestations/${encodeURIComponent(attestationId)}`,
    options,
  );
  return unwrapAttestationPayload(payload);
}

export function getRuntimeDriftV1(options?: AdminRuntimeRequestOptions): Promise<DriftResponse> {
  return getAdminRuntimeJson<DriftResponse>("/admin/v1/drift", options);
}

export function getSafetyModeV1(options?: AdminRuntimeRequestOptions): Promise<SafetyModeResponse> {
  return getAdminRuntimeJson<SafetyModeResponse>("/admin/v1/safety-mode", options);
}


export function acknowledgeSafetyModeV1(
  input: SafetyModeAckRequest,
  options?: AdminRuntimeRequestOptions,
): Promise<SafetyModeAckResponse> {
  return postAdminRuntimeJson<SafetyModeAckRequest, SafetyModeAckResponse>(
    "/admin/v1/safety-mode/ack",
    input,
    options,
  );
}

export function getPromotionEvidenceV1(
  releaseId: string,
  options?: AdminRuntimeRequestOptions,
): Promise<PromotionEvidenceResponse> {
  return getAdminRuntimeJson<PromotionEvidenceResponse>(
    `/admin/v1/promotion-evidence/${encodeURIComponent(releaseId)}`,
    options,
  );
}

