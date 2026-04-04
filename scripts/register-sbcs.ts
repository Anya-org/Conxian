// scripts/register-sbcs.ts
// Codifies core Sovereign Business Cells (SBC) in fiscal-intelligence.clar
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  uintCV,
  stringAsciiCV,
} from '@stacks/transactions';
import { StacksTestnet } from '@stacks/network';

const network = new StacksTestnet();
const modulePath = fileURLToPath(import.meta.url);

const sbcs = ["Conxian-Core", "Nexus-Labs", "Fiscal-Auth", "Sovereign-Ops"];

function loadDotEnvIfPresent() {
  const moduleDir = dirname(modulePath);
  const searchDirs = [resolve(moduleDir, '..'), moduleDir, process.cwd()];

  const envPath = searchDirs
    .map((dir) => resolve(dir, '.env'))
    .find((candidate) => existsSync(candidate));

  if (!envPath) return;

  const fileText = readFileSync(envPath, 'utf8');
  for (const rawLine of fileText.split(/\r?\n/u)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;

    const eqIndex = line.indexOf('=');
    if (eqIndex === -1) continue;

    const key = line.slice(0, eqIndex).trim();
    if (!key) continue;

    let value = line.slice(eqIndex + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

function requirePrivateKey(): string {
  const privateKey = process.env.STX_PRIVATE_KEY?.trim();

  if (
    !privateKey ||
    privateKey === 'CHANGEME' ||
    privateKey === 'your_private_key_here' ||
    privateKey === 'YOUR_PRIVATE_KEY' ||
    privateKey === '<your_stacks_private_key_here>'
  ) {
    throw new Error(
      'STX_PRIVATE_KEY is missing or still set to a placeholder value; please provide a real private key'
    );
  }

  return privateKey;
}

async function registerSBCs(privateKey: string) {
  for (const sbc of sbcs) {
    const txOptions = {
      contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
      contractName: 'fiscal-intelligence',
      functionName: 'codify-sbc',
      functionArgs: [stringAsciiCV(sbc)],
      senderKey: privateKey,
      validateWithPostConditions: true,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
    };

    const transaction = await makeContractCall(txOptions);
    const broadcastResponse = await broadcastTransaction(transaction, network);
    console.log(`Registering SBC: ${sbc} - TX ID: ${broadcastResponse.txid}`);
  }
}

async function main() {
  loadDotEnvIfPresent();
  const privateKey = requirePrivateKey();
  await registerSBCs(privateKey);
}

const isMain = process.argv.slice(1).some((arg) => resolve(arg) === modulePath);

if (isMain) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
