import { Parser } from 'xml2js';
import { SettlementEnvelope } from '../types/settlement.js';

const xmlParser = new Parser({ explicitArray: false, mergeAttrs: true });

export async function parsePacs008(xml: string): Promise<SettlementEnvelope> {
  const result = await xmlParser.parseStringPromise(xml);
  const document = result.Document || result;
  const creditTransfer = document.FIToFICstmrCdtTrf;
  const grpHdr = creditTransfer.GrpHdr;
  const cdtTrfTxInf = Array.isArray(creditTransfer.CdtTrfTxInf)
    ? creditTransfer.CdtTrfTxInf[0]
    : creditTransfer.CdtTrfTxInf;

  return {
    external_tx_reference: grpHdr.MsgId,
    settlement_network_origin: 'ISO20022',
    fiat_currency: cdtTrfTxInf.IntrBkSttlmAmt._currency || cdtTrfTxInf.IntrBkSttlmAmt.currency || 'USD',
    fiat_value: parseFloat(cdtTrfTxInf.IntrBkSttlmAmt._ || cdtTrfTxInf.IntrBkSttlmAmt.value || cdtTrfTxInf.IntrBkSttlmAmt),
    sender_identity: cdtTrfTxInf.Dbtr.Nm,
    receiver_identity: cdtTrfTxInf.Cdtr.Nm,
    timestamp: grpHdr.CreDtTm,
    metadata: {
      type: 'pacs.008',
      bizMsgIdr: grpHdr.MsgId
    }
  };
}

export async function parsePacs009(xml: string): Promise<SettlementEnvelope> {
  const result = await xmlParser.parseStringPromise(xml);
  const document = result.Document || result;
  const fiCreditTransfer = document.FICdtTrf;
  const grpHdr = fiCreditTransfer.GrpHdr;
  const cdtTrfTxInf = Array.isArray(fiCreditTransfer.CdtTrfTxInf)
    ? fiCreditTransfer.CdtTrfTxInf[0]
    : fiCreditTransfer.CdtTrfTxInf;

  return {
    external_tx_reference: grpHdr.MsgId,
    settlement_network_origin: 'ISO20022',
    fiat_currency: cdtTrfTxInf.IntrBkSttlmAmt._currency || cdtTrfTxInf.IntrBkSttlmAmt.currency || 'USD',
    fiat_value: parseFloat(cdtTrfTxInf.IntrBkSttlmAmt._ || cdtTrfTxInf.IntrBkSttlmAmt.value || cdtTrfTxInf.IntrBkSttlmAmt),
    sender_identity: cdtTrfTxInf.InstgAgt.FinInstnId.Nm || 'Unknown FI',
    receiver_identity: cdtTrfTxInf.InstdAgt.FinInstnId.Nm || 'Unknown FI',
    timestamp: grpHdr.CreDtTm,
    metadata: {
      type: 'pacs.009',
      bizMsgIdr: grpHdr.MsgId
    }
  };
}
