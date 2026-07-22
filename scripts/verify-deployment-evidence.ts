import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export const VERIFIER_VERSION = "1.0.0";
export const EVIDENCE_SCHEMA_VERSION = "1.0.0";

export const NETWORK_API_BASE_URLS = {
  testnet: "https://api.testnet.hiro.so",
  mainnet: "https://api.mainnet.hiro.so",
} as const;

export type DeploymentNetwork = keyof typeof NETWORK_API_BASE_URLS;

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
  | "read-only-not-checked";

export interface DeploymentEvidenceManifest {
  $schema?: string;
  schemaVersion: typeof EVIDENCE_SCHEMA_VERSION;
  network: DeploymentNetwork;
  apiBaseUrl: string;
  deployer: string;
  evidence: {
    source: "confirmed-receipts";
    capturedAt: string;
    gitCommit?: string;
    planPath?: string;
    planSha256?: string;
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
  contractId?: string;
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
  contracts: ContractVerificationReport[];
  failures: VerificationFailure[];
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
  error?: "network-error" | "invalid-json";
}

interface RecordValue {
  [key: string]: unknown;
}

const ADDRESS_PATTERN = /^S[TP][0-9A-Z]{39}$/;
const CONTRACT_NAME_PATTERN = /^[a-z][a-z0-9-]{0,127}$/;
const TX_ID_PATTERN = /^(?:0x)?[0-9a-f]{64}$/i;
const HEX_PATTERN = /^0x[0-9a-f]*$/i;
const SHA256_PATTERN = /^[0-9a-f]{64}$/i;

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

function isAddress(value: unknown): value is string {
  return typeof value === "string" && ADDRESS_PATTERN.test(value);
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

  if (
    (network === "testnet" || network === "mainnet") &&
    apiBaseUrl.replace(/\/$/, "") !== NETWORK_API_BASE_URLS[network]
  ) {
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

  if (!isAddress(value.sender)) {
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
    isAddress(value.sender) &&
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

  if (input.network !== "testnet" && input.network !== "mainnet") {
    failures.push(
      failure(
        "malformed-manifest",
        "network",
        "network must be explicitly set to testnet or mainnet",
      ),
    );
  }

  validateApiBaseUrl(input.network, input.apiBaseUrl, failures);

  if (!isAddress(input.deployer)) {
    failures.push(
      failure("malformed-manifest", "deployer", "deployer must be a valid Stacks address"),
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

    if (
      typeof input.evidence.capturedAt !== "string" ||
      Number.isNaN(Date.parse(input.evidence.capturedAt))
    ) {
      failures.push(
        failure(
          "malformed-manifest",
          "evidence.capturedAt",
          "evidence.capturedAt must be an ISO-8601 timestamp",
        ),
      );
    }

    if (
      input.evidence.gitCommit !== undefined &&
      (typeof input.evidence.gitCommit !== "string" ||
        !/^[0-9a-f]{40}$/i.test(input.evidence.gitCommit))
    ) {
      failures.push(
        failure(
          "malformed-manifest",
          "evidence.gitCommit",
          "evidence.gitCommit must be a 40-character commit SHA when provided",
        ),
      );
    }

    if (
      input.evidence.planSha256 !== undefined &&
      (typeof input.evidence.planSha256 !== "string" ||
        !SHA256_PATTERN.test(input.evidence.planSha256))
    ) {
      failures.push(
        failure(
          "malformed-manifest",
          "evidence.planSha256",
          "evidence.planSha256 must be a 64-character SHA-256 digest when provided",
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
        !isAddress(principalParts[1]) ||
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
        if (isAddress(input.deployer) && principalParts[1] !== input.deployer) {
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
            if (validateReadOnlyCheck(check, checkScope, failures)) {
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
      apiBaseUrl: (input.apiBaseUrl as string).replace(/\/$/, ""),
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
): Promise<HttpResult> {
  let response: FetchResponseLike;
  try {
    response = await fetchImpl(url, init);
  } catch {
    return { status: null, ok: false, error: "network-error" };
  }

  let data: unknown;
  try {
    data = await response.json();
  } catch {
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
}

export function createHiroApi(options: {
  baseUrl: string;
  fetchImpl?: FetchLike;
  apiKey?: string;
}): HiroApi {
  const baseUrl = options.baseUrl.replace(/\/$/, "");
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
      return requestJson(fetchImpl, `${baseUrl}/extended/v1/tx/${encodeURIComponent(txId)}`, {
        method: "GET",
        headers,
      });
    },
    getContractInterface(principal) {
      return requestJson(
        fetchImpl,
        `${baseUrl}/extended/v1/contract/${encodeURIComponent(principal)}/interface`,
        {
          method: "GET",
          headers,
        },
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
    (blockHash.length === 0 || typeof blockHeight !== "number" || !Number.isInteger(blockHeight) || blockHeight <= 0)
  ) {
    failures.push(
      failure(
        "transaction-unconfirmed",
        scope,
        "successful canonical transaction lacks confirmed block metadata",
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
    typeof interfaceData.contract_id === "string" &&
    interfaceData.contract_id !== contract.principal
  ) {
    return {
      failures: [
        failure(
          "interface-mismatch",
          scope,
          "Hiro interface response identifies a different contract principal",
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
      ...(typeof interfaceData.contract_id === "string"
        ? { contractId: interfaceData.contract_id }
        : {}),
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

  if (!isRecord(result.data) || result.data.okay !== true || typeof result.data.result !== "string") {
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

export async function verifyDeploymentEvidence(
  input: unknown,
  api: HiroApi,
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
      contracts: [],
      failures: validation.failures,
    };
  }

  const manifest = validation.manifest;
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

    const transactionResult = await api.getTransaction(contract.publishTxId);
    const transactionVerification = verifyTransaction(contract, manifest, transactionResult);
    if (transactionVerification.summary) {
      contractReport.transaction = transactionVerification.summary;
    }
    contractReport.failures.push(...transactionVerification.failures);

    const interfaceResult = await api.getContractInterface(contract.principal);
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
          const readOnlyResult = await api.callReadOnly(contract.principal, check.function, check);
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
    contracts,
    failures,
  };
}

function parseCliArgs(args: string[]): { manifestPath: string; outputPath?: string } {
  let manifestPath: string | undefined;
  let outputPath: string | undefined;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--manifest") {
      manifestPath = args[index + 1];
      index += 1;
    } else if (arg === "--output") {
      outputPath = args[index + 1];
      index += 1;
    } else if (arg === "--help" || arg === "-h") {
      console.error(
        "Usage: npx tsx scripts/verify-deployment-evidence.ts --manifest <path> [--output <path>]",
      );
      process.exit(0);
    }
  }

  if (!manifestPath) {
    throw new Error(
      "--manifest is required; plans, workflow success, and broadcast-only IDs cannot verify deployment",
    );
  }

  return { manifestPath, outputPath };
}

export async function runCli(args = process.argv.slice(2)): Promise<number> {
  const { manifestPath, outputPath } = parseCliArgs(args);
  const rawManifest = JSON.parse(readFileSync(resolve(manifestPath), "utf8")) as unknown;

  const validation = validateManifest(rawManifest);
  let report: VerificationReport;
  if (!validation.ok || !validation.manifest) {
    report = await verifyDeploymentEvidence(rawManifest, {
      getTransaction: async () => ({ status: null, ok: false }),
      getContractInterface: async () => ({ status: null, ok: false }),
      callReadOnly: async () => ({ status: null, ok: false }),
    });
  } else {
    const api = createHiroApi({
      baseUrl: validation.manifest.apiBaseUrl,
      apiKey: process.env.HIRO_API_KEY,
    });
    report = await verifyDeploymentEvidence(validation.manifest, api);
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
