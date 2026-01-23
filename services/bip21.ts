export function buildBip21Uri(address: string, params?: { amount?: number; label?: string; message?: string }) {
  const scheme = 'bitcoin:';
  if (!address) return '';
  const query: string[] = [];
  if (params?.amount && params.amount > 0) query.push(`amount=${params.amount}`);
  if (params?.label) query.push(`label=${encodeURIComponent(params.label)}`);
  if (params?.message) query.push(`message=${encodeURIComponent(params.message)}`);
  return query.length ? `${scheme}${address}?${query.join('&')}` : `${scheme}${address}`;
}

export function parseBip21(input: string): {
  address: string;
  amount?: number;
  label?: string;
  message?: string;
  options?: Record<string, string>;
} {
  const trimmed = (input || "").trim();
  if (!trimmed) return { address: "" };
  const noScheme = trimmed.toLowerCase().startsWith("bitcoin:")
    ? trimmed.slice("bitcoin:".length)
    : trimmed;
  const [addressPart, queryPart] = noScheme.split("?", 2);
  const address = addressPart.trim();
  const result: {
    address: string;
    amount?: number;
    label?: string;
    message?: string;
    options?: Record<string, string>;
  } = { address };
  if (!queryPart) return result;

  const params = new URLSearchParams(queryPart);
  const options: Record<string, string> = {};

  params.forEach((val, key) => {
    if (key === "amount") {
      const amount = Number(val);
      if (!Number.isNaN(amount) && Number.isFinite(amount) && amount > 0)
        result.amount = amount;
    } else if (key === "label") {
      result.label = val;
    } else if (key === "message") {
      result.message = val;
    } else {
      options[key] = val;
    }
  });

  if (Object.keys(options).length > 0) {
    result.options = options;
  }

  return result;
}
