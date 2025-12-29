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
  const required = [
    path.join(projectRoot, 'README.md'),
    path.join(projectRoot, 'ROADMAP.md'),
    path.join(projectRoot, 'documentation'),
  ];

  const missing = required.filter((p) => !exists(p));
  if (missing.length > 0) {
    console.error('Documentation validation failed. Missing required docs/dirs:');
    for (const p of missing) {
      console.error(`- ${p}`);
    }
    process.exit(1);
  }

  process.exit(0);
}

main();

export { main };
