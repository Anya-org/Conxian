import { registerPlugin } from '@capacitor/core';

export interface BreezPluginDef {
  start(options: {
    mnemonic?: string;
    vault?: string;
    pin?: string;
    apiKey: string;
    inviteCode?: string;
  }): Promise<{ id: string; balanceMsat: number }>;
  nodeInfo(): Promise<{
    id: string;
    blockHeight: number;
    maxPayableMsat: number;
    maxReceivableMsat: number;
  }>;
  invoice(options: {
    amountMsat?: number;
    description?: string;
  }): Promise<{ bolt11: string; paymentHash: string }>;
  pay(options: {
    bolt11: string;
  }): Promise<{ paymentHash: string; status: string; amountMsat: number }>;
  lnurlAuth(options: { lnurl: string }): Promise<void>;
  stop(): Promise<void>;
}

const Breez = registerPlugin<BreezPluginDef>("Breez");

export { Breez };

export async function startBreezNode(
  options: {
    mnemonic?: string;
    vault?: string;
    pin?: string;
    apiKey: string;
    inviteCode?: string;
  }
) {
  return Breez.start(options);
}

export async function getBreezInfo() {
  return Breez.nodeInfo();
}

export async function createLnInvoice(amountMsat: number, description: string) {
  return Breez.invoice({ amountMsat, description });
}

export async function payLnInvoice(bolt11: string) {
  return Breez.pay({ bolt11 });
}

export async function performLnurlAuth(lnurl: string) {
  return Breez.lnurlAuth({ lnurl });
}
