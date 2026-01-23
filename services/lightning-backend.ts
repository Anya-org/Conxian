import { LnBackendConfig } from '../types';

export interface LightningBackend {
  configured: boolean;
  createInvoice(amountSats: number, memo?: string): Promise<{ invoice: string }>;
  payInvoice(invoice: string): Promise<{ preimage?: string }>;
  lnurlPay(callback: string, amountMsat: number, comment?: string): Promise<{ status: string }>;
  lnurlWithdraw(callback: string, k1: string, invoice: string): Promise<{ status: string }>;
}

class NoneBackend implements LightningBackend {
  configured = false;
  async createInvoice(_amountSats: number, _memo?: string): Promise<{ invoice: string }> {
    throw new Error('Lightning backend not configured');
  }
  async payInvoice(_invoice: string): Promise<{ preimage?: string }> {
    throw new Error('Lightning backend not configured');
  }
  async lnurlPay(_callback: string, _amountMsat: number, _comment?: string): Promise<{ status: string }> {
    throw new Error('Lightning backend not configured');
  }
  async lnurlWithdraw(_callback: string, _k1: string, _invoice: string): Promise<{ status: string }> {
    throw new Error('Lightning backend not configured');
  }
}

class LndBackend implements LightningBackend {
  configured = true;
  baseUrl: string;
  macaroon: string;
  constructor(host: string, macaroon: string) {
    const trimmed = host.trim();
    this.baseUrl = trimmed.includes('://') ? trimmed : `https://${trimmed}`;
    this.macaroon = macaroon;
  }
  async createInvoice(amountSats: number, memo?: string) {
    const url = new URL('/v1/invoices', this.baseUrl).toString();
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Grpc-Metadata-macaroon': this.macaroon
      },
      body: JSON.stringify({ value: amountSats, memo: memo || 'Conxius' })
    });
    if (!res.ok) throw new Error('LND invoice request failed');
    const data = await res.json();
    return { invoice: data.payment_request };
  }
  async payInvoice(invoice: string) {
    const url = new URL('/v1/channels/transactions', this.baseUrl).toString();
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Grpc-Metadata-macaroon': this.macaroon
      },
      body: JSON.stringify({ payment_request: invoice })
    });
    if (!res.ok) throw new Error('LND payment request failed');
    const data = await res.json();
    return { preimage: data.payment_preimage };
  }
  async lnurlPay(callback: string, amountMsat: number, comment?: string) {
    const cb = new URL(callback);
    cb.searchParams.set('amount', `${amountMsat}`);
    if (comment) cb.searchParams.set('comment', comment);
    const res = await fetch(cb.toString());
    const data = await res.json();
    if (!data.pr) throw new Error('LNURL callback missing invoice');
    await this.payInvoice(data.pr);
    return { status: 'paid' };
  }
  async lnurlWithdraw(callback: string, k1: string, invoice: string) {
    const url = new URL(callback);
    url.searchParams.set('k1', k1);
    url.searchParams.set('pr', invoice);
    const res = await fetch(url.toString());
    const data = await res.json();
    return { status: data.status || 'ok' };
  }
}
import { createLnInvoice, payLnInvoice, startBreezNode } from "./breez";

class BreezBackend implements LightningBackend {
  configured = true;

  async createInvoice(amountSats: number, memo?: string) {
    // Breez expects msats
    const { bolt11 } = await createLnInvoice(
      amountSats * 1000,
      memo || "Conxius",
    );
    return { invoice: bolt11 };
  }

  async payInvoice(invoice: string) {
    const res = await payLnInvoice(invoice);
    return { preimage: res.paymentHash }; // Note: Breez might strictly return hash or preimage, we mapped hash in plugin. Preimage is usually hidden or ID.
  }

  async lnurlPay(callback: string, amountMsat: number, comment?: string) {
    // Breez SDK handles LNURL parsing and payment internally usually, but here we can reimplement
    // or use basic manual flow if Breez SDK exposes raw pay method.
    // For now, standard manual flow:
    const cb = new URL(callback);
    cb.searchParams.set("amount", `${amountMsat}`);
    if (comment) cb.searchParams.set("comment", comment);
    const res = await fetch(cb.toString());
    const data = await res.json();
    if (!data.pr) throw new Error("LNURL callback missing invoice");
    await this.payInvoice(data.pr);
    return { status: "paid" };
  }

  async lnurlWithdraw(callback: string, k1: string, invoice: string) {
    const url = new URL(callback);
    url.searchParams.set("k1", k1);
    url.searchParams.set("pr", invoice);
    const res = await fetch(url.toString());
    const data = await res.json();
    return { status: data.status || "ok" };
  }
}

export function getLightningBackend(cfg?: LnBackendConfig): LightningBackend {
  if (!cfg || cfg.type === 'None') return new NoneBackend();
  if (cfg.type === 'LND' && cfg.endpoint && cfg.apiKey) {
    return new LndBackend(cfg.endpoint, cfg.apiKey);
  }
  if (cfg.type === "Greenlight" || cfg.type === "Breez") {
    return new BreezBackend();
  }
  return new NoneBackend();
}
