#!/usr/bin/env ts-node
/*
 * AutoVault Deployer Key Generator
 * ------------------------------------------------------------
 * Generates a BIP39 mnemonic and derives Stacks private keys + addresses.
 * Safe usage guidelines:
 *  - Run locally on a trusted, offline (or at least secure) machine.
 *  - NEVER commit the mnemonic or private key to version control.
 *  - Prefer a 24‑word (256-bit) mnemonic for production deployments.
 *  - Back up in at least two secure, offline locations.
 *  - Treat output as highly sensitive. Clear your terminal scrollback afterwards.
 *
 * Default behavior is NON-DESTRUCTIVE and will NOT generate secrets unless you pass --confirm.
 * This prevents accidental exposure inside CI logs or shared sessions.
 *
 * Usage Examples:
 *   npm run generate-deployer-key -- --confirm              # 24-word mnemonic, 1 account (index 0)
 *   npm run generate-deployer-key -- --strength 128 --confirm --accounts 2
 *   npm run generate-deployer-key -- --confirm --accounts 3 --out .deployer.keys
 *   npm run generate-deployer-key -- --test --confirm       # Uses a PUBLIC test mnemonic (DO NOT FUND)
 *
 * Optional flags:
 *   --strength <128|256>   Entropy bits (default 256 => 24 words)
 *   --accounts <N>          Number of sequential account indices to derive (default 1)
 *   --out <filepath>        Write a copy of the output to a file (chmod 600) (NOT RECOMMENDED for prod)
 *   --test                  Use a known public mnemonic (for dry tests only)
 *   --confirm               Actually generate / display secrets
 */

import * as fs from 'fs';
import * as path from 'path';
// bip39 is CommonJS; dynamic require for robustness if executed from subdirectory
// eslint-disable-next-line @typescript-eslint/no-var-requires
let bip39: any;
try {
  bip39 = require('bip39');
} catch (e) {
  try {
    // Fallback: attempt resolution relative to stacks workspace if script run from subfolder
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    bip39 = require(path.join(__dirname, '../stacks/node_modules/bip39'));
  } catch (e2) {
    console.error('Failed to load bip39 module. Ensure dependencies installed in stacks directory.');
    process.exit(1);
  }
}
import { AddressVersion, TransactionVersion } from '@stacks/transactions';
// Use scure bip32 for HD derivation
import { HDKey } from '@scure/bip32';
import { createStacksPrivateKey, getPublicKey, privateKeyToString } from '@stacks/transactions/dist/esm/keys';
import { publicKeyToAddressSingleSig } from '@stacks/transactions';
import { bytesToHex } from '@stacks/common';

interface CliOptions {
  strength: 128 | 256;
  accounts: number;
  out?: string;
  test: boolean;
  confirm: boolean;
}

function parseArgs(): CliOptions {
  const args = process.argv.slice(2);
  let strength: 128 | 256 = 256;
  let accounts = 1;
  let out: string | undefined;
  let test = false;
  let confirm = false;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--strength') {
      const v = args[++i];
      if (v !== '128' && v !== '256') throw new Error('strength must be 128 or 256');
      strength = Number(v) as 128 | 256;
    } else if (a === '--accounts') {
      accounts = Number(args[++i]);
      if (!Number.isInteger(accounts) || accounts < 1 || accounts > 10) {
        throw new Error('accounts must be integer 1..10');
      }
    } else if (a === '--out') {
      out = args[++i];
    } else if (a === '--test') {
      test = true;
    } else if (a === '--confirm') {
      confirm = true;
    } else if (a === '--help' || a === '-h') {
      usageAndExit(0);
    }
  }
  return { strength, accounts, out, test, confirm };
}

function usageAndExit(code: number) {
  console.log(`Usage: generate-deployer-key [--strength 128|256] [--accounts N] [--out file] [--test] --confirm\n`);
  process.exit(code);
}

function banner() {
  return `================ AutoVault Deployer Key Generator ================\nSECURITY WARNING: Secrets only generated when --confirm is supplied.\n=====================================================================`;
}

function main() {
  const opts = parseArgs();
  console.log(banner());
  if (!opts.confirm) {
    console.log('\n[DRY] No secrets generated. Re-run with --confirm to proceed.');
    return;
  }

  const mnemonic = opts.test
    ? // Public, known BIP39 test vector (NEVER FUND). If 24 words requested we extend deterministically.
      (opts.strength === 128
        ? 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
        : 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art')
    : bip39.generateMnemonic(opts.strength);

  const lines: string[] = [];
  lines.push('MNEMONIC (WRITE DOWN, KEEP OFFLINE):');
  lines.push(mnemonic);
  lines.push('');
  lines.push('DERIVED ACCOUNTS:');

  for (let i = 0; i < opts.accounts; i++) {
  const seed = bip39.mnemonicToSeedSync(mnemonic);
  const root = HDKey.fromMasterSeed(seed);
  const path = `m/44'/5757'/0'/0/${i}`; // SLIP-0044 coin type 5757 for Stacks
  const child = root.derive(path);
  if (!child.privateKey) throw new Error('Failed to derive child private key');
  const privHex = bytesToHex(child.privateKey);
  const stacksPriv = createStacksPrivateKey(privHex);
  const pub = getPublicKey(stacksPriv);
  const testnetAddr = publicKeyToAddressSingleSig(pub, AddressVersion.TestnetSingleSig);
  const mainnetAddr = publicKeyToAddressSingleSig(pub, AddressVersion.MainnetSingleSig);
  lines.push(`Account #${i}`);
  lines.push(`  Derivation Path     : ${path}`);
  lines.push(`  Testnet STX Address : ${testnetAddr}`);
  lines.push(`  Mainnet STX Address : ${mainnetAddr}`);
  lines.push(`  Private Key (hex)   : ${privateKeyToString(stacksPriv)}`);
  lines.push('');
  }

  lines.push('ENV EXPORT EXAMPLE (session only):');
  lines.push('  export DEPLOYER_PRIVKEY=<paste private key for desired account>');
  lines.push('');
  lines.push('Backup Guidance:');
  lines.push('  1. Record mnemonic on paper (ink, not erasable).');
  lines.push('  2. Store in two geotextically separate secure locations.');
  lines.push('  3. Optionally store encrypted in a password manager (never plain text cloud docs).');
  lines.push('  4. Do NOT phototext or email the mnemonic.');
  lines.push('  5. Consider using a hardware wallet for production if available.');

  const output = lines.join('\n');
  console.log('\n' + output);

  if (opts.out) {
    const outPath = path.resolve(process.cwd(), opts.out);
    if (fs.existsSync(outPath)) {
      console.error(`Refusing to overwrite existing file: ${outPath}`);
    } else {
      fs.writeFileSync(outPath, output, { encoding: 'utf8', flag: 'w' });
      fs.chmodSync(outPath, 0o600);
      console.log(`\n[written] ${outPath} (chmod 600)`);
    }
  }
}

main();
