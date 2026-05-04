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

  // Fix newlines inside tuples
  // Look for `}` or `)` or primitive values followed by newline then a key
  content = content.replace(/(\})\s*\r?\n\s*([a-zA-Z0-9\-]+:)/g, '$1,\n      $2');
  content = content.replace(/([a-zA-Z0-9\-]+|"[^"]*"|'[^']*'|u[0-9]+|true|false|\))(\s*\r?\n\s*)([a-zA-Z0-9\-]+:)/g, (match, val, space, key) => {
    // Only add comma if it looks like we're inside a tuple or list context.
    // To be safe, if we see a value, newline, then a key, it's 99% a tuple missing a comma.
    return `${val},${space}${key}`;
  });

  if (content !== original) {
    fs.writeFileSync(filePath, content);
    console.log("Fixed multiline tuple commas in:", filePath);
  }
});
