export interface SettlementEnvelope {
  external_tx_reference: string;
  settlement_network_origin: 'PAPSS' | 'BRICS' | 'ISO20022' | 'ERP_ODATA';
  fiat_currency: string;
  fiat_value: number;
  sender_identity: string;
  receiver_identity: string;
  metadata?: any;
  timestamp: string;
}

export interface ERPIntent {
  intentId: string;
  erp_system: 'SAP' | 'ORACLE';
  mandate_id: string; // x402 Mandate
  source_account: string;
  target_stacks_principal: string;
  amount: string;
  currency: string;
}
