import { mkdir, writeFile } from "fs/promises";
import { dirname, resolve } from "path";
import { randomBytes } from "crypto";
import { generateWallet, generateSecretKey } from "@stacks/wallet-sdk";
import { getAddressFromPrivateKey } from "@stacks/transactions";

type GeneratedKey = {
  label: string;
  testnetAddress: string;
  mainnetAddress: string;
  privateKey: string;
  mnemonic: string;
};

type Args = {
  count: number;
  outFile: string;
  overwrite: boolean;
  printSecrets: boolean;
};

function printUsageAndExit(code: number): never {
  console.error(
    [
      "BOS wallet key generation (safe by default)",
      "",
      "Usage:",
      "  bun scripts/generate-bos-keys.ts [--count 5] [--out .tmp/bos-keys.json] [--overwrite] [--i-understand-this-leaks-secrets]",
      "",
      "Defaults:",
      "  - Writes key material to a local gitignored file (.tmp/...) with restrictive permissions.",
      "  - Prints ONLY public addresses to stdout.",
      "",
      "Flags:",
      "  --count <n>                         Number of keys to generate (default: 5)",
      "  --out <file>                        Where to write secrets JSON (default: .tmp/bos-keys.json)",
      "  --overwrite                         Allow overwriting --out if it already exists",
      "  --i-understand-this-leaks-secrets    Also print private keys/mnemonics to stdout",
    ].join("\n"),
  );

  process.exit(code);
}

function parseArgs(argv: string[]): Args {
  const args: Args = {
    count: 5,
    outFile: resolve(process.cwd(), ".tmp", "bos-keys.json"),
    overwrite: false,
    printSecrets: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];

    if (arg === "--help" || arg === "-h") {
      printUsageAndExit(0);
    }

    if (arg === "--count") {
      const value = argv[i + 1];
      if (!value) printUsageAndExit(1);
      const parsed = Number(value);
      if (!Number.isInteger(parsed) || parsed <= 0) {
        console.error(`Invalid --count: ${value}`);
        process.exit(1);
      }
      args.count = parsed;
      i++;
      continue;
    }

    if (arg === "--out") {
      const value = argv[i + 1];
      if (!value) printUsageAndExit(1);
      args.outFile = resolve(process.cwd(), value);
      i++;
      continue;
    }

    if (arg === "--overwrite") {
      args.overwrite = true;
      continue;
    }

    if (arg === "--i-understand-this-leaks-secrets") {
      args.printSecrets = true;
      continue;
    }

    console.error(`Unknown arg: ${arg}`);
    printUsageAndExit(1);
  }

  return args;
}

function defaultLabels(count: number): string[] {
  if (count === 5) {
    return [
      "Internal Key 1",
      "Internal Key 2",
      "Deployer Key 1",
      "Deployer Key 2",
      "Deployer Key 3",
    ];
  }

  return Array.from({ length: count }, (_, i) => `Key ${i + 1}`);
}

async function generateKeys(count: number): Promise<GeneratedKey[]> {
  const password = process.env.BOS_WALLET_PASSWORD ?? randomBytes(32).toString("hex");
  const labels = defaultLabels(count);

  const keys: GeneratedKey[] = [];

  for (let i = 0; i < count; i++) {
    const mnemonic = generateSecretKey();
    const wallet = await generateWallet({ secretKey: mnemonic, password });
    const account = wallet.accounts[0];

    if (!account) {
      throw new Error("Wallet generation returned no accounts");
    }

    const privateKey = account.stxPrivateKey;
    const testnetAddress = getAddressFromPrivateKey(privateKey, "testnet");
    const mainnetAddress = getAddressFromPrivateKey(privateKey, "mainnet");

    keys.push({
      label: labels[i] ?? `Key ${i + 1}`,
      mnemonic,
      privateKey,
      testnetAddress,
      mainnetAddress,
    });
  }

  return keys;
}

async function writeSecretsFile(outFile: string, keys: GeneratedKey[], overwrite: boolean): Promise<void> {
  await mkdir(dirname(outFile), { recursive: true, mode: 0o700 });

  await writeFile(
    outFile,
    JSON.stringify({ generatedAt: new Date().toISOString(), keys }, null, 2) + "\n",
    {
      mode: 0o600,
      flag: overwrite ? "w" : "wx",
    },
  );
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  console.log("=== BOS Wallet Key Generation ===");
  console.log(`Generating ${args.count} key(s)...`);

  const keys = await generateKeys(args.count);

  await writeSecretsFile(args.outFile, keys, args.overwrite);
  console.log(`\nWrote secret material to: ${args.outFile}`);
  console.log("(This path should be gitignored; do not commit it.)\n");

  for (const key of keys) {
    console.log(`--- ${key.label} ---`);
    console.log(`Address (Testnet): ${key.testnetAddress}`);
    console.log(`Address (Mainnet): ${key.mainnetAddress}`);

    if (args.printSecrets) {
      console.log("WARNING: Printing secret material to stdout.");
      console.log(`Private Key: ${key.privateKey}`);
      console.log(`Mnemonic: ${key.mnemonic}`);
    }

    console.log("");
  }

  if (!args.printSecrets) {
    console.log(
      "Note: private keys/mnemonics were NOT printed. If you really need stdout output, re-run with --i-understand-this-leaks-secrets.",
    );
  }
}

main().catch((err: unknown) => {
  console.error(err);
  process.exit(1);
});
