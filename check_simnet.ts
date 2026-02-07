import { initSimnet } from "@stacks/clarinet-sdk";

async function main() {
  try {
    const simnet = await initSimnet();
    console.log("Simnet initialized successfully");
  } catch (e) {
    console.error("Simnet initialization failed:");
    console.error(e);
  }
}

main();
