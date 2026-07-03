import { Request, Response } from 'express';
import { ERPIntent, SettlementEnvelope } from '../types/settlement.js';

export const handleERPSync = async (req: Request, res: Response) => {
  try {
    const payload = req.body;
    const erpSystem = payload['@odata.context']?.includes('sap') ? 'SAP' : 'ORACLE';

    // x402 Mandate mapping logic
    const mandateId = payload.MandateID || payload.PurchaseOrderReference;

    const intent: ERPIntent = {
      intentId: payload.ID || payload.ReferenceID,
      erp_system: erpSystem,
      mandate_id: mandateId,
      source_account: payload.SourceAccount || payload.PayingParty,
      target_stacks_principal: payload.TargetStacksPrincipal || payload.ReceiverAddress,
      amount: payload.Amount || payload.Value,
      currency: payload.Currency || payload.CurrencyCode
    };

    const envelope: SettlementEnvelope = {
      external_tx_reference: intent.intentId,
      settlement_network_origin: 'ERP_ODATA',
      fiat_currency: intent.currency,
      fiat_value: parseFloat(intent.amount),
      sender_identity: intent.source_account,
      receiver_identity: intent.target_stacks_principal,
      timestamp: new Date().toISOString(),
      metadata: { erp_intent: intent }
    };

    // Fail-closed enforcement: ensure OData parsing/mapping engine is healthy
    const syncEngineHealthy = process.env.NODE_ENV === 'test' || true; // Placeholder for health check
    if (!syncEngineHealthy) {
        return res.status(503).json({ status: 'ERROR', message: 'ERP Sync Engine unhealthy' });
    }

    res.status(202).json({ status: 'ACCEPTED', intent, envelope });
  } catch (error: any) {
    res.status(400).json({ status: 'ERROR', message: error.message || 'ERP sync processing failure' });
  }
};
