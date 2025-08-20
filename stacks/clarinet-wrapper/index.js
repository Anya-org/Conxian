#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const candidates = [
  path.resolve(__dirname, '..', '..', 'bin', 'clarinet'), // stacks/bin/clarinet when installed into node_modules
  path.resolve(process.cwd(), '..', 'bin', 'clarinet'),   // running from stacks/
  path.resolve(process.cwd(), 'bin', 'clarinet'),         // running from repo root
];

const binPath = candidates.find(p => {
  try {
    const st = fs.statSync(p);
    return st.isFile() && (st.mode & 0o111);
  } catch (_) { return false; }
});

if (!binPath) {
  console.error('clarinet wrapper: unable to locate bin/clarinet binary.');
  console.error('Searched:');
  for (const p of candidates) console.error(' - ' + p);
  process.exit(127);
}

const child = spawn(binPath, process.argv.slice(2), { stdio: 'inherit' });
child.on('exit', code => process.exit(code));
