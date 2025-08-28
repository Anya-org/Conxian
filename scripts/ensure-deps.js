#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function dirExists(p) {
  try {
    return fs.statSync(p).isDirectory();
  } catch {
    return false;
  }
}

function runNpmInstall(cwd) {
  const rel = path.relative(projectRoot, cwd) || '.';
  console.log(`Installing dependencies with 'npm install' in ${rel} ...`);
  const result = spawnSync('npm', ['install'], {
    cwd,
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });
  if (result.error) {
    console.error(`Failed to run npm install in ${cwd}: ${result.error.message}`);
    process.exit(result.status || 1);
  }
  if (result.status !== 0) {
    process.exit(result.status);
  }
}

const scriptDir = __dirname; // /scripts
const projectRoot = path.resolve(scriptDir, '..');
const stacksDir = path.join(projectRoot, 'stacks');
const wrapperDir = path.join(stacksDir, 'clarinet-wrapper');

// Ensure stacks/clarinet-wrapper/node_modules
if (!dirExists(path.join(wrapperDir, 'node_modules'))) {
  console.log('Node modules not found in stacks/clarinet-wrapper directory.');
  runNpmInstall(wrapperDir);
}

// Ensure project root node_modules
if (!dirExists(path.join(projectRoot, 'node_modules'))) {
  console.log('Node modules not found in project root.');
  runNpmInstall(projectRoot);
}
