// BIP-21 URI builder and parser for Bitcoin payment requests
// Reference: https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki

export interface Bip21Options {
  amount?: number;
  label?: string;
  message?: string;
}

export interface Bip21Parsed {
  address: string;
  amount?: number;
  label?: string;
  message?: string;
}

export function buildBip21Uri(address: string, opts?: Bip21Options): string {
  const params: string[] = [];
  if (opts?.amount !== undefined) params.push(`amount=${opts.amount}`);
  if (opts?.label) params.push(`label=${encodeURIComponent(opts.label)}`);
  if (opts?.message) params.push(`message=${encodeURIComponent(opts.message)}`);
  const query = params.length ? `?${params.join('&')}` : '';
  return `bitcoin:${address}${query}`;
}

export function parseBip21(uri: string): Bip21Parsed {
  const stripped = uri.startsWith('bitcoin:') ? uri.slice(8) : uri;
  const [address, queryString] = stripped.split('?');
  const result: Bip21Parsed = { address };

  if (queryString) {
    const params = new URLSearchParams(queryString);
    const amount = params.get('amount');
    if (amount) result.amount = parseFloat(amount);
    const label = params.get('label');
    if (label) result.label = label;
    const message = params.get('message');
    if (message) result.message = message;
  }

  return result;
}
