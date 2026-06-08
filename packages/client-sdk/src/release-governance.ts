import type {
  ReleaseApprovalRequest,
  ReleaseApprovalResponse,
  ReleaseDecisionRequest,
  ReleaseDecisionResponse,
} from "@conxian/schemas";
import type { AdminRuntimeRequestOptions } from "./runtime-client";
import { postAdminRuntimeJson } from "./runtime-client";

export function requestReleaseApprovalV1(
  input: ReleaseApprovalRequest,
  options?: AdminRuntimeRequestOptions,
): Promise<ReleaseApprovalResponse> {
  return postAdminRuntimeJson<ReleaseApprovalRequest, ReleaseApprovalResponse>(
    "/admin/v1/releases/request-approval",
    input,
    options,
  );
}

export function submitReleaseDecisionV1(
  input: ReleaseDecisionRequest,
  options?: AdminRuntimeRequestOptions,
): Promise<ReleaseDecisionResponse> {
  return postAdminRuntimeJson<ReleaseDecisionRequest, ReleaseDecisionResponse>(
    "/admin/v1/releases/decision",
    input,
    options,
  );
}
