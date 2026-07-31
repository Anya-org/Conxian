import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import {
  AddressVersion,
  addressToString,
  createAddress,
  validateStacksAddress,
} from "@stacks/transactions";

export const VERIFIER_VERSION = "1.1.0";
export const EVIDENCE_SCHEMA_VERSION = "1.0.0";

export const NETWORK_API_BASE_URLS = {
  testnet: "https://api.testnet.hiro.so",
  mainnet: "https://api.mainnet.hiro.so",
} as const;

export type DeploymentNetwork = keyof typeof NETWORK_API_BASE_URLS;

export const CANONICAL_PLAN_PATHS: Record<DeploymentNetwork, string> = {
  testnet: "deployments/full-system.testnet-plan.yaml",
  mainnet: "deployments/full-system.mainnet-plan.yaml",
};

export type FailureClassification =
  | "malformed-manifest"
  | "network-mismatch"
  | "deployer-mismatch"
  | "contract-mismatch"
  | "transaction-id-mismatch"
  | "missing-transaction"
  | "transaction-pending"
  | "transaction-failed"
  | "transaction-noncanonical"
  | "transaction-unconfirmed"
  | "transaction-api-error"
  | "interface-missing"
  | "interface-mismatch"
  | "interface-api-error"
  | "read-only-missing"
  | "read-only-mismatch"
  | "read-only-api-error"
  | "read-only-not-checked"
  | "evidence-binding-mismatch";

export interface DeploymentEvidenceManifest {
  $schema?: string;
  schemaVersion: typeof EVIDENCE_SCHEMA_VERSION;
  network: DeploymentNetwork;
  apiBaseUrl: string;
  deployer: string;
  evidence: {
    source: "confirmed-receipts";
    capturedAt: string;
    gitCommit: string;
    planPath: string;
    planSha256: string;
  };
  contracts: ContractEvidence[];
}

export interface ContractEvidence {
  name: string;
  principal: string;
  publishTxId: string;
  interface: {
    required: true;
    expectedContractName: string;
    expectedFunctions?: string[];
  };
  readOnlyChecks?: ReadOnlyCheck[];
}

export interface ReadOnlyCheck {
  function: string;
  sender: string;
  arguments: string[];
  expectedResultHex: string;
}

export interface VerificationFailure {
  classification: FailureClassification;
  scope: string;
  message: string;
  httpStatus?: number;
}

export interface TransactionEvidenceSummary {
  txId: string;
  status: string;
  sender: string;
  contractId: string;
  canonical: true;
  blockHash: string;
  blockHeight: number;
}

export interface InterfaceEvidenceSummary {
  available: true;
  contractId: string;
  functionCount: number;
  expectedFunctionsChecked: string[];
}

export interface ReadOnlyEvidenceSummary {
  function: string;
  sender: string;
  expectedResultHex: string;
  actualResultHex: string;
}

export interface ContractVerificationReport {
  name: string;
  principal: string;
  publishTxId: string;
  transaction?: TransactionEvidenceSummary;
  contractInterface?: InterfaceEvidenceSummary;
  readOnlyChecks: ReadOnlyEvidenceSummary[];
  failures: VerificationFailure[];
}

export interface VerificationReport {
  verifierVersion: typeof VERIFIER_VERSION;
  schemaVersion?: string;
  ok: boolean;
  network?: DeploymentNetwork;
  apiBaseUrl?: string;
  deployer?: string;
  scope: "documented-transaction-ids-and-contract-addresses-only";
  claim: "declared evidence entries verified" | "no deployment is verified";
  contracts: ContractVerificationReport[];
  failures: VerificationFailure[];
}

export interface EvidenceBinding {
  network: DeploymentNetwork;
  deployer: string;
  gitCommit: string;
  planPath: string;
  planSha256: string;
}

export interface FetchResponseLike {
  status: number;
  ok: boolean;
  json(): Promise<unknown>;
}

export interface FetchInitLike {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
  signal?: AbortSignal;
}

export type FetchLike = (
  url: string,
  init?: FetchInitLike,
) => Promise<FetchResponseLike>;

export interface HiroApi {
  getTransaction(txId: string): Promise<HttpResult>;
  getContractInterface(principal: string): Promise<HttpResult>;
  callReadOnly(
    principal: string,
    functionName: string,
    request: Pick<ReadOnlyCheck, "sender" | "arguments">,
  ): Promise<HttpResult>;
}

export interface HttpResult {
  status: number | null;
  ok: boolean;
  data?: unknown;
  error?: "network-error" | "invalid-json" | "timeout";
}

interface RecordValue {
  [key: string]: unknown;
}

const CONTRACT_NAME_PATTERN = /^[a-z][a-z0-9-]{0,127}$/;
const TX_ID_PATTERN = /^(?:0x)?[0-9a-f]{64}$/i;
const HEX_PATTERN = /^0x[0-9a-f]+$/i;
const SHA256_PATTERN = /^[0-9a-f]{64}$/i;
const COMMIT_PATTERN = /^[0-9a-f]{40}$/i;
const BLOCK_HASH_PATTERN = /^0x[0-9a-f]{64}$/;
const ISO_DATETIME_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;
const DEFAULT_HIRO_TIMEOUT_MS = 15_000;

const NETWORK_ADDRESS_PREFIXES: Record<DeploymentNetwork, string> = {
  testnet: "ST",
  mainnet: "SP",
};

const NETWORK_ADDRESS_VERSIONS: Record<DeploymentNetwork, readonly number[]> = {
  testnet: [AddressVersion.TestnetSingleSig, AddressVersion.TestnetMultiSig],
  mainnet: [AddressVersion.MainnetSingleSig, AddressVersion.MainnetMultiSig],
};

function isRecord(value: unknown): value is RecordValue {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function failure(
  classification: FailureClassification,
  scope: string,
  message: string,
  httpStatus?: number,
): VerificationFailure {
  return {
    classification,
    scope,
    message,
    ...(httpStatus === undefined ? {} : { httpStatus }),
  };
}

function rejectUnknownProperties(
  value: RecordValue,
  allowed: readonly string[],
  scope: string,
  failures: VerificationFailure[],
): void {
  const allowedProperties = new Set(allowed);
  for (const property of Object.keys(value)) {
    if (!allowedProperties.has(property)) {
      failures.push(
        failure(
          "malformed-manifest",
          `${scope}.${property}`,
          "manifest contains an unsupported property",
        ),
      );
    }
  }
}

function isDeploymentNetwork(value: unknown): value is DeploymentNetwork {
  return value === "testnet" || value === "mainnet";
}

export function isCanonicalStacksAddress(
  value: unknown,
  network: DeploymentNetwork,
): value is string {
  if (
    typeof value !== "string" ||
    !value.startsWith(NETWORK_ADDRESS_PREFIXES[network]) ||
    !validateStacksAddress(value)
  ) {
    return false;
  }

  try {
    const address = createAddress(value);
    return (
      NETWORK_ADDRESS_VERSIONS[network].includes(address.version) &&
      addressToString(address) === value
    );
  } catch {
    return false;
  }
}

function isContractName(value: unknown): value is string {
  return typeof value === "string" && CONTRACT_NAME_PATTERN.test(value);
}

function isTxId(value: unknown): value is string {
  return typeof value === "string" && TX_ID_PATTERN.test(value);
}

function normalizeTxId(txId: string): string {
  const normalized = txId.toLowerCase();
  return normalized.startsWith("0x") ? normalized : `0x${normalized}`;
}

function isHex(value: unknown): value is string {
  return typeof value === "string" && HEX_PATTERN.test(value);
}

function isCanonicalBlockHash(value: unknown): value is string {
  return typeof value === "string" && BLOCK_HASH_PATTERN.test(value);
}

function isIsoDateTime(value: unknown): value is string {
  return (
    typeof value === "string" &&
    ISO_DATETIME_PATTERN.test(value) &&
    !Number.isNaN(Date.parse(value))
  );
}

function validateApiBaseUrl(
  network: unknown,
  apiBaseUrl: unknown,
  failures: VerificationFailure[],
): void {
  if (typeof apiBaseUrl !== "string") {
    failures.push(
      failure(
        "malformed-manifest",
        "apiBaseUrl",
        "apiBaseUrl must be an HTTPS URL for the selected Hiro network",
      ),
    );
    return;
  }

  let parsed: URL;
  try {
    parsed = new URL(apiBaseUrl);
  } catch {
    failures.push(
      failure("malformed-manifest", "apiBaseUrl", "apiBaseUrl is not a valid URL"),
    );
    return;
  }

  if (parsed.protocol !== "https:") {
    failures.push(
      failure("malformed-manifest", "apiBaseUrl", "apiBaseUrl must use HTTPS"),
    );
    return;
  }

  if (isDeploymentNetwork(network) && apiBaseUrl !== NETWORK_API_BASE_URLS[network]) {
    failures.push(
      failure(
        "network-mismatch",
        "apiBaseUrl",
        `apiBaseUrl does not match the explicit ${network} network`,
      ),
    );
  }
}

function validateReadOnlyCheck(
  value: unknown,
  scope: string,
  network: DeploymentNetwork | undefined,
  failures: VerificationFailure[],
): value is ReadOnlyCheck {
  if (!isRecord(value)) {
    failures.push(failure("malformed-manifest", scope, "read-only check must be an object"));
    return false;
  }

  rejectUnknownProperties(
    value,
    ["function", "sender", "arguments", "expectedResultHex"],
    scope,
    failures,
  );

  if (!isContractName(value.function)) {
    failures.push(
      failure(
        "malformed-manifest",
        `${scope}.function`,
        "read-only function must be a lowercase Clarity identifier",
      ),
    );
  }

  if (!network || !isCanonicalStacksAddress(value.sender, network)) {
    failures.push(
      failure(
        "malformed-manifest",
        `${scope}.sender`,
        "read-only sender must be a valid Stacks address",
      ),
    );
  }

  if (!Array.isArray(value.arguments) || !value.arguments.every(isHex)) {
    failures.push(
      failure(
        "malformed-manifest",
        `${scope}.arguments`,
        "read-only arguments must be an array of Clarity hex values",
      ),
    );
  }

  if (!isHex(value.expectedResultHex) || value.expectedResultHex.length <= 2) {
    failures.push(
      failure(
        "malformed-manifest",
        `${scope}.expectedResultHex`,
        "expectedResultHex must be a non-empty Clarity hex value",
      ),
    );
  }

  return (
    isContractName(value.function) &&
    network !== undefined &&
    isCanonicalStacksAddress(value.sender, network) &&
    Array.isArray(value.arguments) &&
    value.arguments.every(isHex) &&
    isHex(value.expectedResultHex) &&
    value.expectedResultHex.length > 2
  );
}

export function validateManifest(input: unknown): {
  ok: boolean;
  manifest?: DeploymentEvidenceManifest;
  failures: VerificationFailure[];
} {
  const failures: VerificationFailure[] = [];

  if (!isRecord(input)) {
    return {
      ok: false,
      failures: [
        failure("malformed-manifest", "manifest", "evidence manifest must be a JSON object"),
      ],
    };
  }

  rejectUnknownProperties(
    input,
    ["$schema", "schemaVersion", "network", "apiBaseUrl", "deployer", "evidence", "contracts"],
    "manifest",
    failures,
  );

  if (input.schemaVersion !== EVIDENCE_SCHEMA_VERSION) {
    failures.push(
      failure(
        "malformed-manifest",
        "schemaVersion",
        `schemaVersion must be exactly ${EVIDENCE_SCHEMA_VERSION}`,
      ),
    );
  }

  if (!isDeploymentNetwork(input.network)) {
    failures.push(
      failure(
        "malformed-manifest",
        "network",
        "network must be explicitly set to testnet or mainnet",
      ),
    );
  }

  validateApiBaseUrl(input.network, input.apiBaseUrl, failures);

  const network = isDeploymentNetwork(input.network) ? input.network : undefined;
  if (!network || !isCanonicalStacksAddress(input.deployer, network)) {
    failures.push(
      failure(
        "malformed-manifest",
        "deployer",
        network
          ? `deployer must be a canonical ${network} Stacks address with a valid checksum and network version`
          : "deployer must be a canonical Stacks address for the explicit deployment network",
      ),
    );
  }

  if (!isRecord(input.evidence)) {
    failures.push(
      failure(
        "malformed-manifest",
        "evidence",
        "evidence metadata is required; a plan, workflow result, or broadcast-only ID is not evidence",
      ),
    );
  } else {
    rejectUnknownProperties(
      input.evidence,
      ["source", "capturedAt", "gitCommit", "planPath", "planSha256"],
      "evidence",
      failures,
    );
    if (input.evidence.source !== "confirmed-receipts") {
      failures.push(
        failure(
          "malformed-manifest",
          "evidence.source",
          "evidence.source must be confirmed-receipts; plans, workflow success, and broadcast-only IDs are not proof",
        ),
      );
    }

    if (!isIsoDateTime(input.evidence.capturedAt)) {
      failures.push(
        failure(
          "malformed-manifest",
          "evidence.capturedAt",
          "evidence.capturedAt must be a valid RFC 3339/ISO-8601 timestamp with an explicit timezone",
        ),
      );
    }

    if (
      typeof input.evidence.gitCommit !== "string" ||
      !COMMIT_PATTERN.test(input.evidence.gitCommit)
    ) {
      failures.push(
        failure(
          "malformed-manifest",
          "evidence.gitCommit",
          "evidence.gitCommit is required and must be a 40-character commit SHA",
        ),
      );
    }

    if (
      typeof input.evidence.planPath !== "string" ||
      input.evidence.planPath.length === 0
    ) {
      failures.push(
        failure(
          "malformed-manifest",
          "evidence.planPath",
          "evidence.planPath is required and must be a non-empty path",
        ),
      );
    } else if (
      network &&
      input.evidence.planPath !== CANONICAL_PLAN_PATHS[network]
    ) {
      failures.push(
        failure(
          "network-mismatch",
          "evidence.planPath",
          `evidence.planPath must be the canonical ${network} deployment plan path`,
        ),
      );
    }

    if (
      typeof input.evidence.planSha256 !== "string" ||
      !SHA256_PATTERN.test(input.evidence.planSha256)
    ) {
      failures.push(
        failure(
          "malformed-manifest",
          "evidence.planSha256",
          "evidence.planSha256 is required and must be a 64-character SHA-256 digest",
        ),
      );
    }
  }

  if (!Array.isArray(input.contracts) || input.contracts.length === 0) {
    failures.push(
      failure(
        "malformed-manifest",
        "contracts",
        "contracts must contain at least one exact contract evidence entry",
      ),
    );
  }

  const names = new Set<string>();
  const principals = new Set<string>();
  const txIds = new Set<string>();
  const validContracts: ContractEvidence[] = [];

  if (Array.isArray(input.contracts)) {
    input.contracts.forEach((value, index) => {
      const scope = `contracts[${index}]`;
      if (!isRecord(value)) {
        failures.push(failure("malformed-manifest", scope, "contract evidence must be an object"));
        return;
      }

      rejectUnknownProperties(
        value,
        ["name", "principal", "publishTxId", "interface", "readOnlyChecks"],
        scope,
        failures,
      );

      const name = value.name;
      const principal = value.principal;
      const publishTxId = value.publishTxId;

      if (!isContractName(name)) {
        failures.push(
          failure(
            "malformed-manifest",
            `${scope}.name`,
            "contract name must be a lowercase Clarity identifier",
          ),
        );
      } else if (names.has(name)) {
        failures.push(
          failure("malformed-manifest", `${scope}.name`, `duplicate contract name: ${name}`),
        );
      } else {
        names.add(name);
      }

      const principalParts =
        typeof principal === "string" ? principal.match(/^([^\.]+)\.([^.]+)$/) : null;
      if (
        !principalParts ||
        !network ||
        !isCanonicalStacksAddress(principalParts[1], network) ||
        !isContractName(principalParts[2])
      ) {
        failures.push(
          failure(
            "malformed-manifest",
            `${scope}.principal`,
            "principal must be an address followed by an exact contract name",
          ),
        );
      } else {
        if (principalParts[2] !== name) {
          failures.push(
            failure(
              "contract-mismatch",
              `${scope}.principal`,
              `principal contract name ${principalParts[2]} does not match expected name ${String(name)}`,
            ),
          );
        }
        if (network && principalParts[1] !== input.deployer) {
          failures.push(
            failure(
              "deployer-mismatch",
              `${scope}.principal`,
              "contract principal address does not match the expected deployer",
            ),
          );
        }
        if (typeof principal === "string" && principals.has(principal)) {
          failures.push(
            failure("malformed-manifest", `${scope}.principal`, `duplicate contract principal: ${principal}`),
          );
        } else if (typeof principal === "string") {
          principals.add(principal);
        }
      }

      if (!isTxId(publishTxId)) {
        failures.push(
          failure(
            "malformed-manifest",
            `${scope}.publishTxId`,
            "publishTxId must be a 64-byte transaction ID, with an optional 0x prefix",
          ),
        );
      } else {
        const normalizedTxId = normalizeTxId(publishTxId);
        if (txIds.has(normalizedTxId)) {
          failures.push(
            failure("malformed-manifest", `${scope}.publishTxId`, `duplicate transaction ID: ${normalizedTxId}`),
          );
        } else {
          txIds.add(normalizedTxId);
        }
      }

      const interfaceValue = value.interface;
      if (isRecord(interfaceValue)) {
        rejectUnknownProperties(
          interfaceValue,
          ["required", "expectedContractName", "expectedFunctions"],
          `${scope}.interface`,
          failures,
        );
      }
      if (!isRecord(interfaceValue) || interfaceValue.required !== true) {
        failures.push(
          failure(
            "malformed-manifest",
            `${scope}.interface`,
            "each contract must require interface verification",
          ),
        );
      }

      if (
        !isRecord(interfaceValue) ||
        interfaceValue.expectedContractName !== name ||
        !isContractName(interfaceValue.expectedContractName)
      ) {
        failures.push(
          failure(
            "malformed-manifest",
            `${scope}.interface.expectedContractName`,
            "expectedContractName must exactly match the contract name",
          ),
        );
      }

      if (
        isRecord(interfaceValue) &&
        interfaceValue.expectedFunctions !== undefined &&
        (!Array.isArray(interfaceValue.expectedFunctions) ||
          !interfaceValue.expectedFunctions.every(isContractName))
      ) {
        failures.push(
          failure(
            "malformed-manifest",
            `${scope}.interface.expectedFunctions`,
            "expectedFunctions must be an array of lowercase Clarity identifiers",
          ),
        );
      }

      if (
        isRecord(interfaceValue) &&
        Array.isArray(interfaceValue.expectedFunctions)
      ) {
        const expectedFunctionNames = interfaceValue.expectedFunctions as unknown[];
        if (new Set(expectedFunctionNames).size !== expectedFunctionNames.length) {
          failures.push(
            failure(
              "malformed-manifest",
              `${scope}.interface.expectedFunctions`,
              "expectedFunctions must not contain duplicate function names",
            ),
          );
        }
      }

      const readOnlyChecks: ReadOnlyCheck[] = [];
      if (value.readOnlyChecks !== undefined) {
        if (!Array.isArray(value.readOnlyChecks)) {
          failures.push(
            failure(
              "malformed-manifest",
              `${scope}.readOnlyChecks`,
              "readOnlyChecks must be an array when provided",
            ),
          );
        } else {
          value.readOnlyChecks.forEach((check, checkIndex) => {
            const checkScope = `${scope}.readOnlyChecks[${checkIndex}]`;
            if (validateReadOnlyCheck(check, checkScope, network, failures)) {
              readOnlyChecks.push(check);
            }
          });
        }
      }

      if (
        isContractName(name) &&
        typeof principal === "string" &&
        isTxId(publishTxId) &&
        isRecord(interfaceValue) &&
        interfaceValue.required === true &&
        interfaceValue.expectedContractName === name
      ) {
        validContracts.push({
          name,
          principal,
          publishTxId: normalizeTxId(publishTxId),
          interface: {
            required: true,
            expectedContractName: name,
            ...(Array.isArray(interfaceValue.expectedFunctions)
              ? { expectedFunctions: interfaceValue.expectedFunctions as string[] }
              : {}),
          },
          ...(readOnlyChecks.length > 0 ? { readOnlyChecks } : {}),
        });
      }
    });
  }

  if (failures.length > 0) {
    return { ok: false, failures };
  }

  return {
    ok: true,
    manifest: {
      ...(typeof input.$schema === "string" ? { $schema: input.$schema } : {}),
      schemaVersion: input.schemaVersion as typeof EVIDENCE_SCHEMA_VERSION,
      network: input.network as DeploymentNetwork,
      apiBaseUrl: input.apiBaseUrl as string,
      deployer: input.deployer as string,
      evidence: input.evidence as DeploymentEvidenceManifest["evidence"],
      contracts: validContracts,
    },
    failures: [],
  };
}

async function requestJson(
  fetchImpl: FetchLike,
  url: string,
  init: FetchInitLike,
  timeoutMs = DEFAULT_HIRO_TIMEOUT_MS,
): Promise<HttpResult> {
  const controller = new AbortController();
  let timeoutHandle: ReturnType<typeof setTimeout> | undefined;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutHandle = setTimeout(() => {
      controller.abort();
      reject(new Error("request timeout"));
    }, timeoutMs);
  });

  try {
    let response: FetchResponseLike;
    try {
      response = await Promise.race([
        fetchImpl(url, { ...init, signal: controller.signal }),
        timeoutPromise,
      ]);
    } catch (error) {
      return {
        status: null,
        ok: false,
        error: error instanceof Error && error.message === "request timeout"
          ? "timeout"
          : "network-error",
      };
    }

    let data: unknown;
    try {
      data = await Promise.race([response.json(), timeoutPromise]);
    } catch (error) {
      if (error instanceof Error && error.message === "request timeout") {
        return { status: response.status, ok: false, error: "timeout" };
      }
      return {
        status: response.status,
        ok: false,
        error: "invalid-json",
      };
    }

    return {
      status: response.status,
      ok: response.ok && response.status >= 200 && response.status < 300,
      data,
    };
  } finally {
    if (timeoutHandle !== undefined) {
      clearTimeout(timeoutHandle);
    }
  }
}

export function createHiroApi(options: {
  baseUrl: string;
  fetchImpl?: FetchLike;
  apiKey?: string;
  timeoutMs?: number;
}): HiroApi {
  const baseUrl = options.baseUrl.replace(/\/+$/, "");
  const timeoutMs = options.timeoutMs ?? DEFAULT_HIRO_TIMEOUT_MS;
  const fetchImpl: FetchLike =
    options.fetchImpl ??
    ((url, init) =>
      fetch(url, init).then((response) => response as unknown as FetchResponseLike));
  const headers: Record<string, string> = {
    accept: "application/json",
  };

  if (options.apiKey) {
    headers["x-hiro-api-key"] = options.apiKey;
  }

  return {
    getTransaction(txId) {
      return requestJson(
        fetchImpl,
        `${baseUrl}/extended/v1/tx/${encodeURIComponent(txId)}`,
        {
          method: "GET",
          headers,
        },
        timeoutMs,
      );
    },
    getContractInterface(principal) {
      return requestJson(
        fetchImpl,
        `${baseUrl}/extended/v1/contract/${encodeURIComponent(principal)}/interface`,
        {
          method: "GET",
          headers,
        },
        timeoutMs,
      );
    },
    callReadOnly(principal, functionName, request) {
      return requestJson(
        fetchImpl,
        `${baseUrl}/v2/contracts/call-read/${encodeURIComponent(principal)}/${encodeURIComponent(functionName)}`,
        {
          method: "POST",
          headers: {
            ...headers,
            "content-type": "application/json",
          },
          body: JSON.stringify({
            sender: request.sender,
            arguments: request.arguments,
          }),
        },
        timeoutMs,
      );
    },
  };
}

function transactionContractId(transaction: RecordValue): string | undefined {
  if (typeof transaction.contract_id === "string") {
    return transaction.contract_id;
  }
  if (isRecord(transaction.smart_contract) && typeof transaction.smart_contract.contract_id === "string") {
    return transaction.smart_contract.contract_id;
  }
  return undefined;
}

function transactionStatus(transaction: RecordValue): string | undefined {
  return typeof transaction.tx_status === "string" ? transaction.tx_status : undefined;
}

function responseFailure(
  result: HttpResult,
  scope: string,
  notFoundClassification: FailureClassification,
  notFoundMessage: string,
  apiErrorClassification: FailureClassification,
  apiErrorMessage: string,
): VerificationFailure {
  if (result.status === 404) {
    return failure(notFoundClassification, scope, notFoundMessage, result.status);
  }
  return failure(
    apiErrorClassification,
    scope,
    result.error === "network-error"
      ? `${apiErrorMessage}; the Hiro API request failed before a response was received`
      : result.error === "timeout"
        ? `${apiErrorMessage}; the Hiro API request timed out`
      : result.error === "invalid-json"
        ? `${apiErrorMessage}; Hiro returned invalid JSON`
        : `${apiErrorMessage}; Hiro returned HTTP ${String(result.status)}`,
    result.status === null ? undefined : result.status,
  );
}

function verifyTransaction(
  contract: ContractEvidence,
  manifest: DeploymentEvidenceManifest,
  result: HttpResult,
): { summary?: TransactionEvidenceSummary; failures: VerificationFailure[] } {
  const scope = `${contract.name}.publishTxId`;
  if (!result.ok) {
    return {
      failures: [
        responseFailure(
          result,
          scope,
          "missing-transaction",
          "No evidence was found at the documented transaction ID; this is not a claim of global nonexistence",
          "transaction-api-error",
          "Unable to retrieve the documented publish transaction",
        ),
      ],
    };
  }

  if (!isRecord(result.data)) {
    return {
      failures: [failure("transaction-api-error", scope, "Hiro returned a malformed transaction response")],
    };
  }

  const transaction = result.data;
  const failures: VerificationFailure[] = [];
  const txId = typeof transaction.tx_id === "string" ? normalizeTxId(transaction.tx_id) : undefined;
  const expectedTxId = normalizeTxId(contract.publishTxId);
  if (!txId) {
    failures.push(failure("transaction-api-error", scope, "Hiro transaction response omitted tx_id"));
  } else if (txId !== expectedTxId) {
    failures.push(
      failure(
        "transaction-id-mismatch",
        scope,
        "Hiro returned a different transaction ID than the manifest documented",
      ),
    );
  }

  if (transaction.tx_type !== "smart_contract") {
    failures.push(
      failure(
        "contract-mismatch",
        scope,
        "documented publish transaction is not a smart-contract transaction",
      ),
    );
  }

  if (transaction.sender_address !== manifest.deployer) {
    failures.push(
      failure(
        "deployer-mismatch",
        scope,
        "publish transaction sender does not match the expected deployer",
      ),
    );
  }

  const contractId = transactionContractId(transaction);
  if (contractId !== contract.principal) {
    failures.push(
      failure(
        "contract-mismatch",
        scope,
        "publish transaction contract principal does not match the exact manifest principal",
      ),
    );
  }

  const status = transactionStatus(transaction);
  if (status === "pending" || status === "mempool") {
    failures.push(
      failure(
        "transaction-pending",
        scope,
        "publish transaction is pending or still in the mempool; confirmation is not proven",
      ),
    );
  } else if (status !== "success") {
    failures.push(
      failure(
        "transaction-failed",
        scope,
        `publish transaction did not complete successfully (status: ${status ?? "missing"})`,
      ),
    );
  }

  if (status === "success" && transaction.canonical !== true) {
    failures.push(
      failure(
        "transaction-noncanonical",
        scope,
        "publish transaction is not explicitly canonical; confirmation is not proven",
      ),
    );
  }

  const blockHash = typeof transaction.block_hash === "string" ? transaction.block_hash : "";
  const blockHeight = transaction.block_height;
  if (
    status === "success" &&
    transaction.canonical === true &&
    (!isCanonicalBlockHash(blockHash) ||
      typeof blockHeight !== "number" ||
      !Number.isInteger(blockHeight) ||
      blockHeight <= 0)
  ) {
    failures.push(
      failure(
        "transaction-unconfirmed",
        scope,
        "successful canonical transaction lacks a canonical 32-byte Hiro block hash and positive block height",
      ),
    );
  }

  if (failures.length > 0) {
    return { failures };
  }

  return {
    summary: {
      txId: expectedTxId,
      status: "success",
      sender: manifest.deployer,
      contractId: contract.principal,
      canonical: true,
      blockHash,
      blockHeight: blockHeight as number,
    },
    failures: [],
  };
}

function verifyContractInterface(
  contract: ContractEvidence,
  result: HttpResult,
): { summary?: InterfaceEvidenceSummary; failures: VerificationFailure[] } {
  const scope = `${contract.name}.interface`;
  if (!result.ok) {
    return {
      failures: [
        responseFailure(
          result,
          scope,
          "interface-missing",
          "No interface evidence was found at the documented contract address; this is not a claim of global nonexistence",
          "interface-api-error",
          "Unable to retrieve the documented contract interface",
        ),
      ],
    };
  }

  if (!isRecord(result.data) || !Array.isArray(result.data.functions)) {
    return {
      failures: [
        failure(
          "interface-api-error",
          scope,
          "Hiro returned a malformed contract interface response",
        ),
      ],
    };
  }

  const interfaceData = result.data;
  if (
    typeof interfaceData.contract_id !== "string" ||
    interfaceData.contract_id !== contract.principal
  ) {
    return {
      failures: [
        failure(
          "interface-mismatch",
          scope,
          "Hiro interface response must include contract_id exactly equal to the manifest principal",
        ),
      ],
    };
  }

  const functions = interfaceData.functions as unknown[];
  const functionNames = functions
    .filter(isRecord)
    .map((entry) => entry.name)
    .filter((name): name is string => typeof name === "string");
  const expectedFunctions = contract.interface.expectedFunctions ?? [];
  const missingFunctions = expectedFunctions.filter((name) => !functionNames.includes(name));
  if (missingFunctions.length > 0) {
    return {
      failures: [
        failure(
          "interface-mismatch",
          scope,
          `required interface functions are missing: ${missingFunctions.join(", ")}`,
        ),
      ],
    };
  }

  return {
    summary: {
      available: true,
      contractId: interfaceData.contract_id,
      functionCount: functions.length,
      expectedFunctionsChecked: expectedFunctions,
    },
    failures: [],
  };
}

function verifyReadOnly(
  contract: ContractEvidence,
  check: ReadOnlyCheck,
  result: HttpResult,
  index: number,
): { summary?: ReadOnlyEvidenceSummary; failures: VerificationFailure[] } {
  const scope = `${contract.name}.readOnlyChecks[${index}]`;
  if (!result.ok) {
    return {
      failures: [
        responseFailure(
          result,
          scope,
          "read-only-missing",
          "No read-only evidence was found for the declared check at the documented contract address",
          "read-only-api-error",
          "Unable to execute the declared read-only check",
        ),
      ],
    };
  }

  if (
    !isRecord(result.data) ||
    result.data.okay !== true ||
    !isHex(result.data.result)
  ) {
    return {
      failures: [
        failure(
          "read-only-api-error",
          scope,
          "Hiro returned a read-only response that was not an okay result with a hex value",
        ),
      ],
    };
  }

  const actualResultHex = result.data.result.toLowerCase();
  const expectedResultHex = check.expectedResultHex.toLowerCase();
  if (actualResultHex !== expectedResultHex) {
    return {
      failures: [
        failure(
          "read-only-mismatch",
          scope,
          `read-only result for ${check.function} did not match the declared expected result`,
        ),
      ],
    };
  }

  return {
    summary: {
      function: check.function,
      sender: check.sender,
      expectedResultHex,
      actualResultHex,
    },
    failures: [],
  };
}

function validateCompleteEvidenceBinding(expected: unknown): VerificationFailure[] {
  const failures: VerificationFailure[] = [];

  if (!isRecord(expected)) {
    return [
      failure(
        "evidence-binding-mismatch",
        "expected-binding",
        "complete verification binding is required: network, deployer, deployed git commit, canonical plan path, and plan SHA-256",
      ),
    ];
  }

  const network = expected.network;
  const deployer = expected.deployer;
  const gitCommit = expected.gitCommit;
  const planPath = expected.planPath;
  const planSha256 = expected.planSha256;

  if (!isDeploymentNetwork(network)) {
    failures.push(
      failure(
        "evidence-binding-mismatch",
        "expected-binding.network",
        "expected verification network must be testnet or mainnet",
      ),
    );
  }

  if (
    !isDeploymentNetwork(network) ||
    typeof deployer !== "string" ||
    !isCanonicalStacksAddress(deployer, network)
  ) {
    failures.push(
      failure(
        "evidence-binding-mismatch",
        "expected-binding.deployer",
        "expected deployer must be a canonical Stacks address for the explicit verification network",
      ),
    );
  }

  if (typeof gitCommit !== "string" || !COMMIT_PATTERN.test(gitCommit)) {
    failures.push(
      failure(
        "evidence-binding-mismatch",
        "expected-binding.gitCommit",
        "expected deployed git commit must be a 40-character commit SHA",
      ),
    );
  }

  if (
    typeof planPath !== "string" ||
    !isDeploymentNetwork(network) ||
    planPath !== CANONICAL_PLAN_PATHS[network]
  ) {
    failures.push(
      failure(
        "evidence-binding-mismatch",
        "expected-binding.planPath",
        isDeploymentNetwork(network)
          ? `expected plan path must be the canonical ${network} path: ${CANONICAL_PLAN_PATHS[network]}`
          : "expected plan path cannot be validated until the network is testnet or mainnet",
      ),
    );
  }

  if (typeof planSha256 !== "string" || !SHA256_PATTERN.test(planSha256)) {
    failures.push(
      failure(
        "evidence-binding-mismatch",
        "expected-binding.planSha256",
        "expected plan SHA-256 must be a 64-character digest",
      ),
    );
  }

  return failures;
}

export function validateEvidenceBinding(
  manifest: DeploymentEvidenceManifest,
  expected: EvidenceBinding,
): VerificationFailure[] {
  const failures = validateCompleteEvidenceBinding(expected);
  if (failures.length > 0) {
    return failures;
  }

  const binding = expected as EvidenceBinding;

  if (manifest.network !== binding.network) {
    failures.push(
      failure(
        "evidence-binding-mismatch",
        "evidence.network",
        "evidence network does not match the explicitly expected verification network",
      ),
    );
  }

  if (manifest.deployer !== binding.deployer) {
    failures.push(
      failure(
        "evidence-binding-mismatch",
        "deployer",
        "manifest deployer does not match the explicitly expected deployer",
      ),
    );
  }

  if (manifest.evidence.gitCommit.toLowerCase() !== binding.gitCommit.toLowerCase()) {
    failures.push(
      failure(
        "evidence-binding-mismatch",
        "evidence.gitCommit",
        "evidence git commit does not match the explicitly deployed commit",
      ),
    );
  }

  if (manifest.evidence.planPath !== binding.planPath) {
    failures.push(
      failure(
        "evidence-binding-mismatch",
        "evidence.planPath",
        "evidence plan path does not match the explicitly verified plan path",
      ),
    );
  }

  if (manifest.evidence.planSha256.toLowerCase() !== binding.planSha256.toLowerCase()) {
    failures.push(
      failure(
        "evidence-binding-mismatch",
        "evidence.planSha256",
        "evidence plan SHA-256 does not match the explicitly verified plan digest",
      ),
    );
  }

  return failures;
}

async function safeApiCall(call: () => Promise<HttpResult>): Promise<HttpResult> {
  try {
    const result = await call();
    if (
      !isRecord(result) ||
      typeof result.ok !== "boolean" ||
      (typeof result.status !== "number" && result.status !== null)
    ) {
      return { status: null, ok: false, error: "network-error" };
    }
    return result as HttpResult;
  } catch {
    return { status: null, ok: false, error: "network-error" };
  }
}

export async function verifyDeploymentEvidence(
  input: unknown,
  api: HiroApi,
  expectedBinding: EvidenceBinding,
): Promise<VerificationReport> {
  const validation = validateManifest(input);
  if (!validation.ok || !validation.manifest) {
    const raw = isRecord(input) ? input : undefined;
    return {
      verifierVersion: VERIFIER_VERSION,
      ...(typeof raw?.schemaVersion === "string" ? { schemaVersion: raw.schemaVersion } : {}),
      ok: false,
      ...(raw?.network === "testnet" || raw?.network === "mainnet"
        ? { network: raw.network }
        : {}),
      ...(typeof raw?.apiBaseUrl === "string" ? { apiBaseUrl: raw.apiBaseUrl } : {}),
      ...(typeof raw?.deployer === "string" ? { deployer: raw.deployer } : {}),
      scope: "documented-transaction-ids-and-contract-addresses-only",
      claim: "no deployment is verified",
      contracts: [],
      failures: validation.failures,
    };
  }

  const manifest = validation.manifest;
  const bindingFailures = validateEvidenceBinding(manifest, expectedBinding);
  if (bindingFailures.length > 0) {
    return {
      verifierVersion: VERIFIER_VERSION,
      schemaVersion: manifest.schemaVersion,
      ok: false,
      network: manifest.network,
      apiBaseUrl: manifest.apiBaseUrl,
      deployer: manifest.deployer,
      scope: "documented-transaction-ids-and-contract-addresses-only",
      claim: "no deployment is verified",
      contracts: [],
      failures: bindingFailures,
    };
  }

  const contracts: ContractVerificationReport[] = [];
  const failures: VerificationFailure[] = [];

  for (const contract of manifest.contracts) {
    const contractReport: ContractVerificationReport = {
      name: contract.name,
      principal: contract.principal,
      publishTxId: contract.publishTxId,
      readOnlyChecks: [],
      failures: [],
    };

    const transactionResult = await safeApiCall(() => api.getTransaction(contract.publishTxId));
    const transactionVerification = verifyTransaction(contract, manifest, transactionResult);
    if (transactionVerification.summary) {
      contractReport.transaction = transactionVerification.summary;
    }
    contractReport.failures.push(...transactionVerification.failures);

    const interfaceResult = await safeApiCall(() => api.getContractInterface(contract.principal));
    const interfaceVerification = verifyContractInterface(contract, interfaceResult);
    if (interfaceVerification.summary) {
      contractReport.contractInterface = interfaceVerification.summary;
    }
    contractReport.failures.push(...interfaceVerification.failures);

    if (contract.readOnlyChecks && contract.readOnlyChecks.length > 0) {
      if (!contractReport.transaction || !contractReport.contractInterface) {
        contract.readOnlyChecks.forEach((_, index) => {
          contractReport.failures.push(
            failure(
              "read-only-not-checked",
              `${contract.name}.readOnlyChecks[${index}]`,
              "read-only check was not executed because publish receipt and interface evidence were not both verified",
            ),
          );
        });
      } else {
        for (const [index, check] of contract.readOnlyChecks.entries()) {
          const readOnlyResult = await safeApiCall(() =>
            api.callReadOnly(contract.principal, check.function, check),
          );
          const readOnlyVerification = verifyReadOnly(contract, check, readOnlyResult, index);
          if (readOnlyVerification.summary) {
            contractReport.readOnlyChecks.push(readOnlyVerification.summary);
          }
          contractReport.failures.push(...readOnlyVerification.failures);
        }
      }
    }

    contracts.push(contractReport);
    failures.push(...contractReport.failures);
  }

  return {
    verifierVersion: VERIFIER_VERSION,
    schemaVersion: manifest.schemaVersion,
    ok: failures.length === 0,
    network: manifest.network,
    apiBaseUrl: manifest.apiBaseUrl,
    deployer: manifest.deployer,
    scope: "documented-transaction-ids-and-contract-addresses-only",
    claim: failures.length === 0 ? "declared evidence entries verified" : "no deployment is verified",
    contracts,
    failures,
  };
}

export function parseCliArgs(args: string[]): {
  manifestPath: string;
  outputPath?: string;
  expectedBinding: EvidenceBinding;
} {
  let manifestPath: string | undefined;
  let outputPath: string | undefined;
  let expectedNetwork: DeploymentNetwork | undefined;
  let expectedDeployer: string | undefined;
  let expectedGitCommit: string | undefined;
  let expectedPlanPath: string | undefined;
  let expectedPlanSha256: string | undefined;

  const valueFor = (arg: string, index: number): string => {
    const value = args[index + 1];
    if (!value || value.startsWith("--")) {
      throw new Error(`${arg} requires a value`);
    }
    return value;
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--manifest") {
      manifestPath = valueFor(arg, index);
      index += 1;
    } else if (arg === "--output") {
      outputPath = valueFor(arg, index);
      index += 1;
    } else if (arg === "--expected-network") {
      const value = valueFor(arg, index);
      if (!isDeploymentNetwork(value)) {
        throw new Error("--expected-network must be testnet or mainnet");
      }
      expectedNetwork = value;
      index += 1;
    } else if (arg === "--expected-deployer") {
      expectedDeployer = valueFor(arg, index);
      index += 1;
    } else if (arg === "--expected-git-commit") {
      expectedGitCommit = valueFor(arg, index);
      index += 1;
    } else if (arg === "--expected-plan-path") {
      expectedPlanPath = valueFor(arg, index);
      index += 1;
    } else if (arg === "--expected-plan-sha256") {
      expectedPlanSha256 = valueFor(arg, index);
      index += 1;
    } else if (arg === "--help" || arg === "-h") {
      console.error(
        "Usage: npx tsx scripts/verify-deployment-evidence.ts --manifest <path> --expected-network <testnet|mainnet> --expected-deployer <address> --expected-git-commit <sha> --expected-plan-path <canonical-plan-path> --expected-plan-sha256 <sha256> [--output <path>]",
      );
      process.exit(0);
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  if (!manifestPath) {
    throw new Error(
      "--manifest is required; plans, workflow success, and broadcast-only IDs cannot verify deployment",
    );
  }

  const bindingValues = [
    expectedNetwork,
    expectedDeployer,
    expectedGitCommit,
    expectedPlanPath,
    expectedPlanSha256,
  ];
  const hasCompleteBinding = bindingValues.every((value) => value !== undefined);
  if (!hasCompleteBinding) {
    throw new Error(
      "all five verification binding flags are required: network, deployer, git commit, canonical plan path, and plan SHA-256",
    );
  }

  const bindingNetwork = expectedNetwork as DeploymentNetwork;
  const bindingPlanPath = expectedPlanPath as string;
  if (bindingPlanPath !== CANONICAL_PLAN_PATHS[bindingNetwork]) {
    throw new Error(
      `--expected-plan-path must be the canonical ${bindingNetwork} path: ${CANONICAL_PLAN_PATHS[bindingNetwork]}`,
    );
  }

  return {
    manifestPath,
    outputPath,
    expectedBinding: {
      network: bindingNetwork,
      deployer: expectedDeployer as string,
      gitCommit: expectedGitCommit as string,
      planPath: bindingPlanPath,
      planSha256: expectedPlanSha256 as string,
    },
  };
}

export async function runCli(args = process.argv.slice(2)): Promise<number> {
  const { manifestPath, outputPath, expectedBinding } = parseCliArgs(args);
  const rawManifest = JSON.parse(readFileSync(resolve(manifestPath), "utf8")) as unknown;

  const validation = validateManifest(rawManifest);
  let report: VerificationReport;
  if (!validation.ok || !validation.manifest) {
    report = await verifyDeploymentEvidence(rawManifest, {
      getTransaction: async () => ({ status: null, ok: false }),
      getContractInterface: async () => ({ status: null, ok: false }),
      callReadOnly: async () => ({ status: null, ok: false }),
    }, expectedBinding);
  } else {
    const api = createHiroApi({
      baseUrl: validation.manifest.apiBaseUrl,
      apiKey: process.env.HIRO_API_KEY,
    });
    report = await verifyDeploymentEvidence(validation.manifest, api, expectedBinding);
  }

  const serialized = `${JSON.stringify(report, null, 2)}\n`;
  if (outputPath) {
    writeFileSync(resolve(outputPath), serialized, "utf8");
  }
  process.stdout.write(serialized);
  return report.ok ? 0 : 1;
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : undefined;
if (invokedPath && pathToFileURL(invokedPath).href === import.meta.url) {
  runCli().then(
    (exitCode) => {
      process.exitCode = exitCode;
    },
    (error: unknown) => {
      process.stderr.write(`${error instanceof Error ? error.message : "verification failed"}\n`);
      process.exitCode = 2;
    },
  );
}
