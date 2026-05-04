const fs = require('fs');
const path = require('path');

function walk(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    const dirPath = path.join(dir, f);
    if (fs.statSync(dirPath).isDirectory()) walk(dirPath, callback);
    else callback(dirPath);
  });
}

let count = 0;
walk('contracts', (filePath) => {
  if (!filePath.endsWith('.clar')) return;
  let content = fs.readFileSync(filePath, 'utf8');
  let original = content;
  
  // Replace block-height with stacks-block-height
  // Avoid replacing stacks-block-height or burn-block-height
  content = content.replace(/(?<!stacks-|burn-)block-height/g, 'stacks-block-height');

  if (content !== original) {
    fs.writeFileSync(filePath, content);
    count++;
    console.log("Fixed block-height in:", filePath);
  }
});
console.log("Total files updated:", count);
