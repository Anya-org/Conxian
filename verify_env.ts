import { initSimnet } from "@stacks/clarinet-sdk";

async function main() {
  try {
    console.log("Initializing Simnet...");
    const simnet = await initSimnet();
    console.log("Simnet initialized successfully.");

    console.log("Checking Clarity 4 keywords...");
    try {
      const result = simnet.runSnippet("stacks-block-time");
      console.log("stacks-block-time result:", result);
    } catch (e) {
      console.log("stacks-block-time snippet failed (as expected if unresolved).");
    }

    try {
      const result = simnet.runSnippet("burn-block-height");
      console.log("burn-block-height result:", result);
    } catch (e) {
       console.log("burn-block-height snippet failed.");
    }

  } catch (e) {
    console.error("Simnet initialization failed:");
    console.error(e);
  }
}

main();
