import { bech32 } from 'bech32';
import bolt11 from 'light-bolt11-decoder';
import { Buffer } from 'buffer';

export type LnurlPayParams = {
  callback: string;
  maxSendable: number;
  minSendable: number;
  metadata: string;
  commentAllowed?: number;
  // tag: 'payRequest'
};

export type LnurlWithdrawParams = {
  callback: string;
  k1: string;
  maxWithdrawable: number;
  defaultDescription: string;
  // tag: 'withdrawRequest'
};

export function isLnurl(input: string) {
  return input.startsWith('lnurl1') || input.startsWith('https://') || input.startsWith('http://');
}

export function decodeLnurl(input: string) {
  if (input.startsWith('lnurl1')) {
    const { words } = bech32.decode(input, 1024);
    const bytes = bech32.fromWords(words);
    return Buffer.from(bytes).toString('utf8');
  }
  return input;
}

export async function fetchLnurlParams(url: string): Promise<LnurlPayParams | LnurlWithdrawParams> {
  const res = await fetch(url);
  if (!res.ok) throw new Error('LNURL fetch failed');
  return await res.json();
}

export function decodeBolt11(invoice: string) {
  try {
    const decoded: any = bolt11.decode(invoice);
    const amountMsat = decoded.sections?.find((s: any) => s.name === 'amount')?.value || null;
    const payee = decoded.payeeNodeKey || decoded.payeeNode || null;
    const description = decoded.sections?.find((s: any) => s.name === 'description')?.value || null;
    return { valid: true, amountMsat, payee, description };
  } catch {
    return { valid: false };
  }
}
