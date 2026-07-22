import { createHash } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

export type DeploymentNetwork = "testnet" | "mainnet";
export type EvidenceStatus = "plan" | "workflow" | "broadcast" | "confirmed";
export type DeploymentTransactionKind = "contract-publish" | "contract-call";
export type InterfaceAccess = "public" | "read_only";

export interface RequiredFunction {
  name: string;
  access: InterfaceAccess;
}

export interface ContractPublicationEvidence {
  kind: "contract-publish";
  contractName: string;
  contractId: string;
  expectedSender: string;
  txid: string;
  apiEvidence?: TransactionApiEvidence;
}

export interface ContractCallEvidence {
  kind: "contract-call";
  contractId: string;
  functionName: string;
  expectedSender: string;
  txid: string;
  apiEvidence?: TransactionApiEvidence;
}

export interface InterfaceExpectation {
  contractId: string;
  requiredFunctions: RequiredFunction[];
  interfaceEvidence?: InterfaceApiEvidence;
}

export interface TransactionApiEvidence {
  observedAt: string;
  endpoint: string;
  txId: string;
  txStatus: "success";
  canonical: true;
  isUnanchored: false;
  txType: "smart_contract" | "contract_call";
  senderAddress: string;
  contractId: string;
  functionName: string | null;
  blockHash: string;
  blockHeight: number;
  burnBlockHash: string;
  burnBlockHeight: number;
  blockTimeIso?: string;
  burnBlockTimeIso?: string;
}

export interface InterfaceApiEvidence {
  observedAt: string;
  endpoint: string;
  httpStatus: 200;
  functions: RequiredFunction[];
}

export interface DeploymentEvidence {
  schemaVersion: "1";
  evidenceStatus: EvidenceStatus;
  generatedAt: string;
  verifiedAt?: string;
  sourceCommit: string;
  network: DeploymentNetwork;
  deployer: string;
  plan: {
    path: string;
    sha256: string;
  };
  claims: {
    scope: "checked-addresses";
    globalNonexistence: false;
  };
  contractPublications: ContractPublicationEvidence[];
  contractCalls: ContractCallEvidence[];
  interfaces: InterfaceExpectation[];
  preexistingContracts?: string[];
}

export interface VerifyEvidenceOptions {
  network: DeploymentNetwork;
  deployer: string;
  baseUrl?: string;
  apiKey?: string;
  planPath?: string;
  sourceCommit?: string;
  fetcher?: typeof fetch;
  now?: () => Date;
}

export interface WaitForEvidenceOptions extends VerifyEvidenceOptions {
  timeoutMs?: number;
  pollIntervalMs?: number;
  sleep?: (milliseconds: number) => Promise<void>;
}

export class DeploymentVerificationError extends Error {
  readonly code: string;
  readonly retryable: boolean;

  constructor(message: string, code: string, retryable = false) {
    super(message);
    this.name = "DeploymentVerificationError";
    this.code = code;
    this.retryable = retryable;
  }
}

export const HIRO_API_BASE_URLS: Readonly<Record<DeploymentNetwork, string>> = {
  testnet: "https://api.testnet.hiro.so",
  mainnet: "https://api.mainnet.hiro.so",
};

const TXID_PATTERN = /^0x[0-9a-fA-F]{64}$/;
const HASH_PATTERN = /^[0-9a-f]{64}$/;
const COMMIT_PATTERN = /^[0-9a-f]{40}$/;
const ADDRESS_PATTERN = /^S[PT][0-9A-Z]{39}$/;
const CONTRACT_NAME_PATTERN = /^[a-zA-Z][a-zA-Z0-9-]{0,39}$/;
const ISO_TIMESTAMP_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/;

type JsonObject = Record<string, unknown>;

interface HttpJsonResponse {
  status: number;
  body: unknown;
}

function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function assertCondition(
  condition: unknown,
  message: string,
  code = "MALFORMED_EVIDENCE",
  retryable = false,
): asserts condition {
  if (!condition) {
    throw new DeploymentVerificationError(message, code, retryable);
  }
}

function assertOnlyKeys(value: JsonObject, allowed: readonly string[], path: string, code = "MALFORMED_EVIDENCE"): void {
  for (const key of Object.keys(value)) {
    assertCondition(allowed.includes(key), `${path}.${key} is not allowed in the evidence schema`, code);
  }
}

function assertIsoTimestamp(value: unknown, path: string, code = "MALFORMED_EVIDENCE"): asserts value is string {
  assertCondition(
    typeof value === "string" && ISO_TIMESTAMP_PATTERN.test(value) && !Number.isNaN(Date.parse(value)),
    `${path} must be an ISO-8601 UTC timestamp`,
    code,
  );
}

function assertAddress(value: unknown, path: string): asserts value is string {
  assertCondition(
    typeof value === "string" && ADDRESS_PATTERN.test(value),
    `${path} must be a valid Stacks standard address`,
  );
}

function assertContractName(value: unknown, path: string): asserts value is string {
  assertCondition(
    typeof value === "string" && CONTRACT_NAME_PATTERN.test(value),
    `${path} must be a valid Clarity contract name`,
  );
}

function assertTxid(value: unknown, path: string): asserts value is string {
  assertCondition(
    typeof value === "string" && TXID_PATTERN.test(value),
    `${path} must be a non-empty 0x-prefixed 32-byte transaction ID`,
  );
}

function assertHash(value: unknown, path: string): asserts value is string {
  assertCondition(
    typeof value === "string" && HASH_PATTERN.test(value),
    `${path} must be a lowercase SHA-256 hash`,
  );
}

function assertCommit(value: unknown, path: string): asserts value is string {
  assertCondition(
    typeof value === "string" && COMMIT_PATTERN.test(value),
    `${path} must be a full 40-character lowercase Git commit SHA`,
  );
}

function assertContractId(value: unknown, path: string): asserts value is string {
  assertCondition(typeof value === "string" && value.includes("."), `${path} must be an address.contract-name identifier`);
  const separator = value.lastIndexOf(".");
  assertAddress(value.slice(0, separator), `${path} address`);
  assertContractName(value.slice(separator + 1), `${path} contract name`);
}

function assertNetworkDeployer(network: DeploymentNetwork, deployer: string): void {
  assertAddress(deployer, "deployer");
  const expectedPrefix = network === "mainnet" ? "SP" : "ST";
  assertCondition(
    deployer.startsWith(expectedPrefix),
    `deployer ${deployer} does not match ${network} address prefix ${expectedPrefix}`,
    "NETWORK_DEPLOYER_MISMATCH",
  );
}

function assertRecordedTransactionEvidence(value: unknown, path: string): void {
  assertCondition(isObject(value), `${path} must be an object`);
  assertOnlyKeys(
    value,
    [
      "observedAt",
      "endpoint",
      "txId",
      "txStatus",
      "canonical",
      "isUnanchored",
      "txType",
      "senderAddress",
      "contractId",
      "functionName",
      "blockHash",
      "blockHeight",
      "burnBlockHash",
      "burnBlockHeight",
      "blockTimeIso",
      "burnBlockTimeIso",
    ],
    path,
  );
  assertIsoTimestamp(value.observedAt, `${path}.observedAt`);
  assertCondition(isNonEmptyString(value.endpoint), `${path}.endpoint must be non-empty`);
  assertTxid(value.txId, `${path}.txId`);
  assertCondition(value.txStatus === "success", `${path}.txStatus must be success`);
  assertCondition(value.canonical === true, `${path}.canonical must be true`);
  assertCondition(value.isUnanchored === false, `${path}.isUnanchored must be false`);
  assertCondition(
    value.txType === "smart_contract" || value.txType === "contract_call",
    `${path}.txType is unsupported`,
  );
  assertAddress(value.senderAddress, `${path}.senderAddress`);
  assertContractId(value.contractId, `${path}.contractId`);
  assertCondition(value.functionName === null || isNonEmptyString(value.functionName), `${path}.functionName is invalid`);
  assertCondition(isNonEmptyString(value.blockHash), `${path}.blockHash must be non-empty`);
  assertCondition(Number.isInteger(value.blockHeight) && (value.blockHeight as number) > 0, `${path}.blockHeight is invalid`);
  assertCondition(isNonEmptyString(value.burnBlockHash), `${path}.burnBlockHash must be non-empty`);
  assertCondition(
    Number.isInteger(value.burnBlockHeight) && (value.burnBlockHeight as number) > 0,
    `${path}.burnBlockHeight is invalid`,
  );
  if (value.blockTimeIso !== undefined) assertIsoTimestamp(value.blockTimeIso, `${path}.blockTimeIso`);
  if (value.burnBlockTimeIso !== undefined) assertIsoTimestamp(value.burnBlockTimeIso, `${path}.burnBlockTimeIso`);
}

function assertRecordedInterfaceEvidence(value: unknown, path: string): void {
  assertCondition(isObject(value), `${path} must be an object`);
  assertOnlyKeys(value, ["observedAt", "endpoint", "httpStatus", "functions"], path);
  assertIsoTimestamp(value.observedAt, `${path}.observedAt`);
  assertCondition(isNonEmptyString(value.endpoint), `${path}.endpoint must be non-empty`);
  assertCondition(value.httpStatus === 200, `${path}.httpStatus must be 200`);
  assertInterfaceFunctions(value.functions, `${path}.functions`);
}

function assertInterfaceFunctions(
  value: unknown,
  path: string,
  code = "MALFORMED_EVIDENCE",
): asserts value is RequiredFunction[] {
  assertCondition(Array.isArray(value), `${path} must be an array`, code);
  const names = new Set<string>();
  for (const [index, item] of value.entries()) {
    assertCondition(isObject(item), `${path}[${index}] must be an object`, code);
    assertOnlyKeys(item, ["name", "access"], `${path}[${index}]`, code);
    assertCondition(isNonEmptyString(item.name), `${path}[${index}].name must be non-empty`, code);
    assertCondition(item.access === "public" || item.access === "read_only", `${path}[${index}].access is unsupported`, code);
    assertCondition(!names.has(item.name), `${path} contains duplicate function ${item.name}`, code);
    names.add(item.name);
  }
}

function parseEvidenceBundle(value: unknown): DeploymentEvidence {
  assertCondition(isObject(value), "evidence bundle must be a JSON object");
  assertOnlyKeys(
    value,
    [
      "schemaVersion",
      "evidenceStatus",
      "generatedAt",
      "verifiedAt",
      "sourceCommit",
      "network",
      "deployer",
      "plan",
      "claims",
      "contractPublications",
      "contractCalls",
      "interfaces",
      "preexistingContracts",
    ],
    "evidence",
  );
  assertCondition(value.schemaVersion === "1", "evidence bundle schemaVersion must be \"1\"");
  assertCondition(
    value.evidenceStatus === "plan" ||
      value.evidenceStatus === "workflow" ||
      value.evidenceStatus === "broadcast" ||
      value.evidenceStatus === "confirmed",
    "evidence bundle evidenceStatus is unsupported",
  );
  assertIsoTimestamp(value.generatedAt, "generatedAt");
  if (value.verifiedAt !== undefined) assertIsoTimestamp(value.verifiedAt, "verifiedAt");
  assertCommit(value.sourceCommit, "sourceCommit");
  assertCondition(value.network === "testnet" || value.network === "mainnet", "network must be testnet or mainnet");
  assertAddress(value.deployer, "deployer");
  assertCondition(isObject(value.plan), "plan must be an object");
  assertOnlyKeys(value.plan, ["path", "sha256"], "plan");
  assertCondition(isNonEmptyString(value.plan.path), "plan.path must be non-empty");
  assertHash(value.plan.sha256, "plan.sha256");
  assertCondition(isObject(value.claims), "claims must be an object");
  assertOnlyKeys(value.claims, ["scope", "globalNonexistence"], "claims");
  assertCondition(value.claims.scope === "checked-addresses", "claims.scope must be checked-addresses");
  assertCondition(value.claims.globalNonexistence === false, "global nonexistence claims are not allowed");
  assertNetworkDeployer(value.network, value.deployer);

  assertCondition(Array.isArray(value.contractPublications), "contractPublications must be an array");
  assertCondition(value.contractPublications.length > 0, "at least one contract publication is required");
  assertCondition(
    value.contractCalls === undefined || Array.isArray(value.contractCalls),
    "contractCalls must be an array when present",
  );
  assertCondition(Array.isArray(value.interfaces), "interfaces must be an array");
  assertCondition(value.interfaces.length > 0, "at least one contract interface expectation is required");

  const txids = new Set<string>();
  const publicationIds = new Set<string>();
  for (const [index, item] of value.contractPublications.entries()) {
    const path = `contractPublications[${index}]`;
    assertCondition(isObject(item), `${path} must be an object`);
    assertOnlyKeys(item, ["kind", "contractName", "contractId", "expectedSender", "txid", "apiEvidence"], path);
    assertCondition(item.kind === "contract-publish", `${path}.kind must be contract-publish`);
    assertContractName(item.contractName, `${path}.contractName`);
    assertContractId(item.contractId, `${path}.contractId`);
    assertAddress(item.expectedSender, `${path}.expectedSender`);
    assertTxid(item.txid, `${path}.txid`);
    assertCondition(item.expectedSender === value.deployer, `${path}.expectedSender must match deployer`, "IDENTITY_MISMATCH");
    assertCondition(
      item.contractId === `${value.deployer}.${item.contractName}`,
      `${path}.contractId must match deployer and contractName`,
      "IDENTITY_MISMATCH",
    );
    assertCondition(!txids.has(item.txid), `${path}.txid is duplicated`, "DUPLICATE_TXID");
    assertCondition(!publicationIds.has(item.contractId), `${path}.contractId is duplicated`, "DUPLICATE_CONTRACT");
    txids.add(item.txid);
    publicationIds.add(item.contractId);
    if (item.apiEvidence !== undefined) assertRecordedTransactionEvidence(item.apiEvidence, `${path}.apiEvidence`);
  }

  const contractCalls = (value.contractCalls ?? []) as ContractCallEvidence[];
  for (const [index, item] of contractCalls.entries()) {
    const path = `contractCalls[${index}]`;
    assertCondition(isObject(item), `${path} must be an object`);
    assertOnlyKeys(item, ["kind", "contractId", "functionName", "expectedSender", "txid", "apiEvidence"], path);
    assertCondition(item.kind === "contract-call", `${path}.kind must be contract-call`);
    assertContractId(item.contractId, `${path}.contractId`);
    assertCondition(isNonEmptyString(item.functionName), `${path}.functionName must be non-empty`);
    assertAddress(item.expectedSender, `${path}.expectedSender`);
    assertTxid(item.txid, `${path}.txid`);
    assertCondition(item.expectedSender === value.deployer, `${path}.expectedSender must match deployer`, "IDENTITY_MISMATCH");
    assertCondition(!txids.has(item.txid), `${path}.txid is duplicated`, "DUPLICATE_TXID");
    txids.add(item.txid);
    if (item.apiEvidence !== undefined) assertRecordedTransactionEvidence(item.apiEvidence, `${path}.apiEvidence`);
  }

  const interfaceIds = new Set<string>();
  for (const [index, item] of value.interfaces.entries()) {
    const path = `interfaces[${index}]`;
    assertCondition(isObject(item), `${path} must be an object`);
    assertOnlyKeys(item, ["contractId", "requiredFunctions", "interfaceEvidence"], path);
    assertContractId(item.contractId, `${path}.contractId`);
    assertCondition(Array.isArray(item.requiredFunctions), `${path}.requiredFunctions must be an array`);
    assertInterfaceFunctions(item.requiredFunctions, `${path}.requiredFunctions`);
    assertCondition(!interfaceIds.has(item.contractId), `${path}.contractId is duplicated`, "DUPLICATE_INTERFACE");
    interfaceIds.add(item.contractId);
    if (item.interfaceEvidence !== undefined) {
      assertRecordedInterfaceEvidence(item.interfaceEvidence, `${path}.interfaceEvidence`);
    }
  }

  for (const contractId of publicationIds) {
    assertCondition(interfaceIds.has(contractId), `missing interface expectation for ${contractId}`, "MISSING_INTERFACE_EXPECTATION");
  }

  if (value.preexistingContracts !== undefined) {
    assertCondition(Array.isArray(value.preexistingContracts), "preexistingContracts must be an array");
    for (const [index, contractId] of value.preexistingContracts.entries()) {
      assertContractId(contractId, `preexistingContracts[${index}]`);
    }
  }

  if (value.evidenceStatus === "confirmed") {
    assertCondition(isNonEmptyString(value.verifiedAt), "confirmed evidence requires verifiedAt");
    for (const [index, item] of value.contractPublications.entries()) {
      assertCondition(item.apiEvidence !== undefined, `confirmed evidence is missing contractPublications[${index}].apiEvidence`);
    }
    for (const [index, item] of contractCalls.entries()) {
      assertCondition(item.apiEvidence !== undefined, `confirmed evidence is missing contractCalls[${index}].apiEvidence`);
    }
    for (const [index, item] of value.interfaces.entries()) {
      assertCondition(item.interfaceEvidence !== undefined, `confirmed evidence is missing interfaces[${index}].interfaceEvidence`);
    }
  }

  return value as unknown as DeploymentEvidence;
}

function normaliseBaseUrl(baseUrl: string): string {
  let parsed: URL;
  try {
    parsed = new URL(baseUrl);
  } catch {
    throw new DeploymentVerificationError("API base URL is invalid", "INVALID_API_BASE_URL");
  }
  assertCondition(parsed.protocol === "http:" || parsed.protocol === "https:", "API base URL must use HTTP or HTTPS", "INVALID_API_BASE_URL");
  assertCondition(parsed.username === "" && parsed.password === "", "API base URL must not contain credentials", "INVALID_API_BASE_URL");
  assertCondition(parsed.search === "" && parsed.hash === "", "API base URL must not contain query or fragment", "INVALID_API_BASE_URL");
  return parsed.toString().replace(/\/$/, "");
}

function endpointUrl(baseUrl: string, path: string): string {
  return `${baseUrl}${path}`;
}

async function fetchJson(
  fetcher: typeof fetch,
  url: string,
  apiKey: string | undefined,
): Promise<HttpJsonResponse> {
  let response: Response;
  try {
    response = await fetcher(url, {
      headers: {
        accept: "application/json",
        ...(apiKey ? { "x-hiro-api-key": apiKey } : {}),
      },
    });
  } catch {
    throw new DeploymentVerificationError(`request failed for ${url}`, "HTTP_REQUEST_FAILED", true);
  }

  let body: unknown = undefined;
  try {
    body = await response.json();
  } catch {
    if (response.status >= 200 && response.status < 300) {
      throw new DeploymentVerificationError(`API returned malformed JSON for ${url}`, "UNSUPPORTED_API_PAYLOAD");
    }
  }

  return { status: response.status, body };
}

function readPlanMetadata(planPath: string): { network?: string; deployer?: string } {
  let contents: string;
  try {
    contents = readFileSync(planPath, "utf8");
  } catch {
    throw new DeploymentVerificationError(`deployment plan is not readable: ${planPath}`, "PLAN_UNREADABLE");
  }
  const network = /^network:\s*([^\s#]+)\s*$/m.exec(contents)?.[1];
  const deployer = /^deployer:\s*([^\s#]+)\s*$/m.exec(contents)?.[1];
  return { network, deployer };
}

export function sha256File(path: string): string {
  try {
    return createHash("sha256").update(readFileSync(path)).digest("hex");
  } catch {
    throw new DeploymentVerificationError(`cannot hash deployment plan: ${path}`, "PLAN_UNREADABLE");
  }
}

function validatePlanAndSource(bundle: DeploymentEvidence, options: VerifyEvidenceOptions): void {
  assertCondition(bundle.network === options.network, "evidence network does not match requested network", "NETWORK_MISMATCH");
  assertCondition(bundle.deployer === options.deployer, "evidence deployer does not match requested deployer", "IDENTITY_MISMATCH");
  assertNetworkDeployer(options.network, options.deployer);
  if (options.sourceCommit !== undefined) {
    assertCommit(options.sourceCommit, "requested sourceCommit");
    assertCondition(bundle.sourceCommit === options.sourceCommit, "evidence source commit does not match requested source commit", "SOURCE_COMMIT_MISMATCH");
  }

  if (options.planPath !== undefined) {
    assertCondition(existsSync(options.planPath), `deployment plan does not exist: ${options.planPath}`, "PLAN_UNREADABLE");
    const expectedHash = sha256File(options.planPath);
    assertCondition(bundle.plan.sha256 === expectedHash, "evidence plan hash does not match deployment plan", "PLAN_HASH_MISMATCH");
    const metadata = readPlanMetadata(options.planPath);
    if (metadata.network !== undefined) {
      assertCondition(metadata.network === options.network, "deployment plan network does not match requested network", "NETWORK_MISMATCH");
    }
    if (metadata.deployer !== undefined) {
      assertCondition(metadata.deployer === options.deployer, "deployment plan deployer does not match requested deployer", "IDENTITY_MISMATCH");
    }
  }
}

function readTransactionContractId(payload: JsonObject, kind: DeploymentTransactionKind): string {
  if (kind === "contract-publish") {
    const smartContract = payload.smart_contract;
    assertCondition(isObject(smartContract), "transaction response is missing smart_contract payload", "UNSUPPORTED_API_PAYLOAD");
    assertContractId(smartContract.contract_id, "transaction smart_contract.contract_id");
    return smartContract.contract_id;
  }

  const contractCall = payload.contract_call;
  assertCondition(isObject(contractCall), "transaction response is missing contract_call payload", "UNSUPPORTED_API_PAYLOAD");
  assertContractId(contractCall.contract_id, "transaction contract_call.contract_id");
  assertCondition(isNonEmptyString(contractCall.function_name), "transaction response is missing contract_call.function_name", "UNSUPPORTED_API_PAYLOAD");
  return contractCall.contract_id;
}

function readTransactionFunctionName(payload: JsonObject, kind: DeploymentTransactionKind): string | null {
  if (kind === "contract-publish") return null;
  const contractCall = payload.contract_call;
  assertCondition(isObject(contractCall) && isNonEmptyString(contractCall.function_name), "transaction response is missing contract_call.function_name", "UNSUPPORTED_API_PAYLOAD");
  return contractCall.function_name;
}

async function verifyTransaction(
  item: ContractPublicationEvidence | ContractCallEvidence,
  options: VerifyEvidenceOptions,
  baseUrl: string,
  fetcher: typeof fetch,
  observedAt: string,
): Promise<TransactionApiEvidence> {
  const endpoint = endpointUrl(baseUrl, `/extended/v1/tx/${encodeURIComponent(item.txid)}`);
  const response = await fetchJson(fetcher, endpoint, options.apiKey);
  if (response.status === 404) {
    throw new DeploymentVerificationError(`transaction ${item.txid} was not found at the checked API address`, "TRANSACTION_NOT_FOUND", true);
  }
  if (response.status < 200 || response.status >= 300) {
    throw new DeploymentVerificationError(`transaction lookup returned HTTP ${response.status}`, "TRANSACTION_HTTP_ERROR", response.status >= 500 || response.status === 429);
  }
  assertCondition(isObject(response.body), "transaction API payload must be an object", "UNSUPPORTED_API_PAYLOAD");
  const payload = response.body;
  assertTxid(payload.tx_id, "transaction.tx_id");
  assertCondition(payload.tx_id.toLowerCase() === item.txid.toLowerCase(), "transaction ID does not match requested txid", "IDENTITY_MISMATCH");
  assertCondition(isNonEmptyString(payload.sender_address), "transaction API payload is missing sender_address", "UNSUPPORTED_API_PAYLOAD");
  assertCondition(payload.sender_address === item.expectedSender, "transaction sender does not match expected sender", "IDENTITY_MISMATCH");
  assertCondition(payload.tx_status === "success", `transaction ${item.txid} is not confirmed: ${String(payload.tx_status ?? "missing status")}`, "TRANSACTION_NOT_CONFIRMED", true);
  assertCondition(payload.canonical === true, `transaction ${item.txid} is not canonical`, "TRANSACTION_NOT_CANONICAL", true);
  assertCondition(payload.is_unanchored === false, `transaction ${item.txid} is unanchored`, "TRANSACTION_UNANCHORED", true);

  const expectedType = item.kind === "contract-publish" ? "smart_contract" : "contract_call";
  assertCondition(payload.tx_type === expectedType, `transaction ${item.txid} has unexpected type`, "TRANSACTION_TYPE_MISMATCH");
  const actualContractId = readTransactionContractId(payload, item.kind);
  assertCondition(actualContractId === item.contractId, "transaction contract identity does not match expected contract", "IDENTITY_MISMATCH");
  const actualFunctionName = readTransactionFunctionName(payload, item.kind);
  if (item.kind === "contract-call") {
    assertCondition(actualFunctionName === item.functionName, "transaction function does not match expected function", "FUNCTION_MISMATCH");
  }

  const blockHash = payload.block_hash;
  const blockHeight = payload.block_height;
  const burnBlockHash = payload.burn_block_hash;
  const burnBlockHeight = payload.burn_block_height;
  assertCondition(isNonEmptyString(blockHash), "transaction API payload is missing block_hash", "UNSUPPORTED_API_PAYLOAD");
  assertCondition(Number.isInteger(blockHeight) && (blockHeight as number) > 0, "transaction API payload has invalid block_height", "UNSUPPORTED_API_PAYLOAD");
  assertCondition(isNonEmptyString(burnBlockHash), "transaction API payload is missing burn_block_hash", "UNSUPPORTED_API_PAYLOAD");
  assertCondition(Number.isInteger(burnBlockHeight) && (burnBlockHeight as number) > 0, "transaction API payload has invalid burn_block_height", "UNSUPPORTED_API_PAYLOAD");
  const confirmedBlockHeight = blockHeight as number;
  const confirmedBurnBlockHeight = burnBlockHeight as number;

  const evidence: TransactionApiEvidence = {
    observedAt,
    endpoint,
    txId: payload.tx_id,
    txStatus: "success",
    canonical: true,
    isUnanchored: false,
    txType: expectedType,
    senderAddress: payload.sender_address,
    contractId: actualContractId,
    functionName: actualFunctionName,
    blockHash,
    blockHeight: confirmedBlockHeight,
    burnBlockHash,
    burnBlockHeight: confirmedBurnBlockHeight,
  };
  if (payload.block_time_iso !== undefined) {
    assertIsoTimestamp(payload.block_time_iso, "transaction.block_time_iso", "UNSUPPORTED_API_PAYLOAD");
    evidence.blockTimeIso = payload.block_time_iso;
  }
  if (payload.burn_block_time_iso !== undefined) {
    assertIsoTimestamp(payload.burn_block_time_iso, "transaction.burn_block_time_iso", "UNSUPPORTED_API_PAYLOAD");
    evidence.burnBlockTimeIso = payload.burn_block_time_iso;
  }
  return evidence;
}

async function verifyInterface(
  item: InterfaceExpectation,
  options: VerifyEvidenceOptions,
  baseUrl: string,
  fetcher: typeof fetch,
  observedAt: string,
): Promise<InterfaceApiEvidence> {
  const separator = item.contractId.lastIndexOf(".");
  const address = item.contractId.slice(0, separator);
  const contractName = item.contractId.slice(separator + 1);
  const endpoint = endpointUrl(
    baseUrl,
    `/v2/contracts/interface/${encodeURIComponent(address)}/${encodeURIComponent(contractName)}`,
  );
  const response = await fetchJson(fetcher, endpoint, options.apiKey);
  if (response.status === 404) {
    throw new DeploymentVerificationError(`interface ${item.contractId} was not found at the checked API address`, "INTERFACE_NOT_FOUND", true);
  }
  if (response.status !== 200) {
    throw new DeploymentVerificationError(`interface lookup returned HTTP ${response.status}`, "INTERFACE_HTTP_ERROR", response.status >= 500 || response.status === 429);
  }
  assertCondition(isObject(response.body), "interface API payload must be an object", "UNSUPPORTED_API_PAYLOAD");
  assertInterfaceFunctions(response.body.functions, "interface.functions", "UNSUPPORTED_API_PAYLOAD");
  const functions = (response.body.functions as RequiredFunction[]).map(({ name, access }) => ({ name, access }));
  for (const required of item.requiredFunctions) {
    assertCondition(
      functions.some((candidate) => candidate.name === required.name && candidate.access === required.access),
      `interface ${item.contractId} is missing ${required.access} function ${required.name}`,
      "INTERFACE_FUNCTION_MISSING",
    );
  }
  return {
    observedAt,
    endpoint,
    httpStatus: 200,
    functions,
  };
}

export async function verifyDeploymentEvidence(
  input: unknown,
  options: VerifyEvidenceOptions,
): Promise<DeploymentEvidence> {
  const bundle = parseEvidenceBundle(input);
  validatePlanAndSource(bundle, options);
  const baseUrl = normaliseBaseUrl(options.baseUrl ?? HIRO_API_BASE_URLS[options.network]);
  const fetcher = options.fetcher ?? fetch;
  const now = options.now ?? (() => new Date());
  const verifiedAt = now().toISOString();

  const contractPublications: ContractPublicationEvidence[] = [];
  for (const item of bundle.contractPublications) {
    const observedAt = now().toISOString();
    contractPublications.push({
      ...item,
      apiEvidence: await verifyTransaction(item, options, baseUrl, fetcher, observedAt),
    });
  }

  const contractCalls: ContractCallEvidence[] = [];
  for (const item of bundle.contractCalls) {
    const observedAt = now().toISOString();
    contractCalls.push({
      ...item,
      apiEvidence: await verifyTransaction(item, options, baseUrl, fetcher, observedAt),
    });
  }

  const interfaces: InterfaceExpectation[] = [];
  for (const item of bundle.interfaces) {
    const observedAt = now().toISOString();
    interfaces.push({
      ...item,
      interfaceEvidence: await verifyInterface(item, options, baseUrl, fetcher, observedAt),
    });
  }

  return {
    ...bundle,
    evidenceStatus: "confirmed",
    verifiedAt,
    contractPublications,
    contractCalls,
    interfaces,
  };
}

export async function waitForDeploymentEvidence(
  input: unknown,
  options: WaitForEvidenceOptions,
): Promise<DeploymentEvidence> {
  const timeoutMs = options.timeoutMs ?? 10 * 60 * 1000;
  const pollIntervalMs = options.pollIntervalMs ?? 15 * 1000;
  assertCondition(Number.isInteger(timeoutMs) && timeoutMs >= 0, "timeoutMs must be a non-negative integer");
  assertCondition(Number.isInteger(pollIntervalMs) && pollIntervalMs > 0, "pollIntervalMs must be a positive integer");
  const sleep = options.sleep ?? ((milliseconds: number) => new Promise<void>((resolvePromise) => setTimeout(resolvePromise, milliseconds)));
  const deadline = Date.now() + timeoutMs;
  let lastError: unknown;

  while (Date.now() <= deadline) {
    try {
      return await verifyDeploymentEvidence(input, options);
    } catch (error) {
      lastError = error;
      if (!(error instanceof DeploymentVerificationError) || !error.retryable) throw error;
      if (Date.now() >= deadline) break;
      await sleep(Math.min(pollIntervalMs, Math.max(1, deadline - Date.now())));
    }
  }

  if (lastError instanceof DeploymentVerificationError) {
    throw new DeploymentVerificationError(
      `${lastError.message}; confirmation timeout exceeded`,
      "CONFIRMATION_TIMEOUT",
      false,
    );
  }
  throw new DeploymentVerificationError("deployment confirmation timeout exceeded", "CONFIRMATION_TIMEOUT");
}

function parseCliArgs(argv: string[]): Record<string, string> {
  const args: Record<string, string> = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith("--")) throw new DeploymentVerificationError(`unexpected argument ${token}`, "CLI_ARGUMENT_ERROR");
    const key = token.slice(2);
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) throw new DeploymentVerificationError(`missing value for --${key}`, "CLI_ARGUMENT_ERROR");
    args[key] = value;
    index += 1;
  }
  return args;
}

async function runCli(): Promise<void> {
  try {
    if (process.argv.includes("--help") || process.argv.includes("-h")) {
      process.stdout.write(
        "Usage: tsx scripts/deployment/verify-evidence.ts --evidence FILE --network testnet|mainnet --deployer ADDRESS [--plan FILE] [--source-commit SHA] [--api-base-url URL] [--output FILE]\n",
      );
      return;
    }
    const args = parseCliArgs(process.argv.slice(2));
    const evidencePath = args.evidence;
    const network = args.network as DeploymentNetwork | undefined;
    const deployer = args.deployer;
    assertCondition(isNonEmptyString(evidencePath), "--evidence is required", "CLI_ARGUMENT_ERROR");
    assertCondition(network === "testnet" || network === "mainnet", "--network must be testnet or mainnet", "CLI_ARGUMENT_ERROR");
    assertCondition(isNonEmptyString(deployer), "--deployer is required", "CLI_ARGUMENT_ERROR");

    let input: unknown;
    try {
      input = JSON.parse(readFileSync(resolve(evidencePath), "utf8"));
    } catch {
      throw new DeploymentVerificationError(`cannot read or parse evidence bundle: ${evidencePath}`, "MALFORMED_EVIDENCE");
    }

    const verified = await verifyDeploymentEvidence(input, {
      network,
      deployer,
      baseUrl: args["api-base-url"],
      apiKey: process.env.HIRO_API_KEY,
      planPath: args.plan,
      sourceCommit: args["source-commit"],
    });
    const output = JSON.stringify(verified, null, 2) + "\n";
    if (args.output) {
      writeFileSync(resolve(args.output), output, { encoding: "utf8", mode: 0o600 });
    } else {
      process.stdout.write(output);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "deployment evidence verification failed";
    process.stderr.write(`deployment evidence verification failed: ${message}\n`);
    process.exitCode = 1;
  }
}

const isDirectRun = process.argv[1] !== undefined && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isDirectRun) {
  void runCli();
}
