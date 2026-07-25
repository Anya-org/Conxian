import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { validateStacksAddress } from "@stacks/transactions";

const DEFAULT_MANIFEST = "evidence/sbtc/phase2/v1.3.3/manifest.json";
const DEFAULT_MATRIX = "evidence/sbtc/phase2/v1.3.3/target-network-matrix.json";
const DEFAULT_VECTORS = "evidence/sbtc/phase2/v1.3.3/recipient-vectors.json";
const EXPECTED_UPSTREAM = {
  repository: "https://github.com/stacks-sbtc/sbtc",
  release: "v1.3.3",
  commit: "11567fc6a111c130177e64380503acca8546aab6",
} as const;
const EXPECTED_ARTIFACTS = {
  "withdrawal-contract": {
    path: "evidence/sbtc/phase2/v1.3.3/sources/sbtc-withdrawal.clar",
    sourcePath: "contracts/contracts/sbtc-withdrawal.clar",
    sha256: "104a89bc5b54bb5c8c8c1429e2e10e43e324e00249a096f04084d536055e1e71",
  },
  "registry-contract": {
    path: "evidence/sbtc/phase2/v1.3.3/sources/sbtc-registry.clar",
    sourcePath: "contracts/contracts/sbtc-registry.clar",
    sha256: "6769b24ae384bf5c3a15922a8ed42298b6bb7723ae30cf59c8619c172f500887",
  },
  "emily-public-openapi": {
    path: "evidence/sbtc/phase2/v1.3.3/sources/public-emily-openapi-spec.json",
    sourcePath:
      "emily/openapi-gen/generated-specs/public-emily-openapi-spec.json",
    sha256: "9d8f1236015c38b04f8b1a75915ac66c4fcdd78c7aa922c7ab6700344aff2147",
  },
} as const;
const REQUIRED_ARTIFACTS = [
  "withdrawal-contract",
  "registry-contract",
  "emily-public-openapi",
];
const REQUIRED_MATRIX_CELLS = {
  token: "contract",
  registry: "contract",
  deposit: "contract",
  withdrawal: "contract",
  "bootstrap-signers": "contract",
  "signer-state": "state",
  emily: "service",
} as const;
const SUPPORTED_TARGET_NETWORKS = ["mainnet", "testnet"] as const;
const REGISTRY_STATES = ["pending", "accepted", "rejected"];
const EMILY_STATES = ["pending", "accepted", "confirmed", "failed"];
const REQUIRED_SOLE_PROOF_CLAIMS = [
  "deploymentPlanAlone",
  "ciOrWorkflowAlone",
  "stacksConfirmationAlone",
  "emilyStatusAlone",
];

type JsonObject = Record<string, unknown>;

export interface EvidenceReason {
  code: string;
  message: string;
}

export interface EvidenceDecision {
  offlineSnapshot: "GO" | "NO-GO";
  officialNetworkIntegration: "GO" | "NO-GO";
  bitcoinSettlementClaim: "NO-GO";
  reasons: EvidenceReason[];
}

export interface VerifyOptions {
  rootDir?: string;
  manifestPath?: string;
  matrixPath?: string;
  vectorsPath?: string;
}

export interface RecipientTuple {
  version: number;
  hashbytes: string;
}

export interface UnsignedWithdrawalGateInput {
  amount: bigint;
  maxFee: bigint;
  recipient: RecipientTuple;
  token: { principal: string; chainVerified: boolean };
  withdrawal: { principal: string; chainVerified: boolean };
}

export interface UnsignedWithdrawalGateResult {
  allowed: false;
  lockedAmount: bigint;
  reviewOnlyIntent: {
    amount: bigint;
    maxFee: bigint;
    recipient: RecipientTuple;
    tokenDebit: "amount-plus-max-fee";
  };
  reasons: string[];
}

function asObject(value: unknown, label: string): JsonObject {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  return value as JsonObject;
}

function readJson(path: string): JsonObject {
  return asObject(JSON.parse(readFileSync(path, "utf8")), path);
}

function sha256(path: string): string {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function addReason(
  reasons: EvidenceReason[],
  code: string,
  message: string,
): void {
  reasons.push({ code, message });
}

function objectOrReason(
  value: unknown,
  label: string,
  reasons: EvidenceReason[],
  code: string,
): JsonObject {
  try {
    return asObject(value, label);
  } catch (error) {
    addReason(reasons, code, String(error));
    return {};
  }
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value) &&
    value.every((entry) => typeof entry === "string")
    ? value
    : [];
}

function sameStrings(actual: string[], expected: string[]): boolean {
  return (
    actual.length === expected.length &&
    actual.every((value, index) => value === expected[index])
  );
}

function nonPlaceholderString(value: unknown): value is string {
  if (typeof value !== "string" || value.trim() === "") return false;
  return !/^(?:unresolved|unknown|placeholder|tbd|todo|n\/?a|null|none)$/i.test(
    value.trim(),
  );
}

function validVerificationTimestamp(value: unknown): value is string {
  if (
    typeof value !== "string" ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(value)
  ) {
    return false;
  }
  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) && timestamp <= Date.now();
}

function validSha256(value: unknown): value is string {
  return typeof value === "string" && /^[0-9a-f]{64}$/i.test(value);
}

function validContractPrincipal(
  value: unknown,
  network: string,
): value is string {
  if (!nonPlaceholderString(value)) return false;
  const [address, contractName, ...extra] = value.split(".");
  if (extra.length > 0 || !address || !contractName) return false;
  if (!/^[a-zA-Z][a-zA-Z0-9_-]{0,39}$/.test(contractName)) return false;
  if (!validateStacksAddress(address)) return false;
  return network === "mainnet"
    ? address.startsWith("SP")
    : network === "testnet" && address.startsWith("ST");
}

function officialImmutableProvenance(
  value: unknown,
  label: string,
  upstreamCommit: string,
  reasons: EvidenceReason[],
): JsonObject {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    addReason(
      reasons,
      "MATRIX_PROVENANCE_MISSING",
      `${label} requires provenance evidence.`,
    );
    return {};
  }
  const provenance = value as JsonObject;
  const sourceUrl =
    typeof provenance.sourceUrl === "string" ? provenance.sourceUrl : "";
  let officialImmutableUrl = false;
  try {
    const url = new URL(sourceUrl);
    officialImmutableUrl =
      url.protocol === "https:" &&
      ((url.hostname === "raw.githubusercontent.com" &&
        url.pathname.startsWith(`/stacks-sbtc/sbtc/${upstreamCommit}/`)) ||
        (url.hostname === "github.com" &&
          url.pathname.startsWith(
            `/stacks-sbtc/sbtc/blob/${upstreamCommit}/`,
          )));
  } catch {
    officialImmutableUrl = false;
  }
  if (
    provenance.sourceCommit !== upstreamCommit ||
    !validSha256(provenance.sourceSha256) ||
    !officialImmutableUrl
  ) {
    addReason(
      reasons,
      "MATRIX_PROVENANCE_INVALID",
      `${label} requires an official immutable stacks-sbtc/sbtc source URL, the pinned commit, and a SHA-256.`,
    );
  }
  return provenance;
}

function validateContractCell(
  cell: JsonObject,
  id: string,
  network: string,
  upstreamCommit: string,
  reasons: EvidenceReason[],
): void {
  if (!validContractPrincipal(cell.principal, network)) {
    addReason(
      reasons,
      "MATRIX_CONTRACT_PRINCIPAL_INVALID",
      `${id}.principal must be a chain-valid ${(SUPPORTED_TARGET_NETWORKS as readonly string[]).includes(network) ? network : "supported target-network"} contract principal and not a placeholder.`,
    );
  }
  if (cell.chainVerified !== true) {
    addReason(
      reasons,
      "MATRIX_CHAIN_VERIFICATION_REQUIRED",
      `${id}.chainVerified must be true.`,
    );
  }
  const provenance = officialImmutableProvenance(
    cell.provenance,
    id,
    upstreamCommit,
    reasons,
  );
  if (
    cell.readBack === null ||
    typeof cell.readBack !== "object" ||
    Array.isArray(cell.readBack)
  ) {
    addReason(
      reasons,
      "MATRIX_READ_BACK_MISSING",
      `${id} requires on-chain read-back evidence.`,
    );
    if (!validVerificationTimestamp(cell.verifiedAt)) {
      addReason(
        reasons,
        "MATRIX_VERIFICATION_TIMESTAMP_INVALID",
        `${id}.verifiedAt must be a valid past UTC timestamp.`,
      );
    }
    return;
  }
  const readBack = cell.readBack as JsonObject;
  if (
    readBack.principal !== cell.principal ||
    !validSha256(readBack.sourceHash) ||
    readBack.sourceHash !== provenance.sourceSha256
  ) {
    addReason(
      reasons,
      "MATRIX_READ_BACK_INVALID",
      `${id}.readBack must match the principal and immutable source SHA-256.`,
    );
  }
  if (!validVerificationTimestamp(cell.verifiedAt)) {
    addReason(
      reasons,
      "MATRIX_VERIFICATION_TIMESTAMP_INVALID",
      `${id}.verifiedAt must be a valid past UTC timestamp.`,
    );
  }
}

function validateSignerStateCell(
  cell: JsonObject,
  upstreamCommit: string,
  reasons: EvidenceReason[],
): void {
  if (!nonPlaceholderString(cell.value)) {
    addReason(
      reasons,
      "SIGNER_STATE_VALUE_MISSING",
      "signer-state.value must contain substantive state evidence.",
    );
  }
  if (cell.chainVerified !== true) {
    addReason(
      reasons,
      "MATRIX_CHAIN_VERIFICATION_REQUIRED",
      "signer-state.chainVerified must be true.",
    );
  }
  const provenance = officialImmutableProvenance(
    cell.provenance,
    "signer-state",
    upstreamCommit,
    reasons,
  );
  if (
    cell.readBack === null ||
    typeof cell.readBack !== "object" ||
    Array.isArray(cell.readBack)
  ) {
    addReason(
      reasons,
      "MATRIX_READ_BACK_MISSING",
      "signer-state requires authoritative read-back evidence.",
    );
    if (!validVerificationTimestamp(cell.verifiedAt)) {
      addReason(
        reasons,
        "MATRIX_VERIFICATION_TIMESTAMP_INVALID",
        "signer-state.verifiedAt must be a valid past UTC timestamp.",
      );
    }
    return;
  }
  const readBack = cell.readBack as JsonObject;
  if (
    !nonPlaceholderString(readBack.value) ||
    readBack.value !== cell.value ||
    !validSha256(readBack.sourceHash) ||
    readBack.sourceHash !== provenance.sourceSha256
  ) {
    addReason(
      reasons,
      "SIGNER_STATE_READ_BACK_INVALID",
      "signer-state.readBack must contain the same substantive state and immutable source SHA-256.",
    );
  }
  if (!validVerificationTimestamp(cell.verifiedAt)) {
    addReason(
      reasons,
      "MATRIX_VERIFICATION_TIMESTAMP_INVALID",
      "signer-state.verifiedAt must be a valid past UTC timestamp.",
    );
  }
}

function validateEmilyCell(
  cell: JsonObject,
  upstreamCommit: string,
  reasons: EvidenceReason[],
): void {
  let validEndpoint = false;
  if (nonPlaceholderString(cell.endpoint)) {
    try {
      validEndpoint = new URL(cell.endpoint).protocol === "https:";
    } catch {
      validEndpoint = false;
    }
  }
  if (!validEndpoint) {
    addReason(
      reasons,
      "EMILY_ENDPOINT_INVALID",
      "emily.endpoint must be a non-placeholder HTTPS endpoint.",
    );
  }
  if (!nonPlaceholderString(cell.version)) {
    addReason(
      reasons,
      "EMILY_VERSION_MISSING",
      "emily.version must identify the verified API/schema version.",
    );
  }
  officialImmutableProvenance(
    cell.schemaEvidence,
    "emily.schemaEvidence",
    upstreamCommit,
    reasons,
  );
  if (cell.liveVerified !== true) {
    addReason(
      reasons,
      "EMILY_LIVE_VERIFICATION_REQUIRED",
      "emily.liveVerified must be true.",
    );
  }
  if (!validVerificationTimestamp(cell.verifiedAt)) {
    addReason(
      reasons,
      "MATRIX_VERIFICATION_TIMESTAMP_INVALID",
      "emily.verifiedAt must be a valid past UTC timestamp.",
    );
  }
}

export function validateOfficialNetworkMatrix(
  matrix: JsonObject,
  upstreamRelease: string = EXPECTED_UPSTREAM.release,
  upstreamCommit: string = EXPECTED_UPSTREAM.commit,
): EvidenceReason[] {
  const reasons: EvidenceReason[] = [];
  if (matrix.schemaVersion !== "1") {
    addReason(reasons, "MATRIX_SCHEMA_VERSION_UNSUPPORTED", "matrix.schemaVersion must be 1.");
  }
  if (
    matrix.upstreamRelease !== upstreamRelease ||
    matrix.upstreamCommit !== upstreamCommit
  ) {
    addReason(
      reasons,
      "MATRIX_PIN_MISMATCH",
      "Matrix pin must match the snapshot manifest.",
    );
  }

  const network =
    typeof matrix.targetNetwork === "string" ? matrix.targetNetwork : "";
  if (!(SUPPORTED_TARGET_NETWORKS as readonly string[]).includes(network)) {
    addReason(
      reasons,
      "TARGET_NETWORK_UNSUPPORTED",
      `targetNetwork must be one of: ${SUPPORTED_TARGET_NETWORKS.join(", ")}.`,
    );
  }

  const requiredEvidence = Array.isArray(matrix.requiredEvidence)
    ? matrix.requiredEvidence
    : [];
  if (!Array.isArray(matrix.requiredEvidence)) {
    addReason(
      reasons,
      "REQUIRED_EVIDENCE_INVALID",
      "requiredEvidence must be an array.",
    );
  }
  const cells = new Map<string, JsonObject>();
  for (const value of requiredEvidence) {
    const cell = objectOrReason(
      value,
      "matrix cell",
      reasons,
      "MATRIX_CELL_INVALID",
    );
    if (typeof cell.id !== "string" || cell.id.trim() === "") {
      addReason(
        reasons,
        "MATRIX_CELL_ID_INVALID",
        "Every matrix cell requires a nonempty id.",
      );
      continue;
    }
    if (!(cell.id in REQUIRED_MATRIX_CELLS)) {
      addReason(
        reasons,
        "MATRIX_CELL_UNEXPECTED",
        `Unexpected matrix cell: ${cell.id}.`,
      );
      continue;
    }
    if (cells.has(cell.id)) {
      addReason(
        reasons,
        "MATRIX_CELL_DUPLICATE",
        `Duplicate matrix cell: ${cell.id}.`,
      );
      continue;
    }
    cells.set(cell.id, cell);
  }

  for (const [id, expectedKind] of Object.entries(REQUIRED_MATRIX_CELLS)) {
    const cell = cells.get(id);
    if (!cell) {
      addReason(
        reasons,
        "MATRIX_CELL_MISSING",
        `Add required matrix cell: ${id}.`,
      );
      continue;
    }
    if (cell.kind !== expectedKind) {
      addReason(
        reasons,
        "MATRIX_CELL_KIND_INVALID",
        `${id}.kind must be ${expectedKind}; received ${String(cell.kind)}.`,
      );
      continue;
    }
    if (expectedKind === "contract")
      validateContractCell(cell, id, network, upstreamCommit, reasons);
    if (expectedKind === "state")
      validateSignerStateCell(cell, upstreamCommit, reasons);
    if (expectedKind === "service")
      validateEmilyCell(cell, upstreamCommit, reasons);
  }
  return reasons;
}

export function validateRecipientTuple(tuple: RecipientTuple): boolean {
  if (
    !Number.isInteger(tuple.version) ||
    tuple.version < 0 ||
    tuple.version > 6
  )
    return false;
  if (
    !/^[0-9a-fA-F]+$/.test(tuple.hashbytes) ||
    tuple.hashbytes.length % 2 !== 0
  )
    return false;
  const byteLength = tuple.hashbytes.length / 2;
  return tuple.version <= 4 ? byteLength === 20 : byteLength === 32;
}

export function expectedWithdrawalLock(amount: bigint, maxFee: bigint): bigint {
  if (amount < 0n || maxFee < 0n)
    throw new Error("amount and maxFee must be non-negative");
  return amount + maxFee;
}

export function evaluateUnsignedWithdrawalGate(
  input: UnsignedWithdrawalGateInput,
): UnsignedWithdrawalGateResult {
  const reasons: string[] = [];
  if (!validateRecipientTuple(input.recipient))
    reasons.push("INVALID_RECIPIENT_TUPLE");
  if (input.token.principal === "unresolved" || !input.token.chainVerified) {
    reasons.push("TOKEN_PRINCIPAL_NOT_CHAIN_VERIFIED");
  }
  if (
    input.withdrawal.principal === "unresolved" ||
    !input.withdrawal.chainVerified
  ) {
    reasons.push("WITHDRAWAL_PRINCIPAL_NOT_CHAIN_VERIFIED");
  }
  if (reasons.length === 0) {
    reasons.push("UNSIGNED_TRANSACTION_BUILDER_INTENTIONALLY_NOT_IMPLEMENTED");
  }
  return {
    allowed: false,
    lockedAmount: expectedWithdrawalLock(input.amount, input.maxFee),
    reviewOnlyIntent: {
      amount: input.amount,
      maxFee: input.maxFee,
      recipient: { ...input.recipient },
      tokenDebit: "amount-plus-max-fee",
    },
    reasons,
  };
}

export function verifyEvidencePack(
  options: VerifyOptions = {},
): EvidenceDecision {
  const rootDir = resolve(options.rootDir ?? process.cwd());
  const manifestPath = resolve(
    rootDir,
    options.manifestPath ?? DEFAULT_MANIFEST,
  );
  const matrixPath = resolve(rootDir, options.matrixPath ?? DEFAULT_MATRIX);
  const vectorsPath = resolve(rootDir, options.vectorsPath ?? DEFAULT_VECTORS);
  const offlineReasons: EvidenceReason[] = [];
  const integrationReasons: EvidenceReason[] = [];
  const settlementReasons: EvidenceReason[] = [];

  let manifest: JsonObject;
  let matrix: JsonObject;
  let vectorsDocument: JsonObject;
  try {
    manifest = readJson(manifestPath);
    matrix = readJson(matrixPath);
    vectorsDocument = readJson(vectorsPath);
  } catch (error) {
    addReason(offlineReasons, "EVIDENCE_FILE_INVALID", String(error));
    return {
      offlineSnapshot: "NO-GO",
      officialNetworkIntegration: "NO-GO",
      bitcoinSettlementClaim: "NO-GO",
      reasons: offlineReasons,
    };
  }

  const upstream = objectOrReason(
    manifest.upstream,
    "manifest.upstream",
    offlineReasons,
    "UPSTREAM_PIN_MISSING",
  );
  const release = typeof upstream.release === "string" ? upstream.release : "";
  const commit = typeof upstream.commit === "string" ? upstream.commit : "";
  const repository =
    typeof upstream.repository === "string" ? upstream.repository : "";
  if (
    !/^v\d+\.\d+\.\d+$/.test(release) ||
    ["main", "master", "latest"].includes(release)
  ) {
    addReason(
      offlineReasons,
      "FLOATING_UPSTREAM_RELEASE",
      "Pin a semantic upstream release tag.",
    );
  }
  if (!/^[0-9a-f]{40}$/.test(commit)) {
    addReason(
      offlineReasons,
      "MISSING_IMMUTABLE_COMMIT",
      "Pin a full 40-character upstream commit SHA.",
    );
  }
  if (
    repository !== EXPECTED_UPSTREAM.repository ||
    release !== EXPECTED_UPSTREAM.release ||
    commit !== EXPECTED_UPSTREAM.commit
  ) {
    addReason(
      offlineReasons,
      "UNEXPECTED_UPSTREAM_PIN",
      `Expected ${EXPECTED_UPSTREAM.repository} ${EXPECTED_UPSTREAM.release} at ${EXPECTED_UPSTREAM.commit}.`,
    );
  }

  const artifacts = Array.isArray(manifest.artifacts) ? manifest.artifacts : [];
  const artifactByKind = new Map<string, JsonObject>();
  for (const value of artifacts) {
    const artifact = objectOrReason(
      value,
      "manifest.artifact",
      offlineReasons,
      "ARTIFACT_METADATA_INVALID",
    );
    const kind = typeof artifact.kind === "string" ? artifact.kind : "";
    artifactByKind.set(kind, artifact);
    const path =
      typeof artifact.path === "string" ? resolve(rootDir, artifact.path) : "";
    const sourceUrl =
      typeof artifact.sourceUrl === "string" ? artifact.sourceUrl : "";
    const expectedHash =
      typeof artifact.sha256 === "string" ? artifact.sha256 : "";
    const expectedArtifact =
      EXPECTED_ARTIFACTS[kind as keyof typeof EXPECTED_ARTIFACTS];
    const immutableUrl = expectedArtifact
      ? `https://raw.githubusercontent.com/stacks-sbtc/sbtc/${EXPECTED_UPSTREAM.commit}/${expectedArtifact.sourcePath}`
      : "";
    if (
      expectedArtifact &&
      (artifact.path !== expectedArtifact.path ||
        artifact.sourcePath !== expectedArtifact.sourcePath ||
        artifact.sourceUrl !== immutableUrl ||
        artifact.sha256 !== expectedArtifact.sha256)
    ) {
      addReason(
        offlineReasons,
        "ARTIFACT_PROVENANCE_MISMATCH",
        `${kind} metadata must match the reviewed v1.3.3 snapshot.`,
      );
    }
    if (
      !path ||
      !sourceUrl.includes(commit) ||
      !/^https:\/\//.test(sourceUrl)
    ) {
      addReason(
        offlineReasons,
        "FLOATING_OR_MISSING_SOURCE_URL",
        `${kind || "unknown artifact"} must use an immutable HTTPS URL containing the full commit.`,
      );
      continue;
    }
    try {
      const actualHash = sha256(path);
      if (actualHash !== expectedHash) {
        addReason(
          offlineReasons,
          "ARTIFACT_HASH_MISMATCH",
          `${kind} SHA-256 mismatch: expected ${expectedHash}, got ${actualHash}.`,
        );
      }
    } catch (error) {
      addReason(
        offlineReasons,
        "ARTIFACT_MISSING",
        `${kind}: ${String(error)}`,
      );
    }
  }
  for (const kind of REQUIRED_ARTIFACTS) {
    if (!artifactByKind.has(kind)) {
      addReason(
        offlineReasons,
        "REQUIRED_ARTIFACT_MISSING",
        `Missing required ${kind} evidence.`,
      );
    }
  }

  const withdrawalArtifact = artifactByKind.get("withdrawal-contract");
  if (withdrawalArtifact && typeof withdrawalArtifact.path === "string") {
    try {
      const source = readFileSync(
        resolve(rootDir, withdrawalArtifact.path),
        "utf8",
      );
      const requiredAbiFragments = [
        "(define-public (initiate-withdrawal-request (amount uint)",
        "(recipient { version: (buff 1), hashbytes: (buff 32) })",
        "(max-fee uint)",
        "protocol-lock (+ amount max-fee)",
        "(define-read-only (validate-recipient",
      ];
      if (
        !requiredAbiFragments.every((fragment) => source.includes(fragment))
      ) {
        addReason(
          offlineReasons,
          "WITHDRAWAL_ABI_EVIDENCE_INVALID",
          "Pinned withdrawal ABI evidence is incomplete.",
        );
      }
    } catch (error) {
      addReason(
        offlineReasons,
        "WITHDRAWAL_ABI_EVIDENCE_UNREADABLE",
        String(error),
      );
    }
  }

  const registryArtifact = artifactByKind.get("registry-contract");
  if (registryArtifact && typeof registryArtifact.path === "string") {
    try {
      const source = readFileSync(
        resolve(rootDir, registryArtifact.path),
        "utf8",
      );
      if (
        !source.includes("(define-map withdrawal-status uint bool)") ||
        !source.includes("status: (map-get? withdrawal-status id)")
      ) {
        addReason(
          offlineReasons,
          "REGISTRY_STATE_EVIDENCE_INVALID",
          "Pinned registry status evidence is incomplete.",
        );
      }
    } catch (error) {
      addReason(
        offlineReasons,
        "REGISTRY_STATE_EVIDENCE_UNREADABLE",
        String(error),
      );
    }
  }

  const emilyArtifact = artifactByKind.get("emily-public-openapi");
  if (emilyArtifact && typeof emilyArtifact.path === "string") {
    try {
      const openApi = readJson(resolve(rootDir, emilyArtifact.path));
      const components = asObject(openApi.components, "openapi.components");
      const schemas = asObject(
        components.schemas,
        "openapi.components.schemas",
      );
      const withdrawalStatus = asObject(
        schemas.WithdrawalStatus,
        "openapi.WithdrawalStatus",
      );
      if (!sameStrings(stringArray(withdrawalStatus.enum), EMILY_STATES)) {
        addReason(
          offlineReasons,
          "EMILY_STATUS_SCHEMA_INVALID",
          "Emily withdrawal states do not match the pinned schema.",
        );
      }
    } catch (error) {
      addReason(offlineReasons, "EMILY_SCHEMA_INVALID", String(error));
    }
  }

  const vectors = Array.isArray(vectorsDocument.vectors)
    ? vectorsDocument.vectors
    : [];
  if (vectors.length === 0) {
    addReason(
      offlineReasons,
      "RECIPIENT_VECTORS_MISSING",
      "Recipient tuple vectors are required.",
    );
  }
  for (const value of vectors) {
    const vector = objectOrReason(
      value,
      "recipient vector",
      offlineReasons,
      "RECIPIENT_VECTOR_INVALID",
    );
    const name = typeof vector.name === "string" ? vector.name : "unnamed";
    const actual = validateRecipientTuple({
      version: typeof vector.version === "number" ? vector.version : Number.NaN,
      hashbytes: typeof vector.hashbytes === "string" ? vector.hashbytes : "",
    });
    if (actual !== vector.valid) {
      addReason(
        offlineReasons,
        "RECIPIENT_VECTOR_MISMATCH",
        `${name} expected valid=${String(vector.valid)}.`,
      );
    }
  }
  for (let version = 0; version <= 6; version += 1) {
    const expectedBytes = version <= 4 ? 20 : 32;
    const hasValidVector = vectors.some((value) => {
      const vector = value as JsonObject;
      return (
        vector.version === version &&
        vector.valid === true &&
        typeof vector.hashbytes === "string" &&
        vector.hashbytes.length === expectedBytes * 2
      );
    });
    if (!hasValidVector) {
      addReason(
        offlineReasons,
        "RECIPIENT_VECTOR_COVERAGE_MISSING",
        `Missing valid ${expectedBytes}-byte vector for version 0x${version.toString(16).padStart(2, "0")}.`,
      );
    }
  }
  const requiredInvalidCases = [
    { version: 0, bytes: 32, label: "20-byte version with 32-byte hash" },
    { version: 6, bytes: 20, label: "32-byte version with 20-byte hash" },
    { version: 7, bytes: 32, label: "unsupported version" },
  ];
  for (const required of requiredInvalidCases) {
    const present = vectors.some((value) => {
      const vector = value as JsonObject;
      return (
        vector.version === required.version &&
        vector.valid === false &&
        typeof vector.hashbytes === "string" &&
        vector.hashbytes.length === required.bytes * 2
      );
    });
    if (!present) {
      addReason(
        offlineReasons,
        "RECIPIENT_VECTOR_COVERAGE_MISSING",
        `Missing invalid boundary vector: ${required.label}.`,
      );
    }
  }

  integrationReasons.push(
    ...validateOfficialNetworkMatrix(matrix, release, commit),
  );

  const stateModels = objectOrReason(
    matrix.stateModels,
    "matrix.stateModels",
    integrationReasons,
    "STATE_MODELS_MISSING",
  );
  if (
    !sameStrings(stringArray(stateModels.registryWithdrawal), REGISTRY_STATES)
  ) {
    addReason(
      integrationReasons,
      "REGISTRY_STATES_INVALID",
      "Registry states must be pending|accepted|rejected.",
    );
  }
  if (!sameStrings(stringArray(stateModels.emilyWithdrawal), EMILY_STATES)) {
    addReason(
      integrationReasons,
      "EMILY_STATES_INVALID",
      "Emily states must be pending|accepted|confirmed|failed.",
    );
  }
  const registryEncoding = objectOrReason(
    stateModels.registryWithdrawalEncoding,
    "matrix.stateModels.registryWithdrawalEncoding",
    integrationReasons,
    "REGISTRY_STATE_ENCODING_MISSING",
  );
  if (
    registryEncoding.pending !== "status = none" ||
    registryEncoding.accepted !== "status = some true" ||
    registryEncoding.rejected !== "status = some false"
  ) {
    addReason(
      integrationReasons,
      "REGISTRY_STATE_ENCODING_INVALID",
      "Registry pending/accepted/rejected must preserve the upstream optional-bool encoding.",
    );
  }

  const settlementClaims = objectOrReason(
    matrix.settlementClaims,
    "matrix.settlementClaims",
    settlementReasons,
    "SETTLEMENT_CLAIM_POLICY_MISSING",
  );
  for (const claim of REQUIRED_SOLE_PROOF_CLAIMS) {
    if (settlementClaims[claim] !== false) {
      addReason(
        settlementReasons,
        "PROHIBITED_SOLE_SETTLEMENT_PROOF",
        `${claim} must remain false; it cannot prove Bitcoin recipient settlement alone.`,
      );
    }
  }
  const bitcoinOutputEvidence = objectOrReason(
    matrix.bitcoinOutputEvidence,
    "matrix.bitcoinOutputEvidence",
    settlementReasons,
    "BITCOIN_OUTPUT_EVIDENCE_MISSING",
  );
  for (const [field, value] of Object.entries(bitcoinOutputEvidence)) {
    if (value === "unresolved") {
      addReason(
        settlementReasons,
        "BITCOIN_OUTPUT_EVIDENCE_UNRESOLVED",
        `${field} remains unresolved.`,
      );
    }
  }
  addReason(
    settlementReasons,
    "OFFLINE_HARNESS_CANNOT_PROVE_SETTLEMENT",
    "This offline harness never grants a Bitcoin recipient settlement claim.",
  );

  const reasons = [
    ...offlineReasons,
    ...integrationReasons,
    ...settlementReasons,
  ].sort((a, b) =>
    `${a.code}:${a.message}`.localeCompare(`${b.code}:${b.message}`),
  );
  return {
    offlineSnapshot: offlineReasons.length === 0 ? "GO" : "NO-GO",
    officialNetworkIntegration:
      offlineReasons.length === 0 && integrationReasons.length === 0
        ? "GO"
        : "NO-GO",
    bitcoinSettlementClaim: "NO-GO",
    reasons,
  };
}

export function formatDecision(decision: EvidenceDecision): string {
  return [
    `OFFLINE_SNAPSHOT: ${decision.offlineSnapshot}`,
    `OFFICIAL_NETWORK_INTEGRATION: ${decision.officialNetworkIntegration}`,
    `BITCOIN_SETTLEMENT_CLAIM: ${decision.bitcoinSettlementClaim}`,
    "REASONS:",
    ...decision.reasons.map((reason) => `- ${reason.code}: ${reason.message}`),
  ].join("\n");
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : "";
if (invokedPath === fileURLToPath(import.meta.url)) {
  const decision = verifyEvidencePack();
  process.stdout.write(`${formatDecision(decision)}\n`);
  if (decision.offlineSnapshot === "NO-GO") process.exitCode = 1;
}
