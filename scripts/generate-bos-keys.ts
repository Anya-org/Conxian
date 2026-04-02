import { mkdir, writeFile } from "fs/promises";
import { dirname, resolve } from "path";
import { tmpdir } from "os";
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
  writeFile: boolean;
};

function printUsageAndExit(code: number): never {
  console.error(
    [
      "BOS wallet key generation (safe by default)",
      "",
      "Usage:",
      "  bun scripts/generate-bos-keys.ts [--count 5] [--out <file>] [--overwrite] [--no-file] [--i-understand-this-leaks-secrets]",
      "",
      "Defaults:",
      "  - Writes key material to a local file outside the repo (OS temp dir) with restrictive permissions.",
      "  - Prints ONLY public addresses to stdout.",
      "",
      "Flags:",
      "  --count <n>                         Number of keys to generate (default: 5)",
      "  --out <file>                        Where to write secrets JSON (default: OS temp dir)",
      "  --overwrite                         Allow overwriting --out if it already exists",
      "  --no-file                           Do not write secret material to disk",
      "  --i-understand-this-leaks-secrets    Also print private keys/mnemonics to stdout",
    ].join("\n"),
  );

  process.exit(code);
}

function parseArgs(argv: string[]): Args {
  const defaultOutFile = resolve(
    tmpdir(),
    `conxian-bos-keys-${new Date().toISOString().replace(/[:.]/g, "-")}.json`,
  );

  const args: Args = {
    count: 5,
    outFile: defaultOutFile,
    overwrite: false,
    printSecrets: false,
    writeFile: true,
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

    if (arg === "--no-file") {
      args.writeFile = false;
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

  if (!args.writeFile && !args.printSecrets) {
    console.error("Refusing to proceed: --no-file requires --i-understand-this-leaks-secrets (otherwise secrets have nowhere to go).");
    process.exit(1);
  }

  console.log("=== BOS Wallet Key Generation ===");
  console.log(`Generating ${args.count} key(s)...`);

  const keys = await generateKeys(args.count);

  if (args.writeFile) {
    try {
      await writeSecretsFile(args.outFile, keys, args.overwrite);
    } catch (err: unknown) {
      if (err && typeof err === "object" && "code" in err && (err as { code?: string }).code === "EEXIST") {
        console.error(
          `Refusing to overwrite existing secrets file at ${args.outFile}. ` +
            "Pass --overwrite to replace it, or delete the file manually.",
        );
        process.exit(1);
      }

      throw err;
    }

    console.log(`\nWrote secret material to: ${args.outFile}`);
    console.log("(Do not commit or share this file.)\n");
  } else {
    console.log("\nSkipping writing secret material to disk (--no-file).\n");
  }

  if (args.printSecrets) {
    console.log("WARNING: Printing secret material to stdout. This may be captured in logs.\n");
  }

  for (const key of keys) {
    console.log(`--- ${key.label} ---`);
    console.log(`Address (Testnet): ${key.testnetAddress}`);
    console.log(`Address (Mainnet): ${key.mainnetAddress}`);

    if (args.printSecrets) {
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
