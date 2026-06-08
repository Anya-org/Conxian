import type {
  GovernanceDecision,
  GovernanceDecisionResponse,
} from "@conxian/schemas";
import type { AdminRuntimeRequestOptions } from "./runtime-client";
import { postAdminRuntimeJson } from "./runtime-client";

export function submitGovernanceDecisionV1(
  input: GovernanceDecision,
  options?: AdminRuntimeRequestOptions,
): Promise<GovernanceDecisionResponse> {
  return postAdminRuntimeJson<GovernanceDecision, GovernanceDecisionResponse>(
    "/admin/v1/governance/decision",
    input,
    options,
  );
}
