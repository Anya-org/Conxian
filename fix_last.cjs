const fs = require('fs');

const filePath = 'contracts/dex/concentrated-liquidity-pool.clar';
let content = fs.readFileSync(filePath, 'utf8');

// Fix Line 39
content = content.replace(
  '{ amount-out: amount-out fee-collected: u0 }',
  '{ amount-out: amount-out, fee-collected: u0 }'
);

// Fix Line 103
content = content.replace(
  '{ token-0: tx-sender token-1: tx-sender fee: u3000 liquidity: u0 sqrt-price: u0 tick: 0 }',
  '{ token-0: tx-sender, token-1: tx-sender, fee: u3000, liquidity: u0, sqrt-price: u0, tick: 0 }'
);
// Catch variations just in case
content = content.replace(
  '{ token-0: tx-sender, token-1: tx-sender fee: u3000 liquidity: u0 sqrt-price: u0 tick: 0 }',
  '{ token-0: tx-sender, token-1: tx-sender, fee: u3000, liquidity: u0, sqrt-price: u0, tick: 0 }'
);

// Fix Line 120
content = content.replace(
  '{ event: "dex-tax-processed" success: (is-ok tax-res) }',
  '{ event: "dex-tax-processed", success: (is-ok tax-res) }'
);

// Catch line 131 if present
content = content.replace(
  '{ event: "bme-report-processed" success: (is-ok bme-res) }',
  '{ event: "bme-report-processed", success: (is-ok bme-res) }'
);

fs.writeFileSync(filePath, content);
console.log("Surgically repaired concentrated-liquidity-pool.clar");
