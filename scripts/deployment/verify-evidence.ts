import { createHash } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { parseDocument } from "yaml";
import {
  AddressVersion,
  contractPrincipalCV,
  createStandardPrincipal,
  cvToHex,
  hexToCV,
  internal_parseCommaSeparated,
  isClarityName,
  standardPrincipalCV,
  validateStacksAddress,
  type ClarityValue,
} from "@stacks/transactions";

export type DeploymentNetwork = "testnet" | "mainnet";
export type EvidenceStatus = "plan" | "workflow" | "broadcast" | "confirmed";
export type EvidenceCoverage = "partial" | "complete";
export type DeploymentTransactionKind = "contract-publish" | "contract-call";
export type InterfaceAccess = "public" | "read_only";

export interface PlanPosition {
  batchId: number;
  transactionIndex: number;
}

export interface RequiredFunction {
  name: string;
  access: InterfaceAccess;
}

export interface CanonicalFunctionArgument {
  name: string;
  type: string;
  hex: string;
  repr: string;
}

export interface ContractPublicationEvidence {
  kind: "contract-publish";
  planPosition: PlanPosition;
  contractName: string;
  contractId: string;
  expectedSender: string;
  txid: string;
  apiEvidence?: TransactionApiEvidence;
}

export interface ContractCallEvidence {
  kind: "contract-call";
  planPosition: PlanPosition;
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
  burnBlockHash?: string;
  burnBlockHeight: number;
  functionArgs?: CanonicalFunctionArgument[];
  blockTimeIso?: string;
  burnBlockTimeIso?: string;
}

export interface InterfaceApiEvidence {
  observedAt: string;
  endpoint: string;
  httpStatus: 200;
  functions: RequiredFunction[];
}

export interface ReadOnlyCheck {
  network: DeploymentNetwork;
  contractId: string;
  sender: string;
  functionName: string;
  arguments: string[];
  expectedOkay: true;
  expectedResultHex: string;
  apiEvidence?: ReadOnlyApiEvidence;
}

export interface ReadOnlyApiEvidence {
  observedAt: string;
  endpoint: string;
  httpStatus: 200;
  sender: string;
  arguments: string[];
  okay: true;
  resultHex: string;
}

export interface DeploymentEvidence {
  schemaVersion: "1";
  evidenceStatus: EvidenceStatus;
  coverage?: EvidenceCoverage;
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
  readOnlyChecks?: ReadOnlyCheck[];
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
  requestTimeoutMs?: number;
}

export interface WaitForEvidenceOptions extends VerifyEvidenceOptions {
  timeoutMs?: number;
  pollIntervalMs?: number;
  sleep?: (milliseconds: number) => Promise<void>;
}

export interface EffectivePlanContractPublish {
  kind: "contract-publish";
  planPosition: PlanPosition;
  contractName: string;
  contractId: string;
  expectedSender: string;
}

export interface EffectivePlanContractCall {
  kind: "contract-call";
  planPosition: PlanPosition;
  contractId: string;
  functionName: string;
  expectedSender: string;
  parameters: string[];
}

export type EffectivePlanEntry = EffectivePlanContractPublish | EffectivePlanContractCall;

export interface ParsedDeploymentPlan {
  network: DeploymentNetwork;
  deployer: string;
  entries: EffectivePlanEntry[];
}

export class DeploymentVerificationError extends Error {
  readonly code: string;
  readonly retryable: boolean;
  readonly status?: string;

  constructor(message: string, code: string, retryable = false, status?: string) {
    super(message);
    this.name = "DeploymentVerificationError";
    this.code = code;
    this.retryable = retryable;
    this.status = status;
  }
}

export const HIRO_API_BASE_URLS: Readonly<Record<DeploymentNetwork, string>> = {
  testnet: "https://api.testnet.hiro.so",
  mainnet: "https://api.mainnet.hiro.so",
};

const TXID_PATTERN = /^0x[0-9a-fA-F]{64}$/;
const HASH_PATTERN = /^[0-9a-f]{64}$/;
const CLARITY_HEX_PATTERN = /^0x?[0-9a-fA-F]+$/;
const COMMIT_PATTERN = /^[0-9a-f]{40}$/;
const CONTRACT_NAME_PATTERN = /^[a-zA-Z][a-zA-Z0-9-]{0,39}$/;
const ISO_TIMESTAMP_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/;

const NETWORK_ADDRESS_VERSIONS: Readonly<Record<DeploymentNetwork, ReadonlySet<number>>> = {
  mainnet: new Set([AddressVersion.MainnetSingleSig, AddressVersion.MainnetMultiSig]),
  testnet: new Set([AddressVersion.TestnetSingleSig, AddressVersion.TestnetMultiSig]),
};

const KNOWN_HIRO_HOSTS = new Set(Object.values(HIRO_API_BASE_URLS).map((baseUrl) => new URL(baseUrl).hostname));
const DEFAULT_REQUEST_TIMEOUT_MS = 30_000;

type JsonObject = Record<string, unknown>;

interface HttpJsonResponse {
  status: number;
  body: unknown;
}

interface FetchJsonOptions {
  method?: "GET" | "POST";
  body?: unknown;
  requestTimeoutMs?: number;
  requestFailureCode?: string;
  requestTimeoutCode?: string;
  malformedCode?: string;
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

function assertOnlyKeys(
  value: JsonObject,
  allowed: readonly string[],
  path: string,
  code = "MALFORMED_EVIDENCE",
): void {
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

function stacksAddressVersion(value: string, path: string): number {
  assertCondition(validateStacksAddress(value), `${path} must be a valid Stacks standard address`);
  try {
    return createStandardPrincipal(value).address.version;
  } catch {
    throw new DeploymentVerificationError(`${path} must be a valid Stacks standard address`, "MALFORMED_EVIDENCE");
  }
}

function assertAddress(value: unknown, path: string, network?: DeploymentNetwork): asserts value is string {
  assertCondition(typeof value === "string", `${path} must be a valid Stacks standard address`);
  const version = stacksAddressVersion(value, path);
  if (network !== undefined) {
    assertCondition(
      NETWORK_ADDRESS_VERSIONS[network].has(version),
      `${path} does not match the ${network} Stacks address network`,
      "NETWORK_DEPLOYER_MISMATCH",
    );
  }
}

function assertContractName(value: unknown, path: string, code = "MALFORMED_EVIDENCE"): asserts value is string {
  assertCondition(
    typeof value === "string" && CONTRACT_NAME_PATTERN.test(value),
    `${path} must be a valid Clarity contract name`,
    code,
  );
}

function assertFunctionName(value: unknown, path: string, code = "MALFORMED_EVIDENCE"): asserts value is string {
  assertCondition(
    typeof value === "string" && isClarityName(value),
    `${path} must be a valid Clarity function name`,
    code,
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

function assertContractId(value: unknown, path: string, network?: DeploymentNetwork): asserts value is string {
  assertCondition(typeof value === "string" && value.includes("."), `${path} must be an address.contract-name identifier`);
  const separator = value.lastIndexOf(".");
  assertAddress(value.slice(0, separator), `${path} address`, network);
  assertContractName(value.slice(separator + 1), `${path} contract name`);
}

function assertNetworkDeployer(network: DeploymentNetwork, deployer: string): void {
  assertAddress(deployer, "deployer", network);
}

function assertPlanPosition(value: unknown, path: string): asserts value is PlanPosition {
  assertCondition(isObject(value), `${path} must be an object`);
  assertOnlyKeys(value, ["batchId", "transactionIndex"], path);
  assertCondition(Number.isInteger(value.batchId) && (value.batchId as number) >= 0, `${path}.batchId is invalid`);
  assertCondition(
    Number.isInteger(value.transactionIndex) && (value.transactionIndex as number) >= 0,
    `${path}.transactionIndex is invalid`,
  );
}

function assertRecordedFunctionArguments(value: unknown, path: string): asserts value is CanonicalFunctionArgument[] {
  assertCondition(Array.isArray(value), `${path} must be an array`);
  for (const [index, item] of value.entries()) {
    const itemPath = `${path}[${index}]`;
    assertCondition(isObject(item), `${itemPath} must be an object`);
    assertOnlyKeys(item, ["name", "type", "hex", "repr"], itemPath);
    assertFunctionName(item.name, `${itemPath}.name`);
    assertCondition(isNonEmptyString(item.type), `${itemPath}.type must be non-empty`);
    assertCanonicalClarityHex(item.hex, `${itemPath}.hex`);
    assertCondition(isNonEmptyString(item.repr), `${itemPath}.repr must be non-empty`);
    const reprHex = clarityHexFromRepr(item.repr, `${itemPath}.repr`);
    assertCondition(
      reprHex === normaliseClarityHex(item.hex as string),
      `${itemPath}.hex and ${itemPath}.repr do not describe the same Clarity value`,
      "ARGUMENT_MISMATCH",
    );
  }
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
      "functionArgs",
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
  if (value.functionName !== null) assertFunctionName(value.functionName, `${path}.functionName`);
  assertCondition(isNonEmptyString(value.blockHash), `${path}.blockHash must be non-empty`);
  assertCondition(Number.isInteger(value.blockHeight) && (value.blockHeight as number) > 0, `${path}.blockHeight is invalid`);
  if (value.burnBlockHash !== undefined) {
    assertCondition(isNonEmptyString(value.burnBlockHash), `${path}.burnBlockHash must be non-empty`);
  }
  assertCondition(
    Number.isInteger(value.burnBlockHeight) && (value.burnBlockHeight as number) > 0,
    `${path}.burnBlockHeight is invalid`,
  );
  if (value.functionArgs !== undefined) assertRecordedFunctionArguments(value.functionArgs, `${path}.functionArgs`);
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

function assertCanonicalSerializedClarityValues(value: unknown, path: string): asserts value is string[] {
  assertCondition(Array.isArray(value), `${path} must be an array`);
  for (const [index, item] of value.entries()) {
    const itemPath = `${path}[${index}]`;
    assertCanonicalClarityHex(item, itemPath);
    assertCondition(item.startsWith("0x"), `${itemPath} must use a 0x-prefixed canonical Clarity value`);
    assertCondition(
      cvToHex(hexToCV(item)).toLowerCase() === item.toLowerCase(),
      `${itemPath} must use canonical Clarity serialization`,
      "MALFORMED_EVIDENCE",
    );
  }
}

function assertReadOnlyApiEvidence(value: unknown, path: string, network: DeploymentNetwork): void {
  assertCondition(isObject(value), `${path} must be an object`);
  assertOnlyKeys(value, ["observedAt", "endpoint", "httpStatus", "sender", "arguments", "okay", "resultHex"], path);
  assertIsoTimestamp(value.observedAt, `${path}.observedAt`);
  assertCondition(isNonEmptyString(value.endpoint), `${path}.endpoint must be non-empty`);
  assertCondition(value.httpStatus === 200, `${path}.httpStatus must be 200`);
  assertAddress(value.sender, `${path}.sender`, network);
  assertCanonicalSerializedClarityValues(value.arguments, `${path}.arguments`);
  assertCondition(value.okay === true, `${path}.okay must be true`);
  assertCanonicalClarityHex(value.resultHex, `${path}.resultHex`);
  assertCondition(value.resultHex.startsWith("0x"), `${path}.resultHex must use a 0x-prefixed canonical Clarity value`);
  assertCondition(
    cvToHex(hexToCV(value.resultHex)).toLowerCase() === value.resultHex.toLowerCase(),
    `${path}.resultHex must use canonical Clarity serialization`,
    "MALFORMED_EVIDENCE",
  );
}

function assertReadOnlyCheck(value: unknown, path: string, network: DeploymentNetwork): void {
  assertCondition(isObject(value), `${path} must be an object`);
  assertOnlyKeys(
    value,
    ["network", "contractId", "sender", "functionName", "arguments", "expectedOkay", "expectedResultHex", "apiEvidence"],
    path,
  );
  assertCondition(value.network === network, `${path}.network must match the evidence network`, "READ_ONLY_NETWORK_MISMATCH");
  assertContractId(value.contractId, `${path}.contractId`, network);
  assertAddress(value.sender, `${path}.sender`, network);
  assertFunctionName(value.functionName, `${path}.functionName`);
  assertCanonicalSerializedClarityValues(value.arguments, `${path}.arguments`);
  assertCondition(value.expectedOkay === true, `${path}.expectedOkay must be true`, "READ_ONLY_EXPECTATION_INVALID");
  assertCanonicalClarityHex(value.expectedResultHex, `${path}.expectedResultHex`);
  assertCondition(
    value.expectedResultHex.startsWith("0x"),
    `${path}.expectedResultHex must use a 0x-prefixed canonical Clarity value`,
  );
  assertCondition(
    cvToHex(hexToCV(value.expectedResultHex)).toLowerCase() === value.expectedResultHex.toLowerCase(),
    `${path}.expectedResultHex must use canonical Clarity serialization`,
    "READ_ONLY_EXPECTATION_INVALID",
  );
  if (value.apiEvidence !== undefined) assertReadOnlyApiEvidence(value.apiEvidence, `${path}.apiEvidence`, network);
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
    assertFunctionName(item.name, `${path}[${index}].name`, code);
    assertCondition(
      item.access === "public" || item.access === "read_only",
      `${path}[${index}].access is unsupported`,
      code,
    );
    assertCondition(!names.has(item.name), `${path} contains duplicate function ${item.name}`, code);
    names.add(item.name);
  }
}

function assertHiroFunctionArguments(value: unknown, path: string, code: string): void {
  assertCondition(Array.isArray(value), `${path} must be an array`, code);
  for (const [index, item] of value.entries()) {
    assertCondition(isObject(item), `${path}[${index}] must be an object`, code);
    assertFunctionName(item.name, `${path}[${index}].name`, code);
    assertCondition(isNonEmptyString(item.type), `${path}[${index}].type must be non-empty`, code);
  }
}

function assertHiroOutputs(value: unknown, path: string, code: string): void {
  if (isNonEmptyString(value)) return;
  if (Array.isArray(value)) {
    for (const [index, item] of value.entries()) {
      if (isNonEmptyString(item)) continue;
      assertCondition(isObject(item) && isNonEmptyString(item.type), `${path}[${index}] is invalid`, code);
    }
    return;
  }
  assertCondition(isObject(value) && isNonEmptyString(value.type), `${path} must contain a type`, code);
}

function readHiroInterfaceFunctions(value: unknown, path: string): RequiredFunction[] {
  const code = "UNSUPPORTED_API_PAYLOAD";
  assertCondition(Array.isArray(value), `${path} must be an array`, code);
  const functions: RequiredFunction[] = [];
  const names = new Set<string>();
  for (const [index, item] of value.entries()) {
    const itemPath = `${path}[${index}]`;
    assertCondition(isObject(item), `${itemPath} must be an object`, code);
    assertFunctionName(item.name, `${itemPath}.name`, code);
    assertCondition(
      item.access === "private" || item.access === "public" || item.access === "read_only",
      `${itemPath}.access is unsupported`,
      code,
    );
    if (item.args !== undefined) assertHiroFunctionArguments(item.args, `${itemPath}.args`, code);
    if (item.outputs !== undefined) assertHiroOutputs(item.outputs, `${itemPath}.outputs`, code);

    // Private functions are documented by Hiro but cannot be requested as
    // public evidence. Validate them above, then omit them from the
    // sanitized evidence representation.
    if (item.access === "private") continue;
    assertCondition(!names.has(item.name), `${path} contains duplicate function ${item.name}`, code);
    names.add(item.name);
    functions.push({ name: item.name, access: item.access });
  }
  return functions;
}

function parseEvidenceBundle(value: unknown): DeploymentEvidence {
  assertCondition(isObject(value), "evidence bundle must be a JSON object");
  assertOnlyKeys(
    value,
    [
      "schemaVersion",
      "evidenceStatus",
      "coverage",
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
      "readOnlyChecks",
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
  if (value.coverage !== undefined) {
    assertCondition(value.coverage === "partial" || value.coverage === "complete", "evidence coverage is unsupported");
  }
  assertIsoTimestamp(value.generatedAt, "generatedAt");
  if (value.verifiedAt !== undefined) assertIsoTimestamp(value.verifiedAt, "verifiedAt");
  assertCommit(value.sourceCommit, "sourceCommit");
  assertCondition(value.network === "testnet" || value.network === "mainnet", "network must be testnet or mainnet");
  assertAddress(value.deployer, "deployer", value.network);
  assertCondition(isObject(value.plan), "plan must be an object");
  assertOnlyKeys(value.plan, ["path", "sha256"], "plan");
  assertCondition(isNonEmptyString(value.plan.path), "plan.path must be non-empty");
  assertHash(value.plan.sha256, "plan.sha256");
  assertCondition(isObject(value.claims), "claims must be an object");
  assertOnlyKeys(value.claims, ["scope", "globalNonexistence"], "claims");
  assertCondition(value.claims.scope === "checked-addresses", "claims.scope must be checked-addresses");
  assertCondition(value.claims.globalNonexistence === false, "global nonexistence claims are not allowed");

  assertCondition(Array.isArray(value.contractPublications), "contractPublications must be an array");
  assertCondition(Array.isArray(value.contractCalls), "contractCalls must be an array");
  assertCondition(Array.isArray(value.interfaces), "interfaces must be an array");

  const txids = new Set<string>();
  const publicationIds = new Set<string>();
  for (const [index, item] of value.contractPublications.entries()) {
    const path = `contractPublications[${index}]`;
    assertCondition(isObject(item), `${path} must be an object`);
    assertOnlyKeys(item, ["kind", "planPosition", "contractName", "contractId", "expectedSender", "txid", "apiEvidence"], path);
    assertCondition(item.kind === "contract-publish", `${path}.kind must be contract-publish`);
    assertPlanPosition(item.planPosition, `${path}.planPosition`);
    assertContractName(item.contractName, `${path}.contractName`);
    assertContractId(item.contractId, `${path}.contractId`, value.network);
    assertAddress(item.expectedSender, `${path}.expectedSender`, value.network);
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

  const contractCalls = value.contractCalls as ContractCallEvidence[];
  for (const [index, item] of contractCalls.entries()) {
    const path = `contractCalls[${index}]`;
    assertCondition(isObject(item), `${path} must be an object`);
    assertOnlyKeys(item, ["kind", "planPosition", "contractId", "functionName", "expectedSender", "txid", "apiEvidence"], path);
    assertCondition(item.kind === "contract-call", `${path}.kind must be contract-call`);
    assertPlanPosition(item.planPosition, `${path}.planPosition`);
    assertContractId(item.contractId, `${path}.contractId`, value.network);
    assertFunctionName(item.functionName, `${path}.functionName`);
    assertAddress(item.expectedSender, `${path}.expectedSender`, value.network);
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
    assertContractId(item.contractId, `${path}.contractId`, value.network);
    assertCondition(Array.isArray(item.requiredFunctions), `${path}.requiredFunctions must be an array`);
    assertInterfaceFunctions(item.requiredFunctions, `${path}.requiredFunctions`);
    assertCondition(!interfaceIds.has(item.contractId), `${path}.contractId is duplicated`, "DUPLICATE_INTERFACE");
    interfaceIds.add(item.contractId);
    if (item.interfaceEvidence !== undefined) {
      assertRecordedInterfaceEvidence(item.interfaceEvidence, `${path}.interfaceEvidence`);
    }
  }

  const declaredReadOnlyChecksValue = value.readOnlyChecks;
  let declaredReadOnlyChecks: ReadOnlyCheck[] = [];
  if (declaredReadOnlyChecksValue !== undefined) {
    assertCondition(Array.isArray(declaredReadOnlyChecksValue), "readOnlyChecks must be an array");
    declaredReadOnlyChecks = declaredReadOnlyChecksValue as ReadOnlyCheck[];
    const readOnlyKeys = new Set<string>();
    for (const [index, item] of declaredReadOnlyChecks.entries()) {
      const path = `readOnlyChecks[${index}]`;
      assertReadOnlyCheck(item, path, value.network);
      const check = item as ReadOnlyCheck;
      const key = `${check.network}:${check.contractId}:${check.sender}:${check.functionName}:${check.arguments.join(",")}:${check.expectedResultHex}`;
      assertCondition(!readOnlyKeys.has(key), `${path} duplicates another declared read-only check`, "DUPLICATE_READ_ONLY_CHECK");
      readOnlyKeys.add(key);
    }
  }

  for (const contractId of publicationIds) {
    assertCondition(interfaceIds.has(contractId), `missing interface expectation for ${contractId}`, "MISSING_INTERFACE_EXPECTATION");
  }

  if (value.preexistingContracts !== undefined) {
    assertCondition(Array.isArray(value.preexistingContracts), "preexistingContracts must be an array");
    for (const [index, contractId] of value.preexistingContracts.entries()) {
      assertContractId(contractId, `preexistingContracts[${index}]`, value.network);
    }
  }

  if (value.evidenceStatus === "confirmed") {
    assertCondition(value.coverage === "complete", "confirmed evidence requires complete coverage");
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
    for (const [index, item] of declaredReadOnlyChecks.entries()) {
      assertCondition(item.apiEvidence !== undefined, `confirmed evidence is missing readOnlyChecks[${index}].apiEvidence`);
    }
  }
  if (value.evidenceStatus === "broadcast") {
    assertCondition(value.coverage === "partial", "broadcast evidence must be labeled partial");
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

export function isKnownHiroApiBaseUrl(baseUrl: string): boolean {
  try {
    const parsed = new URL(baseUrl);
    return parsed.protocol === "https:" && KNOWN_HIRO_HOSTS.has(parsed.hostname.toLowerCase());
  } catch {
    return false;
  }
}

function endpointUrl(baseUrl: string, path: string): string {
  return `${baseUrl}${path}`;
}

async function fetchJson(
  fetcher: typeof fetch,
  url: string,
  apiKey: string | undefined,
  baseUrl: string,
  options: FetchJsonOptions = {},
): Promise<HttpJsonResponse> {
  const requestTimeoutMs = options.requestTimeoutMs ?? DEFAULT_REQUEST_TIMEOUT_MS;
  assertCondition(
    Number.isInteger(requestTimeoutMs) && requestTimeoutMs > 0,
    "requestTimeoutMs must be a positive integer",
    "INVALID_REQUEST_TIMEOUT",
  );

  const controller = new AbortController();
  let timedOut = false;
  const timeout = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, requestTimeoutMs);

  try {
    const headers: Record<string, string> = { accept: "application/json" };
    if (apiKey && isKnownHiroApiBaseUrl(baseUrl)) headers["x-hiro-api-key"] = apiKey;
    const requestInit: RequestInit = {
      method: options.method ?? "GET",
      headers,
      signal: controller.signal,
    };
    if (options.body !== undefined) {
      headers["content-type"] = "application/json";
      requestInit.body = JSON.stringify(options.body);
    }
    const response = await fetcher(url, requestInit);
    let body: unknown = undefined;
    try {
      body = await response.json();
    } catch {
      if (timedOut) {
        throw new DeploymentVerificationError(
          `request timed out for ${url}`,
          options.requestTimeoutCode ?? "HTTP_REQUEST_TIMEOUT",
          true,
        );
      }
      if (response.status >= 200 && response.status < 300) {
        throw new DeploymentVerificationError(
          `API returned malformed JSON for ${url}`,
          options.malformedCode ?? "UNSUPPORTED_API_PAYLOAD",
        );
      }
    }

    return { status: response.status, body };
  } catch (error) {
    if (error instanceof DeploymentVerificationError) throw error;
    if (timedOut) {
      throw new DeploymentVerificationError(
        `request timed out for ${url}`,
        options.requestTimeoutCode ?? "HTTP_REQUEST_TIMEOUT",
        true,
      );
    }
    throw new DeploymentVerificationError(
      `request failed for ${url}`,
      options.requestFailureCode ?? "HTTP_REQUEST_FAILED",
      true,
    );
  } finally {
    clearTimeout(timeout);
  }
}

function planError(message: string, code = "PLAN_MALFORMED"): never {
  throw new DeploymentVerificationError(message, code);
}

function readYamlPlan(planPath: string): unknown {
  let contents: string;
  try {
    contents = readFileSync(planPath, "utf8");
  } catch {
    throw new DeploymentVerificationError(`deployment plan is not readable: ${planPath}`, "PLAN_UNREADABLE");
  }
  try {
    const document = parseDocument(contents, { uniqueKeys: true });
    if (document.errors.length > 0) planError("deployment plan YAML is malformed");
    return document.toJS();
  } catch (error) {
    if (error instanceof DeploymentVerificationError) throw error;
    throw new DeploymentVerificationError("deployment plan YAML is malformed", "PLAN_MALFORMED");
  }
}

function readPlanPosition(batchId: unknown, transactionIndex: number, path: string): PlanPosition {
  assertCondition(Number.isInteger(batchId) && (batchId as number) >= 0, `${path}.id is invalid`, "PLAN_MALFORMED");
  return { batchId: batchId as number, transactionIndex };
}

function readPlanString(value: unknown, path: string): string {
  if (!isNonEmptyString(value)) planError(`${path} must be a non-empty string`);
  return value;
}

export function readDeploymentPlan(planPath: string): ParsedDeploymentPlan {
  const root = readYamlPlan(planPath);
  if (!isObject(root)) planError("deployment plan must be a YAML object");
  const network = root.network;
  const deployer = root.deployer;
  assertCondition(network === "testnet" || network === "mainnet", "deployment plan network is invalid", "PLAN_MALFORMED");
  assertCondition(isNonEmptyString(deployer), "deployment plan deployer is missing", "PLAN_MALFORMED");
  assertNetworkDeployer(network, deployer);
  assertCondition(isObject(root.plan) && Array.isArray(root.plan.batches), "deployment plan batches are missing", "PLAN_MALFORMED");

  const entries: EffectivePlanEntry[] = [];
  const batchIds = new Set<number>();
  for (const [batchIndex, batch] of root.plan.batches.entries()) {
    assertCondition(isObject(batch), `plan.batches[${batchIndex}] must be an object`, "PLAN_MALFORMED");
    const batchId = batch.id;
    assertCondition(Number.isInteger(batchId) && (batchId as number) >= 0, `plan.batches[${batchIndex}].id is invalid`, "PLAN_MALFORMED");
    assertCondition(!batchIds.has(batchId as number), `plan batch id ${String(batchId)} is duplicated`, "PLAN_DUPLICATE_POSITION");
    batchIds.add(batchId as number);
    assertCondition(Array.isArray(batch.transactions), `plan.batches[${batchIndex}].transactions is missing`, "PLAN_MALFORMED");

    for (const [transactionIndex, transaction] of batch.transactions.entries()) {
      assertCondition(isObject(transaction), `plan.batches[${batchIndex}].transactions[${transactionIndex}] must be an object`, "PLAN_MALFORMED");
      const position = readPlanPosition(batchId, transactionIndex, `plan.batches[${batchIndex}]`);
      const transactionKeys = Object.keys(transaction);
      assertCondition(
        transactionKeys.length === 1,
        `plan transaction ${position.batchId}:${position.transactionIndex} must contain exactly one transaction kind`,
        "PLAN_MALFORMED",
      );
      const transactionKind = transactionKeys[0];
      assertCondition(
        transactionKind === "contract-publish" || transactionKind === "contract-call",
        `plan transaction ${position.batchId}:${position.transactionIndex} has unsupported transaction kind ${transactionKind}`,
        "PLAN_MALFORMED",
      );

      if (transactionKind === "contract-publish") {
        const body = transaction[transactionKind];
        assertCondition(isObject(body), `plan transaction ${position.batchId}:${position.transactionIndex} publish body is invalid`, "PLAN_MALFORMED");
        const contractName = readPlanString(body["contract-name"], "contract-publish.contract-name");
        assertContractName(contractName, "contract-publish.contract-name", "PLAN_MALFORMED");
        const expectedSender = readPlanString(body["expected-sender"], "contract-publish.expected-sender");
        assertAddress(expectedSender, "contract-publish.expected-sender", network);
        assertCondition(expectedSender === deployer, "deployment plan transaction sender does not match plan deployer", "IDENTITY_MISMATCH");
        entries.push({
          kind: "contract-publish",
          planPosition: position,
          contractName,
          contractId: `${expectedSender}.${contractName}`,
          expectedSender,
        });
      }
      if (transactionKind === "contract-call") {
        const body = transaction[transactionKind];
        assertCondition(isObject(body), `plan transaction ${position.batchId}:${position.transactionIndex} call body is invalid`, "PLAN_MALFORMED");
        const contractId = readPlanString(body["contract-id"], "contract-call.contract-id");
        assertContractId(contractId, "contract-call.contract-id", network);
        const expectedSender = readPlanString(body["expected-sender"], "contract-call.expected-sender");
        assertAddress(expectedSender, "contract-call.expected-sender", network);
        assertCondition(expectedSender === deployer, "deployment plan transaction sender does not match plan deployer", "IDENTITY_MISMATCH");
        const functionName = readPlanString(body.method, "contract-call.method");
        assertFunctionName(functionName, "contract-call.method", "PLAN_MALFORMED");
        assertCondition(Array.isArray(body.parameters), "contract-call.parameters must be an array", "PLAN_ARGUMENTS_UNSUPPORTED");
        const parameters = body.parameters.map((parameter, parameterIndex) => {
          const repr = readPlanString(parameter, `contract-call.parameters[${parameterIndex}]`);
          // Validate the generator's canonical Clarity representation now so
          // a malformed call cannot become a confirmed bundle later.
          clarityHexFromRepr(repr, `contract-call.parameters[${parameterIndex}]`);
          return repr.trim();
        });
        entries.push({
          kind: "contract-call",
          planPosition: position,
          contractId,
          functionName,
          expectedSender,
          parameters,
        });
      }
    }
  }

  assertCondition(entries.length > 0, "deployment plan contains no effective on-chain transactions", "PLAN_MALFORMED");
  return { network, deployer, entries };
}

export function sha256File(path: string): string {
  try {
    return createHash("sha256").update(readFileSync(path)).digest("hex");
  } catch {
    throw new DeploymentVerificationError(`cannot hash deployment plan: ${path}`, "PLAN_UNREADABLE");
  }
}

function positionKey(position: PlanPosition): string {
  return `${position.batchId}:${position.transactionIndex}`;
}

function planEntryKey(entry: EffectivePlanEntry): string {
  return `${positionKey(entry.planPosition)}:${entry.kind}:${entry.contractId}:${entry.kind === "contract-call" ? entry.functionName : entry.contractName}`;
}

function evidenceEntryKey(entry: ContractPublicationEvidence | ContractCallEvidence): string {
  return `${positionKey(entry.planPosition)}:${entry.kind}:${entry.contractId}:${entry.kind === "contract-call" ? entry.functionName : entry.contractName}`;
}

function validateCompletePlanBinding(bundle: DeploymentEvidence, plan: ParsedDeploymentPlan): void {
  assertCondition(bundle.network === plan.network, "evidence network does not match deployment plan", "NETWORK_MISMATCH");
  assertCondition(bundle.deployer === plan.deployer, "evidence deployer does not match deployment plan", "IDENTITY_MISMATCH");
  assertCondition(
    bundle.preexistingContracts === undefined || bundle.preexistingContracts.length === 0,
    "pre-existing/skipped contracts are not modeled as independently verified plan entries",
    "UNMODELED_PREEXISTING",
  );

  const expected = new Map<string, EffectivePlanEntry>();
  for (const entry of plan.entries) {
    const key = planEntryKey(entry);
    assertCondition(!expected.has(key), `deployment plan contains duplicate effective entry ${key}`, "PLAN_DUPLICATE_ENTRY");
    expected.set(key, entry);
  }

  const actualEntries: Array<ContractPublicationEvidence | ContractCallEvidence> = [
    ...bundle.contractPublications,
    ...bundle.contractCalls,
  ];
  const actual = new Map<string, ContractPublicationEvidence | ContractCallEvidence>();
  for (const entry of actualEntries) {
    const key = evidenceEntryKey(entry);
    assertCondition(!actual.has(key), `evidence contains duplicate plan entry ${key}`, "DUPLICATE_PLAN_ENTRY");
    actual.set(key, entry);
    const expectedEntry = expected.get(key);
    assertCondition(expectedEntry !== undefined, `evidence contains an extra or mismatched plan entry ${key}`, "PLAN_EVIDENCE_MISMATCH");
    assertCondition(entry.expectedSender === expectedEntry.expectedSender, `evidence sender does not match plan entry ${key}`, "IDENTITY_MISMATCH");
    if (entry.kind === "contract-publish" && expectedEntry.kind === "contract-publish") {
      assertCondition(entry.contractName === expectedEntry.contractName, `evidence contract name does not match plan entry ${key}`, "IDENTITY_MISMATCH");
    }
    if (entry.kind === "contract-call" && expectedEntry.kind === "contract-call") {
      assertCondition(entry.functionName === expectedEntry.functionName, `evidence function does not match plan entry ${key}`, "FUNCTION_MISMATCH");
    }
  }

  const missing = [...expected.keys()].filter((key) => !actual.has(key));
  assertCondition(missing.length === 0, `evidence is missing ${missing.length} effective plan transaction(s): ${missing.slice(0, 5).join(", ")}`, "PLAN_EVIDENCE_MISMATCH");
  assertCondition(actual.size === expected.size, "evidence does not have a one-to-one mapping to the deployment plan", "PLAN_EVIDENCE_MISMATCH");
}

function validateReadOnlyCheckBinding(bundle: DeploymentEvidence, plan: ParsedDeploymentPlan): void {
  for (const [index, check] of (bundle.readOnlyChecks ?? []).entries()) {
    const path = `readOnlyChecks[${index}]`;
    assertCondition(check.network === plan.network, `${path}.network does not match the deployment plan`, "READ_ONLY_NETWORK_MISMATCH");
    assertCondition(check.network === bundle.network, `${path}.network does not match the evidence network`, "READ_ONLY_NETWORK_MISMATCH");

    const plannedEntries = plan.entries.filter((entry) => entry.contractId === check.contractId);
    assertCondition(
      plannedEntries.length > 0,
      `${path}.contractId is not covered by the bound deployment plan`,
      "READ_ONLY_PLAN_MISMATCH",
    );

    const evidenceEntries = [
      ...bundle.contractPublications,
      ...bundle.contractCalls,
    ].filter((entry) => entry.contractId === check.contractId);
    assertCondition(
      evidenceEntries.length > 0,
      `${path}.contractId is not covered by the bound deployment evidence`,
      "READ_ONLY_PLAN_MISMATCH",
    );

    const senders = new Set(evidenceEntries.map((entry) => entry.expectedSender));
    assertCondition(
      senders.has(check.sender),
      `${path}.sender is not a canonical sender for the covered contract evidence`,
      "READ_ONLY_SENDER_MISMATCH",
    );
  }
}

function validatePlanAndSource(bundle: DeploymentEvidence, options: VerifyEvidenceOptions): ParsedDeploymentPlan {
  assertCondition(bundle.network === options.network, "evidence network does not match requested network", "NETWORK_MISMATCH");
  assertCondition(bundle.deployer === options.deployer, "evidence deployer does not match requested deployer", "IDENTITY_MISMATCH");
  assertNetworkDeployer(options.network, options.deployer);
  if (options.sourceCommit !== undefined) {
    assertCommit(options.sourceCommit, "requested sourceCommit");
    assertCondition(bundle.sourceCommit === options.sourceCommit, "evidence source commit does not match requested source commit", "SOURCE_COMMIT_MISMATCH");
  }

  assertCondition(isNonEmptyString(options.planPath), "--plan is required for complete deployment evidence", "PLAN_REQUIRED");
  assertCondition(existsSync(options.planPath), `deployment plan does not exist: ${options.planPath}`, "PLAN_UNREADABLE");
  const expectedHash = sha256File(options.planPath);
  assertCondition(bundle.plan.sha256 === expectedHash, "evidence plan hash does not match deployment plan", "PLAN_HASH_MISMATCH");
  const plan = readDeploymentPlan(options.planPath);
  validateCompletePlanBinding(bundle, plan);
  validateReadOnlyCheckBinding(bundle, plan);
  return plan;
}

function readTransactionContractId(payload: JsonObject, kind: DeploymentTransactionKind, network: DeploymentNetwork): string {
  if (kind === "contract-publish") {
    const smartContract = payload.smart_contract;
    assertCondition(isObject(smartContract), "transaction response is missing smart_contract payload", "UNSUPPORTED_API_PAYLOAD");
    assertContractId(smartContract.contract_id, "transaction smart_contract.contract_id", network);
    return smartContract.contract_id;
  }

  const contractCall = payload.contract_call;
  assertCondition(isObject(contractCall), "transaction response is missing contract_call payload", "UNSUPPORTED_API_PAYLOAD");
  assertContractId(contractCall.contract_id, "transaction contract_call.contract_id", network);
  assertFunctionName(contractCall.function_name, "transaction contract_call.function_name", "UNSUPPORTED_API_PAYLOAD");
  return contractCall.contract_id;
}

function readTransactionFunctionName(payload: JsonObject, kind: DeploymentTransactionKind): string | null {
  if (kind === "contract-publish") return null;
  const contractCall = payload.contract_call;
  assertCondition(isObject(contractCall), "transaction response is missing contract_call payload", "UNSUPPORTED_API_PAYLOAD");
  assertFunctionName(contractCall.function_name, "transaction contract_call.function_name", "UNSUPPORTED_API_PAYLOAD");
  return contractCall.function_name;
}

function normaliseClarityHex(value: string): string {
  return `0x${value.replace(/^0x/i, "").toLowerCase()}`;
}

function assertCanonicalClarityHex(
  value: unknown,
  path: string,
  code = "MALFORMED_EVIDENCE",
): asserts value is string {
  assertCondition(
    typeof value === "string" && CLARITY_HEX_PATTERN.test(value) && value.replace(/^0x/i, "").length % 2 === 0,
    `${path} must be valid Clarity value hex`,
    code,
  );
  try {
    cvToHex(hexToCV(value));
  } catch {
    throw new DeploymentVerificationError(`${path} must encode one valid Clarity value`, code);
  }
}

function clarityHexFromRepr(value: string, path: string): string {
  const trimmed = value.trim();
  const contractPrincipalMatch = trimmed.match(/^'([A-Z0-9]+)\.([a-zA-Z][a-zA-Z0-9-]{0,39})'$/);
  if (contractPrincipalMatch !== null) {
    const [, address, contractName] = contractPrincipalMatch;
    assertAddress(address, `${path} principal`);
    assertContractName(contractName, `${path} contract name`, "PLAN_ARGUMENTS_UNSUPPORTED");
    try {
      return cvToHex(contractPrincipalCV(address, contractName)).toLowerCase();
    } catch {
      throw new DeploymentVerificationError(`${path} is not a supported canonical Clarity principal`, "PLAN_ARGUMENTS_UNSUPPORTED");
    }
  }

  const standardPrincipalMatch = trimmed.match(/^'([A-Z0-9]+)'$/);
  if (standardPrincipalMatch !== null) {
    const [, address] = standardPrincipalMatch;
    assertAddress(address, `${path} principal`);
    try {
      return cvToHex(standardPrincipalCV(address)).toLowerCase();
    } catch {
      throw new DeploymentVerificationError(`${path} is not a supported canonical Clarity principal`, "PLAN_ARGUMENTS_UNSUPPORTED");
    }
  }

  try {
    const parsed = internal_parseCommaSeparated(trimmed);
    assertCondition(parsed.length === 1, `${path} must contain exactly one Clarity value`, "PLAN_ARGUMENTS_UNSUPPORTED");
    return cvToHex(parsed[0] as ClarityValue).toLowerCase();
  } catch (error) {
    if (error instanceof DeploymentVerificationError) throw error;
    throw new DeploymentVerificationError(`${path} is not a supported canonical Clarity representation`, "PLAN_ARGUMENTS_UNSUPPORTED");
  }
}

function readAndVerifyCallArguments(
  payload: JsonObject,
  planEntry: EffectivePlanContractCall,
): CanonicalFunctionArgument[] {
  const contractCall = payload.contract_call;
  assertCondition(isObject(contractCall), "transaction response is missing contract_call payload", "UNSUPPORTED_API_PAYLOAD");
  const rawArguments = contractCall.function_args;
  assertCondition(Array.isArray(rawArguments), `transaction ${planEntry.planPosition.batchId}:${planEntry.planPosition.transactionIndex} is missing function_args`, "UNSUPPORTED_API_PAYLOAD");
  assertCondition(rawArguments.length === planEntry.parameters.length, "transaction function argument count does not match deployment plan", "ARGUMENT_MISMATCH");

  return rawArguments.map((rawArgument, index) => {
    const path = `transaction.contract_call.function_args[${index}]`;
    assertCondition(isObject(rawArgument), `${path} must be an object`, "UNSUPPORTED_API_PAYLOAD");
    assertFunctionName(rawArgument.name, `${path}.name`, "UNSUPPORTED_API_PAYLOAD");
    assertCondition(isNonEmptyString(rawArgument.type), `${path}.type must be non-empty`, "UNSUPPORTED_API_PAYLOAD");
    assertCanonicalClarityHex(rawArgument.hex, `${path}.hex`);
    assertCondition(isNonEmptyString(rawArgument.repr), `${path}.repr must be non-empty`, "UNSUPPORTED_API_PAYLOAD");
    const apiHex = cvToHex(hexToCV(rawArgument.hex)).toLowerCase();
    const reprHex = clarityHexFromRepr(rawArgument.repr, `${path}.repr`);
    const planHex = clarityHexFromRepr(planEntry.parameters[index], `deployment plan call argument ${index}`);
    assertCondition(apiHex === reprHex, `${path}.hex and ${path}.repr do not match`, "ARGUMENT_MISMATCH");
    assertCondition(apiHex === planHex, `${path} does not match the deployment plan argument`, "ARGUMENT_MISMATCH");
    return {
      name: rawArgument.name,
      type: rawArgument.type,
      hex: apiHex,
      repr: rawArgument.repr.trim(),
    };
  });
}

function safeTransactionStatus(value: unknown): string {
  if (typeof value === "string" && /^[a-z0-9_]{1,64}$/.test(value)) return value;
  return "unknown";
}

function transactionStatusError(txid: string, statusValue: unknown): DeploymentVerificationError {
  const status = safeTransactionStatus(statusValue);
  const retryable = status === "pending";
  let code = "TRANSACTION_NOT_CONFIRMED";
  if (status === "abort_by_response" || status === "abort_by_post_condition") code = "TRANSACTION_ABORTED";
  if (status.startsWith("dropped_")) code = "TRANSACTION_DROPPED";
  return new DeploymentVerificationError(
    `transaction ${txid} has status ${status}`,
    code,
    retryable,
    status,
  );
}

async function verifyTransaction(
  item: ContractPublicationEvidence | ContractCallEvidence,
  planEntry: EffectivePlanEntry,
  options: VerifyEvidenceOptions,
  baseUrl: string,
  fetcher: typeof fetch,
  observedAt: string,
): Promise<TransactionApiEvidence> {
  const endpoint = endpointUrl(baseUrl, `/extended/v1/tx/${encodeURIComponent(item.txid)}`);
  const response = await fetchJson(fetcher, endpoint, options.apiKey, baseUrl, {
    requestTimeoutMs: options.requestTimeoutMs,
  });
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
  assertAddress(payload.sender_address, "transaction.sender_address", options.network);
  assertCondition(payload.sender_address === item.expectedSender, "transaction sender does not match expected sender", "IDENTITY_MISMATCH");
  if (payload.tx_status !== "success") throw transactionStatusError(item.txid, payload.tx_status);
  assertCondition(payload.canonical === true, `transaction ${item.txid} is not canonical`, "TRANSACTION_NOT_CANONICAL", true);
  assertCondition(payload.is_unanchored === false, `transaction ${item.txid} is unanchored`, "TRANSACTION_UNANCHORED", true);

  const expectedType = item.kind === "contract-publish" ? "smart_contract" : "contract_call";
  assertCondition(payload.tx_type === expectedType, `transaction ${item.txid} has unexpected type`, "TRANSACTION_TYPE_MISMATCH");
  const actualContractId = readTransactionContractId(payload, item.kind, options.network);
  assertCondition(actualContractId === item.contractId, "transaction contract identity does not match expected contract", "IDENTITY_MISMATCH");
  const actualFunctionName = readTransactionFunctionName(payload, item.kind);
  if (item.kind === "contract-call") {
    assertCondition(actualFunctionName === item.functionName, "transaction function does not match expected function", "FUNCTION_MISMATCH");
  }

  let functionArgs: CanonicalFunctionArgument[] | undefined;
  if (item.kind === "contract-call") {
    assertCondition(planEntry.kind === "contract-call", "plan transaction kind does not match evidence", "PLAN_EVIDENCE_MISMATCH");
    functionArgs = readAndVerifyCallArguments(payload, planEntry);
  }

  const blockHash = payload.block_hash;
  const blockHeight = payload.block_height;
  const burnBlockHash = payload.burn_block_hash;
  const burnBlockHeight = payload.burn_block_height;
  assertCondition(isNonEmptyString(blockHash), "transaction API payload is missing block_hash", "UNSUPPORTED_API_PAYLOAD");
  assertCondition(Number.isInteger(blockHeight) && (blockHeight as number) > 0, "transaction API payload has invalid block_height", "UNSUPPORTED_API_PAYLOAD");
  assertCondition(Number.isInteger(burnBlockHeight) && (burnBlockHeight as number) > 0, "transaction API payload has invalid burn_block_height", "UNSUPPORTED_API_PAYLOAD");

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
    blockHeight: blockHeight as number,
    burnBlockHeight: burnBlockHeight as number,
  };
  if (burnBlockHash !== undefined && burnBlockHash !== null) {
    assertCondition(isNonEmptyString(burnBlockHash), "transaction API payload has invalid burn_block_hash", "UNSUPPORTED_API_PAYLOAD");
    evidence.burnBlockHash = burnBlockHash;
  }
  if (functionArgs !== undefined) evidence.functionArgs = functionArgs;
  if (payload.block_time_iso !== undefined && payload.block_time_iso !== null) {
    assertIsoTimestamp(payload.block_time_iso, "transaction.block_time_iso", "UNSUPPORTED_API_PAYLOAD");
    evidence.blockTimeIso = payload.block_time_iso;
  }
  if (payload.burn_block_time_iso !== undefined && payload.burn_block_time_iso !== null) {
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
  const response = await fetchJson(fetcher, endpoint, options.apiKey, baseUrl, {
    requestTimeoutMs: options.requestTimeoutMs,
  });
  if (response.status === 404) {
    throw new DeploymentVerificationError(`interface ${item.contractId} was not found at the checked API address`, "INTERFACE_NOT_FOUND", true);
  }
  if (response.status !== 200) {
    throw new DeploymentVerificationError(`interface lookup returned HTTP ${response.status}`, "INTERFACE_HTTP_ERROR", response.status >= 500 || response.status === 429);
  }
  assertCondition(isObject(response.body), "interface API payload must be an object", "UNSUPPORTED_API_PAYLOAD");
  const functions = readHiroInterfaceFunctions(response.body.functions, "interface.functions");
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

async function verifyReadOnlyCheck(
  check: ReadOnlyCheck,
  options: VerifyEvidenceOptions,
  baseUrl: string,
  fetcher: typeof fetch,
  observedAt: string,
): Promise<ReadOnlyApiEvidence> {
  const separator = check.contractId.lastIndexOf(".");
  const address = check.contractId.slice(0, separator);
  const contractName = check.contractId.slice(separator + 1);
  const endpoint = endpointUrl(
    baseUrl,
    `/v2/contracts/call-read/${encodeURIComponent(address)}/${encodeURIComponent(contractName)}/${encodeURIComponent(check.functionName)}`,
  );
  const response = await fetchJson(fetcher, endpoint, options.apiKey, baseUrl, {
    method: "POST",
    body: {
      sender: check.sender,
      arguments: check.arguments,
    },
    requestTimeoutMs: options.requestTimeoutMs,
    requestFailureCode: "READ_ONLY_REQUEST_FAILED",
    requestTimeoutCode: "READ_ONLY_TIMEOUT",
    malformedCode: "READ_ONLY_MALFORMED_RESPONSE",
  });

  if (response.status === 404) {
    throw new DeploymentVerificationError(
      `read-only function ${check.contractId}.${check.functionName} was not found at the checked API address`,
      "READ_ONLY_NOT_FOUND",
      true,
    );
  }
  if (response.status !== 200) {
    throw new DeploymentVerificationError(
      `read-only lookup returned HTTP ${response.status}`,
      "READ_ONLY_HTTP_ERROR",
      response.status >= 500 || response.status === 429,
    );
  }

  assertCondition(isObject(response.body), "read-only API payload must be an object", "READ_ONLY_MALFORMED_RESPONSE");
  assertCondition(typeof response.body.okay === "boolean", "read-only API payload is missing boolean okay", "READ_ONLY_MALFORMED_RESPONSE");
  if (response.body.okay !== true) {
    assertCondition(
      isNonEmptyString(response.body.cause),
      "read-only API failure payload is missing cause",
      "READ_ONLY_MALFORMED_RESPONSE",
    );
    throw new DeploymentVerificationError(
      `read-only function ${check.contractId}.${check.functionName} did not execute successfully`,
      "READ_ONLY_API_ERROR",
      false,
      "failed",
    );
  }

  assertCondition(
    check.expectedOkay === true,
    `read-only check ${check.contractId}.${check.functionName} has an unsupported expected okay state`,
    "READ_ONLY_EXPECTATION_INVALID",
  );
  assertCanonicalClarityHex(response.body.result, "read-only.result", "READ_ONLY_MALFORMED_RESPONSE");
  assertCondition(response.body.result.startsWith("0x"), "read-only.result must be 0x-prefixed", "READ_ONLY_MALFORMED_RESPONSE");
  const resultHex = cvToHex(hexToCV(response.body.result)).toLowerCase();
  const expectedResultHex = cvToHex(hexToCV(check.expectedResultHex)).toLowerCase();
  assertCondition(
    resultHex === expectedResultHex,
    `read-only result for ${check.contractId}.${check.functionName} did not match the declared expected result`,
    "READ_ONLY_MISMATCH",
  );

  return {
    observedAt,
    endpoint,
    httpStatus: 200,
    sender: check.sender,
    arguments: check.arguments.map((argument) => cvToHex(hexToCV(argument)).toLowerCase()),
    okay: true,
    resultHex,
  };
}

export async function verifyDeploymentEvidence(
  input: unknown,
  options: VerifyEvidenceOptions,
): Promise<DeploymentEvidence> {
  const bundle = parseEvidenceBundle(input);
  const plan = validatePlanAndSource(bundle, options);
  const baseUrl = normaliseBaseUrl(options.baseUrl ?? HIRO_API_BASE_URLS[options.network]);
  const fetcher = options.fetcher ?? fetch;
  const now = options.now ?? (() => new Date());
  const verifiedAt = now().toISOString();

  const contractPublications: ContractPublicationEvidence[] = [];
  for (const item of bundle.contractPublications) {
    const planEntry = plan.entries.find((entry) => planEntryKey(entry) === evidenceEntryKey(item));
    assertCondition(planEntry !== undefined, "publication evidence is not present in the deployment plan", "PLAN_EVIDENCE_MISMATCH");
    const observedAt = now().toISOString();
    contractPublications.push({
      ...item,
      apiEvidence: await verifyTransaction(item, planEntry, options, baseUrl, fetcher, observedAt),
    });
  }

  const contractCalls: ContractCallEvidence[] = [];
  for (const item of bundle.contractCalls) {
    const planEntry = plan.entries.find((entry) => planEntryKey(entry) === evidenceEntryKey(item));
    assertCondition(planEntry !== undefined, "call evidence is not present in the deployment plan", "PLAN_EVIDENCE_MISMATCH");
    const observedAt = now().toISOString();
    contractCalls.push({
      ...item,
      apiEvidence: await verifyTransaction(item, planEntry, options, baseUrl, fetcher, observedAt),
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

  const readOnlyChecks: ReadOnlyCheck[] = [];
  for (const item of bundle.readOnlyChecks ?? []) {
    const observedAt = now().toISOString();
    readOnlyChecks.push({
      ...item,
      arguments: item.arguments.map((argument) => cvToHex(hexToCV(argument)).toLowerCase()),
      expectedResultHex: cvToHex(hexToCV(item.expectedResultHex)).toLowerCase(),
      apiEvidence: await verifyReadOnlyCheck(item, options, baseUrl, fetcher, observedAt),
    });
  }

  return {
    ...bundle,
    evidenceStatus: "confirmed",
    coverage: "complete",
    verifiedAt,
    contractPublications,
    contractCalls,
    interfaces,
    ...(bundle.readOnlyChecks !== undefined ? { readOnlyChecks } : {}),
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
      lastError.status,
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
        "Usage: tsx scripts/deployment/verify-evidence.ts --evidence FILE --network testnet|mainnet --deployer ADDRESS --plan FILE [--source-commit SHA] [--api-base-url URL] [--output FILE]\n",
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
    assertCondition(isNonEmptyString(args.plan), "--plan is required", "CLI_ARGUMENT_ERROR");

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
    const output = `${JSON.stringify(verified, null, 2)}\n`;
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
