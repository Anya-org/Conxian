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
  
  // Catch missing commas in tuple definitions like `{ id: uint to: principal }`
  // A value can be `uint`, `principal`, `bool`, or a sequence like `(string-ascii 64)`
  for (let i = 0; i < 15; i++) {
    content = content.replace(/([a-zA-Z0-9\-]+:\s+(?:[a-zA-Z0-9\-]+|\([^)]+\)))\s+([a-zA-Z0-9\-]+:)/g, '$1, $2');
    content = content.replace(/([a-zA-Z0-9\-]+:\s+(?:[a-zA-Z0-9\-]+|\([^)]+\)))\r?\n\s*([a-zA-Z0-9\-]+:)/g, '$1,\n      $2');
  }

  // Also fix `{a:b}` without spaces just in case, though clarity usually has spaces.

  if (content !== original) {
    fs.writeFileSync(filePath, content);
    console.log("Fixed type tuples in:", filePath);
  }
});
