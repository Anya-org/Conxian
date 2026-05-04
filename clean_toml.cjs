const fs = require('fs');
const content = fs.readFileSync('Clarinet.toml', 'utf8');

const missing = [
  'advanced-order-manager',
  'collateral-manager',
  'compliance-manager',
  'fee-manager',
  'gamification-manager',
  'gauge-manager',
  'migration-manager',
  'position-manager',
  'risk-manager',
  'upgrade-controller'
];

let result = content;
missing.forEach(m => {
  // Remove the block [contracts.X] \n path = "..." \n depends_on = [...]
  const regex = new RegExp(`\\[contracts\\.${m}\\][\\s\\S]*?(?=\\[contracts|$)`, 'g');
  result = result.replace(regex, '');
});

fs.writeFileSync('Clarinet.toml', result);
console.log("Cleaned Clarinet.toml");
