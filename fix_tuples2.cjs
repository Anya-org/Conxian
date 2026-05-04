const fs = require('fs');
const path = require('path');

function walk(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    const dirPath = path.join(dir, f);
    if (fs.statSync(dirPath).isDirectory()) walk(dirPath, callback);
    else callback(dirPath);
  });
}

walk('contracts', (filePath) => {
  if (!filePath.endsWith('.clar')) return;
  let content = fs.readFileSync(filePath, 'utf8');
  let original = content;
  
  // Find cases where there is a key-value pair followed by another key without a comma
  // Example: `id: nft-id, to: recipient nonce: nonce` -> `id: nft-id, to: recipient, nonce: nonce`
  for (let i = 0; i < 10; i++) {
    content = content.replace(/([a-zA-Z0-9\-]+:\s+(?:u[0-9]+|"[^"]*"|'[^']*'|true|false|[a-zA-Z0-9\-]+|\([^)]+\)))\s+([a-zA-Z0-9\-]+:)/g, '$1, $2');
    content = content.replace(/([a-zA-Z0-9\-]+:\s+(?:u[0-9]+|"[^"]*"|'[^']*'|true|false|[a-zA-Z0-9\-]+|\([^)]+\)))\r?\n\s*([a-zA-Z0-9\-]+:)/g, '$1,\n      $2');
  }

  if (content !== original) {
    fs.writeFileSync(filePath, content);
    console.log("Fixed missing commas in:", filePath);
  }
});
