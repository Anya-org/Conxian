// Lightning Network utilities — LNURL and BOLT11 decoding
// Stub implementations for the Conxius wallet service layer

export function isLnurl(input: string): boolean {
  try {
    const url = new URL(input);
    return url.protocol === 'https:' || url.protocol === 'http:';
  } catch {
    return input.toLowerCase().startsWith('lnurl1');
  }
}

export function decodeLnurl(lnurl: string): string {
  if (lnurl.toLowerCase().startsWith('lnurl1')) {
    try {
      const { bech32 } = require('bech32');
      const decoded = bech32.decode(lnurl, 1500);
      const bytes = bech32.fromWords(decoded.words);
      return new TextDecoder().decode(new Uint8Array(bytes));
    } catch {
      return lnurl;
    }
  }
  try {
    new URL(lnurl);
    return lnurl;
  } catch {
    return `https://${lnurl}`;
  }
}

export function decodeBolt11(invoice: string): { valid: boolean; amount?: number; description?: string } {
  if (!invoice || !invoice.toLowerCase().startsWith('lnbc')) {
    return { valid: false };
  }
  try {
    const parts = invoice.slice(2).split('1');
    if (parts.length < 2) return { valid: false };

    const hrp = parts[0];
    const amountMatch = hrp.match(/^(\d+)([pnum])?$/);
    let amount: number | undefined;
    if (amountMatch?.[2]) {
      const multiplier: Record<string, number> = { p: 1e-12, n: 1e-9, u: 1e-6, m: 1e-3 };
      amount = parseInt(amountMatch[1]) * (multiplier[amountMatch[2]] || 1);
    }

    return { valid: true, amount };
  } catch {
    return { valid: false };
  }
}
