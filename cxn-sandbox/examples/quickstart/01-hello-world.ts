/**
 * Conxian Hello World Example
 * 
 * This example demonstrates the simplest possible interaction with
 * the Conxian Gateway - a status check that requires no authentication.
 * 
 * TTFV Target: < 2 minutes
 */

import { ConxianGateway } from '@conxian/sdk';

async function main() {
  console.log('🌐 Connecting to Conxian Gateway...\n');

  // Create gateway client (no auth needed for sandbox)
  const gateway = new ConxianGateway({
    network: 'sandbox',
    baseUrl: process.env.CXN_GATEWAY_URL || 'http://localhost:3000'
  });

  try {
    // Get gateway status
    const status = await gateway.status();
    
    console.log('✅ Connected!\n');
    console.log('📊 Gateway Status:');
    console.log(`   Version:  ${status.version}`);
    console.log(`   Network:  ${status.network}`);
    console.log(`   Bitcoin:  ${status.bitcoin.blockHeight}`);
    console.log(`   Stacks:   ${status.stacks.blockHeight}`);
    console.log(`   Uptime:   ${formatUptime(status.uptime)}\n`);

    // Check supported features
    console.log('🔧 Supported Features:');
    for (const feature of status.features) {
      console.log(`   ${feature.enabled ? '✅' : '❌'} ${feature.name}`);
    }
    console.log('');

    // Get network info
    console.log('⛓️  Network Info:');
    console.log(`   Bitcoin RPC:    ${status.bitcoin.rpcUrl}`);
    console.log(`   Stacks API:    ${status.stacks.apiUrl}`);
    console.log(`   Settlement:    ${status.network}\n`);

    console.log('🎉 You are ready to build with Conxian!');
    console.log('');
    console.log('Next steps:');
    console.log('   1. Run: npm run example:payment');
    console.log('   2. Read: https://docs.conxian-labs.com');
    
  } catch (error) {
    console.error('❌ Connection failed:', error.message);
    console.log('\nMake sure the gateway is running:');
    console.log('   docker-compose up gateway');
    process.exit(1);
  }
}

function formatUptime(seconds: number): string {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  return `${days}d ${hours}h ${mins}m`;
}

main();
