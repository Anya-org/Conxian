const fs = require('fs');

let content = fs.readFileSync('Clarinet.toml', 'utf8');

// Ensure all contracts have clarity-version = 4
let lines = content.split('\n');
let newLines = [];
let inContract = false;
let hasClarityVersion = false;

for (let line of lines) {
  if (line.startsWith('[contracts.')) {
    if (inContract && !hasClarityVersion) {
      newLines.splice(newLines.length - 1, 0, 'clarity-version = 4');
    }
    inContract = true;
    hasClarityVersion = false;
    newLines.push(line);
  } else if (line.startsWith('[')) {
    if (inContract && !hasClarityVersion) {
      newLines.splice(newLines.length - 1, 0, 'clarity-version = 4');
    }
    inContract = false;
    newLines.push(line);
  } else {
    if (line.trim().startsWith('clarity-version')) {
      hasClarityVersion = true;
      newLines.push('clarity-version = 4');
    } else {
      newLines.push(line);
    }
  }
}

if (inContract && !hasClarityVersion) {
  newLines.push('clarity-version = 4');
}

// Add epoch = "2.05" or "3.0" globally? The instructions say:
// `clarity-version = 4` only (v1–v3 banned).
// `epoch = "latest"` mandatory in every Clarinet.toml entry.

// Let's add `epoch = "latest"` to every contract block too.
content = newLines.join('\n');
lines = content.split('\n');
newLines = [];
inContract = false;
let hasEpoch = false;

for (let line of lines) {
  if (line.startsWith('[contracts.')) {
    if (inContract && !hasEpoch) {
      newLines.splice(newLines.length - 1, 0, 'epoch = "latest"');
    }
    inContract = true;
    hasEpoch = false;
    newLines.push(line);
  } else if (line.startsWith('[')) {
    if (inContract && !hasEpoch) {
      newLines.splice(newLines.length - 1, 0, 'epoch = "latest"');
    }
    inContract = false;
    newLines.push(line);
  } else {
    if (line.trim().startsWith('epoch')) {
      hasEpoch = true;
      newLines.push('epoch = "latest"');
    } else {
      newLines.push(line);
    }
  }
}

if (inContract && !hasEpoch) {
  newLines.push('epoch = "latest"');
}

fs.writeFileSync('Clarinet.toml', newLines.join('\n'));
console.log("Updated Clarinet.toml with clarity-version = 4 and epoch = latest");
