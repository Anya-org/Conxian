import { generateWallet, generateSecretKey } from "@stacks/wallet-sdk";
import { getAddressFromPrivateKey } from "@stacks/transactions";

async function generateKeys(count: number) {
    const keys = [];
    for (let i = 0; i < count; i++) {
        const mnemonic = generateSecretKey();
        const wallet = await generateWallet({
            secretKey: mnemonic,
            password: "password123", // Temporary password for derivation
        });
        const account = wallet.accounts[0];
        const privateKey = account.stxPrivateKey;
        const address = getAddressFromPrivateKey(privateKey, 'testnet');
        const mainnetAddress = getAddressFromPrivateKey(privateKey, 'mainnet');
        
        keys.push({
            mnemonic,
            privateKey,
            testnetAddress: address,
            mainnetAddress
        });
    }
    return keys;
}

async function main() {
    console.log("=== BOS Wallet Key Generation ===");
    console.log("Generating 5 keys (2 Internal, 3 Deployer)...\n");
    
    const keys = await generateKeys(5);
    
    const labels = [
        "Internal Key 1",
        "Internal Key 2",
        "Deployer Key 1",
        "Deployer Key 2",
        "Deployer Key 3"
    ];
    
    keys.forEach((key, i) => {
        console.log(`--- ${labels[i]} ---`);
        console.log(`Address (Testnet): ${key.testnetAddress}`);
        console.log(`Address (Mainnet): ${key.mainnetAddress}`);
        console.log(`Private Key: ${key.privateKey}`);
        console.log(`Mnemonic: ${key.mnemonic}\n`);
    });
    
    console.log("IMPORTANT: Save these keys securely. Private keys and mnemonics will be registered as GitHub Secrets.");
}

main().catch(console.error);
