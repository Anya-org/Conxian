import { describe, it, expect } from 'vitest';
import { isLnurl, decodeLnurl, decodeBolt11 } from '../services/lightning';

describe('lightning decoding', () => {
  it('detects http lnurl', () => {
    expect(isLnurl('https://service.com/lnurl')).toBe(true);
  });
  it('decodes bech32 lnurl', () => {
    // lnurl spec requires a valid encoded url; quick check: encoding and decoding round-trip
    const bech32 = require('bech32').bech32;
    const words = bech32.toWords(Buffer.from('https://example.com/lnurl', 'utf8'));
    const lnurl = bech32.encode('lnurl', words);
    expect(decodeLnurl(lnurl)).toContain('https://example.com/lnurl');
  });
  it('rejects invalid bolt11', () => {
    const info = decodeBolt11('lnbcINVALID');
    expect(info.valid).toBe(false);
  });
});

