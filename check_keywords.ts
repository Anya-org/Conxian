import { initSimnet } from "@stacks/clarinet-sdk";

async function main() {
  try {
    const simnet = await initSimnet();
    const keywords = ["stacks-block-time", "stacks-block-height", "contract-hash?", "secp256r1-verify", "to-ascii?", "restrict-assets?"];
    for (const kw of keywords) {
      try {
        const result = simnet.runSnippet(kw);
        console.log(`${kw} result:`, result);
      } catch (e) {
        console.log(`${kw} failed.`);
      }
    }
  } catch (e) {
    console.error(e);
  }
}

main();
