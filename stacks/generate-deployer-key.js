#!/usr/bin/env node
/*
 * Conxian Deployer Key Generator (JS Runtime Version)
 * -----------------------------------------------------
 * Generates a BIP39 mnemonic and derives Stacks private keys + addresses.
 * SECURITY: Never share production mnemonics or private keys in chat/logs.
 * This tool only generates secrets locally when you pass --confirm.
 *
 * Flags:
 *   --confirm              Actually generate and display secrets
 *   --strength 128|256     Entropy bits (default 256 => 24 words)
 *   --accounts N           Number of sequential accounts (default 1, max 10)
 *   --test                 Use well-known public mnemonic (DO NOT FUND) for dry runs
 *   --out file             Save a copy (chmod 600) - optional; avoid for prod
 */
const fs = require('fs');
const path = require('path');
const bip39 = require('bip39');
const { mnemonicToSeedSync } = bip39;
const { HDKey } = require('@scure/bip32');
const { getAddressFromPrivateKey } = require('@stacks/transactions');
const { bytesToHex } = require('@stacks/common');

// Derive Stacks key using BIP44 path m/44'/5757'/0'/0/index
function deriveAccount(mnemonic, index) {
  const seed = mnemonicToSeedSync(mnemonic);
  const root = HDKey.fromMasterSeed(seed);
  const path = `m/44'/5757'/0'/0/${index}`; // 5757 = STX coin type
  const child = root.derive(path);
  if (!child.privateKey) throw new Error('Failed to derive private key');
  let privHex = bytesToHex(child.privateKey);
  if (!privHex.endsWith('01')) privHex = privHex + '01'; // ensure compressed
  const testnetAddr = getAddressFromPrivateKey(privHex, 'testnet');
  const mainnetAddr = getAddressFromPrivateKey(privHex, 'mainnet');
  return { privateKey: privHex, testnetAddr, mainnetAddr, path };
}

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { strength: 256, accounts: 1, test: false, confirm: false, out: null, json: false };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    switch (a) {
      case '--strength':
        opts.strength = Number(args[++i]);
        if (![128, 256].includes(opts.strength)) throw new Error('strength must be 128 or 256');
        break;
      case '--accounts':
        opts.accounts = Number(args[++i]);
        if (!(opts.accounts >= 1 && opts.accounts <= 10)) throw new Error('accounts 1..10');
        break;
      case '--test':
        opts.test = true; break;
      case '--confirm':
        opts.confirm = true; break;
      case '--out':
        opts.out = args[++i]; break;
      case '--json':
        opts.json = true; break;
      case '--help':
      case '-h':
        usage(); process.exit(0);
      default:
        throw new Error(`Unknown arg: ${a}`);
    }
  }
  return opts;
}

function usage() {
  console.log(`Usage: npm run gen-key -- [--confirm] [--strength 128|256] [--accounts N] [--test] [--out file] [--json]\n`);
}

function banner() {
  return '================ Conxian Deployer Key Generator ================';
}

function main() {
  try {
    const opts = parseArgs();
    console.log(banner());
    if (!opts.confirm) {
      console.log('\n[DRY] No secrets generated. Re-run with --confirm to display mnemonic and keys.');
      return;
    }
    const mnemonic = opts.test
      ? (opts.strength === 128
          ? 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
          : 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art')
      : bip39.generateMnemonic(opts.strength);

    const accounts = [];
    for (let i = 0; i < opts.accounts; i++) accounts.push(deriveAccount(mnemonic, i));
    if (opts.json) {
      const jsonOut = { mnemonic, accounts };
      console.log(JSON.stringify(jsonOut, null, 2));
      if (opts.out) {
        const outPath = path.resolve(opts.out);
        if (fs.existsSync(outPath)) throw new Error(`Refusing to overwrite existing file: ${outPath}`);
        fs.writeFileSync(outPath, JSON.stringify(jsonOut, null, 2), 'utf8');
        fs.chmodSync(outPath, 0o600);
        console.log(`\n[written] ${outPath} (chmod 600)`);
      }
    } else {
      const lines = [];
      lines.push('MNEMONIC (BACKUP OFFLINE):');
      lines.push(mnemonic);
      lines.push('');
      lines.push('DERIVED ACCOUNTS:');
      accounts.forEach((acct, i) => {
        lines.push(`Account #${i}`);
        lines.push(`  Derivation Path     : ${acct.path}`);
        lines.push(`  Testnet STX Address : ${acct.testnetAddr}`);
        lines.push(`  Mainnet STX Address : ${acct.mainnetAddr}`);
        lines.push(`  Private Key (hex)   : ${acct.privateKey}`);
        lines.push('');
      });
      lines.push('Export for deploy (session only):');
      lines.push('  export DEPLOYER_PRIVKEY=<private key from Account #0>');
      lines.push('');
      lines.push('Backup Guidance:');
      lines.push('  1. Write mnemonic on paper (ink).');
      lines.push('  2. Store in two secure locations.');
      lines.push('  3. Optional: encrypted password manager (not plain cloud doc).');
      lines.push('  4. Never post mnemonic or key in chat, issues, or commits.');
      lines.push('');
      const out = lines.join('\n');
      console.log('\n' + out);
      if (opts.out) {
        const outPath = path.resolve(opts.out);
        if (fs.existsSync(outPath)) throw new Error(`Refusing to overwrite existing file: ${outPath}`);
        fs.writeFileSync(outPath, out, 'utf8');
        fs.chmodSync(outPath, 0o600);
        console.log(`\n[written] ${outPath} (chmod 600)`);
      }
    }
  } catch (err) {
    console.error('Error:', err.message || err);
    process.exit(1);
  }
}

main();
