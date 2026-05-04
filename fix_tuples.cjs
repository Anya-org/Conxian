const fs = require('fs');
const path = require('path');

function walk(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    const dirPath = path.join(dir, f);
    if (fs.statSync(dirPath).isDirectory()) walk(dirPath, callback);
    else callback(dirPath);
  });
}

let changedFiles = 0;
walk('contracts', (filePath) => {
  if (!filePath.endsWith('.clar')) return;
  let content = fs.readFileSync(filePath, 'utf8');
  let original = content;
  
  // Replace `{ a: 1 b: 2 }` with `{ a: 1, b: 2 }`
  // We might need to run it a few times if there are multiple missing commas like `{ a: 1 b: 2 c: 3 }`
  for (let i = 0; i < 5; i++) {
    content = content.replace(/([a-zA-Z0-9\-]+:\s+(?:u[0-9]+|"[^"]*"|'[^']*'|true|false|[a-zA-Z0-9\-]+|\([^)]+\)))\s+([a-zA-Z0-9\-]+:)/g, '$1, $2');
  }

  // Also catch cross-line missing commas (though less likely or harder, let's see)
  for (let i = 0; i < 5; i++) {
    content = content.replace(/([a-zA-Z0-9\-]+:\s+(?:u[0-9]+|"[^"]*"|'[^']*'|true|false|[a-zA-Z0-9\-]+|\([^)]+\)))\r?\n\s*([a-zA-Z0-9\-]+:)/g, '$1,\n      $2');
  }

  if (content !== original) {
    fs.writeFileSync(filePath, content);
    changedFiles++;
    console.log("Fixed tuples in:", filePath);
  }
});
console.log("Total files fixed:", changedFiles);
