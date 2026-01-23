import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function exists(p) {
  try {
    fs.accessSync(p, fs.constants.R_OK);
    return true;
  } catch {
    return false;
  }
}

function main() {
  const projectRoot = path.join(__dirname, '..');
  const nodeModules = path.join(projectRoot, 'node_modules');
  const pkgLock = path.join(projectRoot, 'package-lock.json');

  const requiredPaths = [
    nodeModules,
    pkgLock,
    path.join(nodeModules, '@stacks', 'clarinet-sdk'),
    path.join(nodeModules, 'vitest'),
  ];

  const missing = requiredPaths.filter((p) => !exists(p));
  if (missing.length > 0) {
    console.error('Missing required dependencies. Run npm install.');
    for (const p of missing) {
      console.error(`- ${p}`);
    }
    process.exit(1);
  }

  process.exit(0);
}

main();

export { main };
