import { describe, it, expect } from 'vitest';
import { buildBip21Uri, parseBip21 } from '../services/bip21';

describe('buildBip21Uri', () => {
  it('builds basic URI', () => {
    expect(buildBip21Uri('bc1qabc')).toBe('bitcoin:bc1qabc');
  });
  it('includes amount when provided', () => {
    expect(buildBip21Uri('bc1qabc', { amount: 0.0001 })).toBe('bitcoin:bc1qabc?amount=0.0001');
  });
  it('includes label and message url-encoded', () => {
    const uri = buildBip21Uri('bc1qabc', { label: 'Conxius Wallet', message: 'Thanks!' });
    expect(uri).toBe('bitcoin:bc1qabc?label=Conxius%20Wallet&message=Thanks!');
  });
});

describe('parseBip21', () => {
  it('parses raw address', () => {
    expect(parseBip21('bc1qabc').address).toBe('bc1qabc');
  });
  it('parses bitcoin: scheme', () => {
    const parsed = parseBip21('bitcoin:bc1qabc?amount=0.01&label=Hi');
    expect(parsed.address).toBe('bc1qabc');
    expect(parsed.amount).toBe(0.01);
    expect(parsed.label).toBe('Hi');
  });
});
