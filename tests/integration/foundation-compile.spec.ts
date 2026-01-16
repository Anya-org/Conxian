import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';

// This test verifies the foundation layer is present and correctly wired.
// It does not execute Clarinet; it validates files and basic content to keep the loop fast.
describe('Foundation layer (traits + encoding)', () => {
  const repoRoot = process.cwd();
  const manifest = path.join(repoRoot, 'Clarinet.toml');

  console.log('Repo Root:', repoRoot);
  console.log('Manifest Path:', manifest);

  it('has a foundation manifest with required entries', () => {
    expect(fs.existsSync(manifest)).toBe(true);
    const content = fs.readFileSync(manifest, 'utf8');
    // Check for existence of trait definitions in the manifest
    expect(content).toContain("contracts/traits/defi-primitives.clar");
    expect(content).toContain('contracts/utils/encoding.clar');
  });

  it("contains centralized traits folder and encoding contracts", () => {
    const allTraits = path.join(
      repoRoot,
      "contracts",
      "traits",
      "defi-primitives.clar"
    );
    const encoding = path.join(repoRoot, "contracts", "utils", "encoding.clar");

    console.log('Traits Path:', allTraits);
    console.log('Encoding Path:', encoding);

    expect(fs.existsSync(allTraits)).toBe(true);
    expect(fs.existsSync(encoding)).toBe(true);

    const traitsSrc = fs.readFileSync(allTraits, "utf8");
    expect(traitsSrc).toMatch(/\(define-trait\s+[a-zA-Z0-9-]+/);

    const encSrc = fs.readFileSync(encoding, "utf8");
    // encoding.clar has hash-data, not hash-uint
    expect(encSrc).toMatch(/define-read-only\s*\(hash-data/);
  });
});
