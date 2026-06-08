import type { AdminApiError, AdminApiErrorEnvelope } from "@conxian/schemas";

export type RuntimeFetch = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;

export interface AdminRuntimeClientConfig {
  runtimeBaseUrl?: string;
  fetchImpl?: RuntimeFetch;
  defaultHeaders?: HeadersInit;
}

export interface AdminRuntimeRequestOptions {
  runtimeBaseUrl?: string;
  fetchImpl?: RuntimeFetch;
  headers?: HeadersInit;
  signal?: AbortSignal;
}

const RUNTIME_BASE_URL_ENV_KEYS = ["CONXIAN_ADMIN_RUNTIME_BASE_URL", "ADMIN_RUNTIME_BASE_URL"] as const;

let runtimeClientConfig: AdminRuntimeClientConfig = {};

export class AdminRuntimeConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AdminRuntimeConfigError";
  }
}

export class AdminRuntimeRequestError extends Error {
  readonly status: number;
  readonly method: string;
  readonly endpoint: string;
  readonly runtimeError?: AdminApiError;

  constructor({
    status,
    method,
    endpoint,
    runtimeError,
  }: {
    status: number;
    method: string;
    endpoint: string;
    runtimeError?: AdminApiError;
  }) {
    const fallback = `Runtime request failed with HTTP ${status}.`;
    super(runtimeError?.message ?? fallback);
    this.name = "AdminRuntimeRequestError";
    this.status = status;
    this.method = method;
    this.endpoint = endpoint;
    this.runtimeError = runtimeError;
  }
}

export function configureAdminRuntimeClient(config: AdminRuntimeClientConfig): void {
  runtimeClientConfig = {
    ...runtimeClientConfig,
    ...config,
  };
}

export function resetAdminRuntimeClientConfig(): void {
  runtimeClientConfig = {};
}

function normalizeRuntimeBaseUrl(runtimeBaseUrl: string): string {
  return runtimeBaseUrl.replace(/\/+$/, "");
}

function getRuntimeBaseUrlFromEnvironment(): string | undefined {
  const runtimeProcess = (globalThis as { process?: { env?: Record<string, string | undefined> } }).process;
  const environment = runtimeProcess?.env;

  if (!environment) {
    return undefined;
  }

  for (const key of RUNTIME_BASE_URL_ENV_KEYS) {
    const value = environment[key];
    if (value && value.trim().length > 0) {
      return value;
    }
  }

  return undefined;
}

function resolveRuntimeBaseUrl(options?: AdminRuntimeRequestOptions): string {
  const configuredRuntimeBaseUrl = options?.runtimeBaseUrl ?? runtimeClientConfig.runtimeBaseUrl ?? getRuntimeBaseUrlFromEnvironment();

  if (!configuredRuntimeBaseUrl || configuredRuntimeBaseUrl.trim().length === 0) {
    throw new AdminRuntimeConfigError(
      "Missing admin runtime base URL. Configure `runtimeBaseUrl` explicitly or set CONXIAN_ADMIN_RUNTIME_BASE_URL.",
    );
  }

  return normalizeRuntimeBaseUrl(configuredRuntimeBaseUrl);
}

function resolveFetchImplementation(options?: AdminRuntimeRequestOptions): RuntimeFetch {
  const fetchImpl = options?.fetchImpl ?? runtimeClientConfig.fetchImpl ?? globalThis.fetch;

  if (typeof fetchImpl !== "function") {
    throw new AdminRuntimeConfigError(
      "No fetch implementation available. Configure `fetchImpl` or run in an environment with global fetch.",
    );
  }

  return fetchImpl;
}

function buildHeaders(initHeaders?: HeadersInit, optionsHeaders?: HeadersInit): Headers {
  const headers = new Headers(runtimeClientConfig.defaultHeaders);

  if (initHeaders) {
    for (const [key, value] of new Headers(initHeaders).entries()) {
      headers.set(key, value);
    }
  }

  if (optionsHeaders) {
    for (const [key, value] of new Headers(optionsHeaders).entries()) {
      headers.set(key, value);
    }
  }

  return headers;
}

async function parseRuntimeErrorEnvelope(response: Response): Promise<AdminApiError | undefined> {
  const contentType = response.headers.get("content-type") ?? "";
  if (!contentType.includes("application/json")) {
    return undefined;
  }

  try {
    const payload = (await response.json()) as AdminApiErrorEnvelope | undefined;
    if (payload?.error && typeof payload.error.code === "string" && typeof payload.error.message === "string") {
      return payload.error;
    }
    return undefined;
  } catch {
    return undefined;
  }
}

function buildEndpointUrl(path: string, runtimeBaseUrl: string): string {
  if (!path.startsWith("/")) {
    return `${runtimeBaseUrl}/${path}`;
  }

  return `${runtimeBaseUrl}${path}`;
}

export async function requestAdminRuntimeJson<TResponse>({
  method,
  path,
  body,
  options,
}: {
  method: "GET" | "POST";
  path: string;
  body?: unknown;
  options?: AdminRuntimeRequestOptions;
}): Promise<TResponse> {
  const runtimeBaseUrl = resolveRuntimeBaseUrl(options);
  const endpoint = buildEndpointUrl(path, runtimeBaseUrl);
  const fetchImpl = resolveFetchImplementation(options);
  const headers = buildHeaders(undefined, options?.headers);

  const requestInit: RequestInit = {
    method,
    headers,
    signal: options?.signal,
  };

  if (body !== undefined) {
    headers.set("content-type", "application/json");
    requestInit.body = JSON.stringify(body);
  }

  const response = await fetchImpl(endpoint, requestInit);

  if (!response.ok) {
    const runtimeError = await parseRuntimeErrorEnvelope(response);
    throw new AdminRuntimeRequestError({
      status: response.status,
      method,
      endpoint,
      runtimeError,
    });
  }

  if (response.status === 204) {
    return undefined as TResponse;
  }

  return (await response.json()) as TResponse;
}

export function getAdminRuntimeJson<TResponse>(
  path: string,
  options?: AdminRuntimeRequestOptions,
): Promise<TResponse> {
  return requestAdminRuntimeJson<TResponse>({ method: "GET", path, options });
}

export function postAdminRuntimeJson<TRequest, TResponse>(
  path: string,
  body: TRequest,
  options?: AdminRuntimeRequestOptions,
): Promise<TResponse> {
  return requestAdminRuntimeJson<TResponse>({
    method: "POST",
    path,
    body,
    options,
  });
}
