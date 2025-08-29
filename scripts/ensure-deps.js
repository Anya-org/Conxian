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
  const npmArgs = ['ci', '--no-audit', '--no-fund'];
  const timeoutMs = Number(process.env.NPM_INSTALL_TIMEOUT_MS || 300000); // default 5 minutes
  console.log(`Installing dependencies with 'npm ${npmArgs.join(' ')}' in ${rel} (timeout ${timeoutMs}ms) ...`);
  const result = spawnSync('npm', npmArgs, {
    cwd,
    stdio: 'inherit',
    shell: process.platform === 'win32',
    timeout: timeoutMs,
    env: Object.assign({}, process.env, {
      CI: 'true',
      npm_config_audit: 'false',
      npm_config_fund: 'false',
      npm_config_progress: 'false',
      npm_config_loglevel: 'error',
    }),
  });
  if (result.error) {
    const code = result.error.code || 'UNKNOWN';
    console.error(`Failed to run npm in ${cwd}: ${result.error.message} (code=${code})`);
    if (code === 'ETIMEDOUT') {
      console.error('npm operation timed out. You can adjust timeout via NPM_INSTALL_TIMEOUT_MS.');
    }
    process.exit(typeof result.status === 'number' ? result.status : 1);
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
