/**
 * @conxian/sdk - Mock SDK for Sandbox Examples
 * 
 * This is a simulation SDK that demonstrates the API without
 * requiring actual infrastructure. For production use, install
 * the real SDK from @conxian/sdk.
 */

// Simulated types
export interface GatewayStatus {
  version: string;
  network: string;
  bitcoin: {
    blockHeight: number;
    rpcUrl: string;
  };
  stacks: {
    blockHeight: number;
    apiUrl: string;
  };
  uptime: number;
  features: Array<{ name: string; enabled: boolean }>;
}

export interface PaymentRequest {
  messageId: string;
  amount: string;
  currency: string;
  originator: {
    name: string;
    lei?: string;
    account: string;
  };
  beneficiary: {
    name: string;
    bic?: string;
    account: string;
  };
  remittance?: string;
}

export interface PaymentResult {
  id: string;
  status: string;
  createdAt: string;
}

export interface SettlementResult {
  txid: string;
  confirmations: number;
  rail: string;
  amount: string;
}

export interface LightningInvoice {
  lnbc: string;
  paymentHash: string;
  amount: string;
}

export interface EnclaveAttestation {
  valid: boolean;
  tee_type: string;
  mrenclave: string;
}

// Mock Gateway Client
export class ConxianGateway {
  private sandbox: boolean;
  private baseUrl: string;

  constructor(options: { sandbox?: boolean; baseUrl?: string; network?: string }) {
    this.sandbox = options.sandbox ?? false;
    this.baseUrl = options.baseUrl ?? 'http://localhost:3000';
  }

  async status(): Promise<GatewayStatus> {
    await new Promise(resolve => setTimeout(resolve, 100));
    
    return {
      version: 'v0.4.0-alpha',
      network: this.sandbox ? 'sandbox' : 'testnet',
      bitcoin: {
        blockHeight: 2847654,
        rpcUrl: 'https://bitcoin-testnet.publicnode.com'
      },
      stacks: {
        blockHeight: 142857,
        apiUrl: 'https://stacks-node-api.testnet.stacks.co'
      },
      uptime: 86400,
      features: [
        { name: 'ISO 20022', enabled: true },
        { name: 'Bitcoin Settlement', enabled: true },
        { name: 'Lightning', enabled: true },
        { name: 'TEE Attestation', enabled: true },
        { name: 'ZKC Compliance', enabled: true }
      ]
    };
  }

  async payments = {
    async create(req: PaymentRequest): Promise<PaymentResult> {
      await new Promise(resolve => setTimeout(resolve, 200));
      
      return {
        id: `pay_${Date.now()}`,
        status: 'pending_settlement',
        createdAt: new Date().toISOString()
      };
    }
  };

  async settle(req: { paymentId: string; rail: string; amount: string; beneficiaryAddress: string }): Promise<SettlementResult> {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    return {
      txid: `tx_${Math.random().toString(36).substring(7)}`,
      confirmations: 0,
      rail: req.rail,
      amount: req.amount
    };
  }

  async lightning = {
    async createInvoice(req: { amount: string; description: string }): Promise<LightningInvoice> {
      await new Promise(resolve => setTimeout(resolve, 100));
      
      const hash = Math.random().toString(36).substring(7);
      return {
        lnbc: `lnbc${req.amount}1p${hash}...`,
        paymentHash: hash,
        amount: req.amount
      };
    }
  };
}

// Mock Enclave SDK
export class EnclaveSDK {
  private mode: string;

  constructor(options: { mode?: string }) {
    this.mode = options.mode ?? 'simulation';
  }

  async generateReport(): Promise<any> {
    await new Promise(resolve => setTimeout(resolve, 50));
    return {
      timestamp: Date.now(),
      mode: this.mode
    };
  }

  async attest(req: { report: any }): Promise<EnclaveAttestation> {
    await new Promise(resolve => setTimeout(resolve, 200));
    
    return {
      valid: true,
      tee_type: 'Intel SGX2 (simulation)',
      mrenclave: 'a1b2c3d4e5f6789012345678901234567890abcd'
    };
  }
}

export { ConxianGateway as Gateway, EnclaveSDK as Enclave };
export const types = {
  PaymentRequest,
  PaymentResult,
  SettlementResult
};
