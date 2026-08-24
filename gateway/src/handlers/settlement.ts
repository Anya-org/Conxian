import { Request, Response } from 'express';
import { parsePacs008, parsePacs009 } from '../parsers/iso20022.js';
import { SettlementEnvelope } from '../types/settlement.js';

// In-memory registry for audited settlement envelopes in gateway runtime
const settlementRegistry: SettlementEnvelope[] = [];

export const getSettlementRegistry = (): readonly SettlementEnvelope[] => settlementRegistry;

export const handlePacs008 = async (req: Request, res: Response) => {
  try {
    const envelope = await parsePacs008(req.body);
    settlementRegistry.push(envelope);
    res.status(202).json({ status: 'ACCEPTED', envelope });
  } catch (error: any) {
    res.status(400).json({ status: 'ERROR', message: error.message });
  }
};

export const handlePacs009 = async (req: Request, res: Response) => {
  try {
    const envelope = await parsePacs009(req.body);
    settlementRegistry.push(envelope);
    res.status(202).json({ status: 'ACCEPTED', envelope });
  } catch (error: any) {
    res.status(400).json({ status: 'ERROR', message: error.message });
  }
};

export const handlePAPSSCallback = async (req: Request, res: Response) => {
  const payload = req.body;
  const envelope: SettlementEnvelope = {
    external_tx_reference: payload.tx_ref,
    settlement_network_origin: 'PAPSS',
    fiat_currency: payload.currency,
    fiat_value: payload.amount,
    sender_identity: payload.sender,
    receiver_identity: payload.receiver,
    timestamp: new Date().toISOString(),
    metadata: payload
  };
  settlementRegistry.push(envelope);
  res.status(202).json({ status: 'ACCEPTED', envelope });
};

export const handleBRICSCallback = async (req: Request, res: Response) => {
  const payload = req.body;
  const envelope: SettlementEnvelope = {
    external_tx_reference: payload.settlement_id,
    settlement_network_origin: 'BRICS',
    fiat_currency: payload.ccy,
    fiat_value: payload.val,
    sender_identity: payload.origin_fi,
    receiver_identity: payload.target_fi,
    timestamp: new Date().toISOString(),
    metadata: payload
  };
  settlementRegistry.push(envelope);
  res.status(202).json({ status: 'ACCEPTED', envelope });
};
