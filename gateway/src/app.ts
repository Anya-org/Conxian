import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { handlePacs008, handlePacs009, handlePAPSSCallback, handleBRICSCallback } from './handlers/settlement.js';
import { handleERPSync } from './handlers/erp.js';
import { verifyWebhookSignature } from './middleware/auth.js';

dotenv.config();

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.text({ type: 'application/xml' }));

app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// ISO 20022 Ingress (Protected by Webhook Signature)
app.post('/v1/iso20022/pacs008', verifyWebhookSignature, handlePacs008);
app.post('/v1/iso20022/pacs009', verifyWebhookSignature, handlePacs009);

// Settlement Callbacks
app.post('/v1/settlement/papss/callback', verifyWebhookSignature, handlePAPSSCallback);
app.post('/v1/settlement/brics/callback', verifyWebhookSignature, handleBRICSCallback);

// ERP Ingress (OData v4)
app.post('/v1/erp/sync', verifyWebhookSignature, handleERPSync);

export default app;
