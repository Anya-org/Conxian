/**
* Conxian testnet deployment helper.
*
* This script broadcasts only the existing deployment sequence. A broadcast
* is never treated as completion: every new publication must be confirmed by
* the fail-closed evidence verifier before the script exits successfully.
*/
import "dotenv/config";
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  PostConditionMode,
  broadcastTransaction,
  getAddressFromPrivateKey,
  makeContractDeploy,
} from "@stacks/transactions";
import { STACKS_TESTNET } from "@stacks/network";
import {
  sha256File,
  waitForDeploymentEvidence,
  type ContractPublicationEvidence,
  type DeploymentEvidence,
  type InterfaceExpectation,
} from "./deployment/verify-evidence";

type DeploymentContract = {
  name: string;
  path: string;
  requiredFunctions?: InterfaceExpectation["requiredFunctions"];
};

const CORE_API_URL = process.env.CORE_API_URL || "https://api.testnet.hiro.so";
const HIRO_API_KEY = process.env.HIRO_API_KEY;
const network = { ...STACKS_TESTNET, coreApiUrl: CORE_API_URL };

const apiHeaders: Record<string, string> = {
  accept: "application/json",
  ...(HIRO_API_KEY ? { "x-hiro-api-key": HIRO_API_KEY } : {}),
};

export const DEPLOYMENT_TRANSACTION_POLICY = {
  postConditionMode: PostConditionMode.Deny,
} as const;

// CSF deployment sequence: traits → core → oracle → tokens → security → dex → agents.
export const DEPLOYMENT_SEQUENCE: DeploymentContract[] = [
  // Phase 1: Traits
  { name: "sip-standards", path: "contracts/traits/sip-standards.clar" },
  { name: "core-traits", path: "contracts/traits/core-traits.clar" },
  { name: "security-monitoring", path: "contracts/traits/security-monitoring.clar" },
  { name: "automation-traits", path: "contracts/traits/automation-traits.clar" },
  { name: "conxian-service-trait", path: "contracts/traits/conxian-service-trait.clar" },
  { name: "defi-traits", path: "contracts/traits/defi-traits.clar" },
  { name: "conxian-csf-trait", path: "contracts/traits/conxian-csf-trait.clar" },
  { name: "conxian-intent-trait", path: "contracts/traits/conxian-intent-trait.clar" },
  // Phase 2: Core Access & Protocol
  { name: "conxian-access", path: "contracts/core/conxian-access.clar" },
  { name: "conxian-protocol", path: "contracts/core/conxian-protocol.clar" },
  // Phase 3: Oracle
  { name: "oracle-aggregator", path: "contracts/oracle/oracle-aggregator.clar" },
  // Phase 4: Tokens
  { name: "cxd-token", path: "contracts/tokens/cxd-token.clar" },
  // Phase 5: BME Engine
  { name: "bme-engine", path: "contracts/core/bme-engine.clar" },
  // Phase 6: Treasury
  { name: "cxd-treasury", path: "contracts/treasury/cxd-treasury.clar" },
  // Phase 7: Security
  { name: "mev-protector", path: "contracts/security/mev-protector.clar" },
  { name: "enhanced-circuit-breaker", path: "contracts/security/enhanced-circuit-breaker.clar" },
  // Phase 8: DEX Core
  { name: "concentrated-liquidity-pool", path: "contracts/dex/concentrated-liquidity-pool.clar" },
  { name: "swap-router", path: "contracts/dex/swap-router.clar" },
  { name: "dex-factory", path: "contracts/dex/dex-factory.clar" },
  // Phase 9: Revenue
  { name: "revenue-distributor", path: "contracts/treasury/revenue-distributor.clar" },
  // Phase 10: Agents
  { name: "agent-risk", path: "contracts/agents/agent-risk.clar" },
  { name: "agent-treasury", path: "contracts/agents/agent-treasury.clar" },
  // Phase 11: Ops
  { name: "ops-engine", path: "contracts/core/ops-engine.clar" },
  // Phase 12: Gateway and automation
  { name: "intent-solver-gateway", path: "contracts/gateway/intent-solver-gateway.clar" },
  { name: "revenue-automation", path: "contracts/treasury/revenue-automation.clar" },
];

function requiredEnvironment(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`${name} is required`);
  }
  return value;
}

async function getJson(url: string): Promise<{ status: number; body: unknown }> {
  let response: Response;
  try {
    response = await fetch(url, { headers: apiHeaders });
  } catch {
    throw new Error(`request failed for ${url}`);
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    throw new Error(`API returned malformed JSON for ${url}`);
  }
  return { status: response.status, body };
}

async function getAccountNonce(address: string): Promise<number> {
  const response = await getJson(`${CORE_API_URL}/v2/accounts/${encodeURIComponent(address)}?proof=0`);
  if (response.status !== 200 || typeof response.body !== "object" || response.body === null) {
    throw new Error(`unable to read deployer nonce (HTTP ${response.status})`);
  }
  const nonce = (response.body as { nonce?: unknown }).nonce;
  if (!Number.isInteger(nonce) || (nonce as number) < 0) {
    throw new Error("deployer nonce response is malformed");
  }
  return nonce as number;
}

async function checkContractExists(address: string, contractName: string): Promise<boolean> {
  const response = await getJson(
    `${CORE_API_URL}/v2/contracts/interface/${encodeURIComponent(address)}/${encodeURIComponent(contractName)}`,
  );
  if (response.status === 404) return false;
  if (response.status === 200) return true;
  throw new Error(`interface preflight failed for ${contractName} (HTTP ${response.status})`);
}

async function deployContract(contract: DeploymentContract, nonce: number, deployerPrivateKey: string): Promise<string> {
  const contractCode = readFileSync(join(process.cwd(), contract.path), "utf8");
  const tx = await makeContractDeploy({
    contractName: contract.name,
    codeBody: contractCode,
    senderKey: deployerPrivateKey,
    network,
    nonce: BigInt(nonce),
    ...DEPLOYMENT_TRANSACTION_POLICY,
    fee: BigInt(500000),
  });

  console.log(`Broadcasting ${contract.name} (nonce: ${nonce})...`);
  const broadcastResponse = await broadcastTransaction({ transaction: tx, network });
  if ("error" in broadcastResponse) {
    throw new Error(`broadcast failed for ${contract.name}: ${broadcastResponse.error}`);
  }
  if (typeof broadcastResponse.txid !== "string" || broadcastResponse.txid.trim().length === 0) {
    throw new Error(`broadcast returned no transaction ID for ${contract.name}`);
  }
  console.log(`  Broadcast accepted for ${contract.name}`);
  return broadcastResponse.txid;
}

function sourceCommit(): string {
  if (process.env.SOURCE_COMMIT) return process.env.SOURCE_COMMIT;
  try {
    return execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim();
  } catch {
    throw new Error("SOURCE_COMMIT is required when git metadata is unavailable");
  }
}

function writeEvidence(path: string, evidence: DeploymentEvidence): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(evidence, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
}

export async function main(): Promise<void> {
  const deployerPrivateKey = requiredEnvironment("DEPLOYER_PRIVKEY");
  const deployerAddress = requiredEnvironment("SYSTEM_ADDRESS");
  const planPath = resolve(process.env.DEPLOYMENT_PLAN_PATH || "deployments/full-system.testnet-plan.yaml");
  const evidencePath = resolve(process.env.DEPLOYMENT_EVIDENCE_PATH || "deployment/testnet-deployment-evidence.json");
  const broadcastEvidencePath = `${evidencePath}.broadcast.json`;
  const planSha256 = sha256File(planPath);
  const commit = sourceCommit();

  const derivedAddress = getAddressFromPrivateKey(deployerPrivateKey, STACKS_TESTNET);
  if (derivedAddress !== deployerAddress) {
    throw new Error("SYSTEM_ADDRESS does not match the supplied deployer key");
  }

  console.log("=== Conxian Testnet Deployment ===");
  console.log(`Network: ${CORE_API_URL}`);
  console.log(`Deployer: ${deployerAddress}`);
  console.log("");

  let nonce = await getAccountNonce(deployerAddress);
  const contractPublications: ContractPublicationEvidence[] = [];
  const interfaces: InterfaceExpectation[] = [];
  const preexistingContracts: string[] = [];

  for (const contract of DEPLOYMENT_SEQUENCE) {
    const contractId = `${deployerAddress}.${contract.name}`;
    interfaces.push({
      contractId,
      requiredFunctions: contract.requiredFunctions ?? [],
    });

    const exists = await checkContractExists(deployerAddress, contract.name);
    if (exists) {
      preexistingContracts.push(contractId);
      console.log(`  ↩ ${contract.name} - already present at checked address, skipping broadcast`);
      continue;
    }

    const txid = await deployContract(contract, nonce, deployerPrivateKey);
    contractPublications.push({
      kind: "contract-publish",
      contractName: contract.name,
      contractId,
      expectedSender: deployerAddress,
      txid,
    });
    nonce += 1;
  }

  if (contractPublications.length === 0) {
    throw new Error("no new contract publications were broadcast; no canonical deployment evidence can be produced");
  }

  const evidence: DeploymentEvidence = {
    schemaVersion: "1",
    evidenceStatus: "broadcast",
    generatedAt: new Date().toISOString(),
    sourceCommit: commit,
    network: "testnet",
    deployer: deployerAddress,
    plan: {
      path: relative(process.cwd(), planPath),
      sha256: planSha256,
    },
    claims: {
      scope: "checked-addresses",
      globalNonexistence: false,
    },
    contractPublications,
    contractCalls: [],
    interfaces,
    preexistingContracts,
  };

  // Preserve the broadcast-only record as non-proof. The confirmed file is
  // written only after the verifier has observed canonical successful txs.
  writeEvidence(broadcastEvidencePath, evidence);
  const verified = await waitForDeploymentEvidence(evidence, {
    network: "testnet",
    deployer: deployerAddress,
    baseUrl: CORE_API_URL,
    apiKey: HIRO_API_KEY,
    planPath,
    sourceCommit: commit,
    timeoutMs: Number(process.env.DEPLOY_CONFIRM_TIMEOUT_MS || 10 * 60 * 1000),
    pollIntervalMs: Number(process.env.DEPLOY_CONFIRM_POLL_MS || 15 * 1000),
  });
  writeEvidence(evidencePath, verified);

  console.log(`Canonical deployment evidence written to ${relative(process.cwd(), evidencePath)}`);
  console.log("Deployment finished only after canonical receipt and interface verification.");
}

const isDirectRun = process.argv[1] !== undefined && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isDirectRun) {
  void main().catch((error: unknown) => {
    const message = error instanceof Error ? error.message : "testnet deployment failed";
    process.stderr.write(`testnet deployment failed: ${message}\n`);
    process.exitCode = 1;
  });
}
