import { initSimnet } from '@stacks/clarinet-sdk'; async function main() { try { const simnet = await initSimnet(); console.log('Simnet Root initialized'); } catch (e) { console.error(e); } } main();
