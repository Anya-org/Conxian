const fs = require('fs');
const path = require('path');

function walk(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    const dirPath = path.join(dir, f);
    if (fs.statSync(dirPath).isDirectory()) {
      walk(dirPath, callback);
    } else {
      callback(dirPath);
    }
  });
}

let violations = 0;

walk('contracts', (filePath) => {
  if (!filePath.endsWith('.clar')) return;
  const content = fs.readFileSync(filePath, 'utf8');
  
  // 1. Check for legacy block-height
  const blockHeightMatches = content.match(/(?<!stacks-|burn-)block-height/g);
  if (blockHeightMatches) {
    console.error(`[C4_VIOLATION] Found legacy 'block-height' in ${filePath}`);
    violations += blockHeightMatches.length;
  }
  
  // 2. Check for missing commas in tuples
  // Look for: Key: Value Key: Value
  // E.g., `amount: u0 fee: u0` -> missing comma
  const missingCommaMatches = content.match(/([a-zA-Z0-9\-]+:\s+(?:u[0-9]+|"[^"]*"|'[^']*'|true|false|[a-zA-Z0-9\-]+|\([^)]+\)))\s+([a-zA-Z0-9\-]+:)/g);
  if (missingCommaMatches) {
    console.error(`[SYNTAX_VIOLATION] Potential missing comma in tuple/list in ${filePath}:\n -> ${missingCommaMatches.join('\n -> ')}`);
    violations += missingCommaMatches.length;
  }
});

if (violations > 0) {
  console.error(`\nFAILED: Found ${violations} Clarity 4 syntax or standards violations. Please fix them to pass the CI gate.`);
  process.exit(1);
} else {
  console.log('SUCCESS: All contracts strictly adhere to Clarity 4 standards (no block-height leakage, no malformed tuples).');
  process.exit(0);
}
