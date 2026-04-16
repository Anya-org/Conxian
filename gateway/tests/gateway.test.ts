import { describe, it, expect, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app.js';

describe('Gateway API', () => {
  it('should return health status', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('OK');
  });

  it('should parse pacs.008 XML', async () => {
    const pacs008Xml = `
      <Document>
        <FIToFICstmrCdtTrf>
          <GrpHdr>
            <MsgId>MSG001</MsgId>
            <CreDtTm>2026-03-31T12:00:00Z</CreDtTm>
          </GrpHdr>
          <CdtTrfTxInf>
            <IntrBkSttlmAmt currency="USD">1000.00</IntrBkSttlmAmt>
            <Dbtr><Nm>John Doe</Nm></Dbtr>
            <Cdtr><Nm>Jane Smith</Nm></Cdtr>
          </CdtTrfTxInf>
        </FIToFICstmrCdtTrf>
      </Document>
    `;
    const res = await request(app)
      .post('/v1/iso20022/pacs008')
      .set('Content-Type', 'application/xml')
      .send(pacs008Xml);

    expect(res.status).toBe(202);
    expect(res.body.envelope.external_tx_reference).toBe('MSG001');
    expect(res.body.envelope.fiat_value).toBe(1000);
  });

  it('should parse ERP Sync OData payload', async () => {
    const erpPayload = {
      "@odata.context": "https://sap.example.com/sap/opu/odata4/sap/api_purchaseorder/srvd_a2x/sap/purchaseorder/0001/$metadata#PurchaseOrder",
      "ID": "ERP_REF_123",
      "MandateID": "MANDATE_456",
      "SourceAccount": "ACC_DEBIT",
      "TargetStacksPrincipal": "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.cxd-token",
      "Amount": "500.50",
      "Currency": "ZAR"
    };
    const res = await request(app)
      .post('/v1/erp/sync')
      .send(erpPayload);

    expect(res.status).toBe(202);
    expect(res.body.intent.erp_system).toBe('SAP');
    expect(res.body.envelope.fiat_value).toBe(500.5);
  });
});
