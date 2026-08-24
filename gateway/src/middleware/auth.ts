import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';

export function verifyWebhookSignature(req: Request, res: Response, next: NextFunction) {
  const signature = req.headers['x-conxian-signature'] as string;
  const secret = process.env.WEBHOOK_SECRET || 'test-webhook-secret';

  if (!secret) {
    return res.status(500).json({ status: "ERROR", message: "Webhook security misconfigured" });
  }

  if (!signature) {
    return res.status(401).json({ status: 'UNAUTHORIZED', message: 'Missing signature' });
  }

  const hmac = crypto.createHmac('sha256', secret);
  const body = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
  const digest = hmac.update(body).digest('hex');

  if (signature !== digest) {
    return res.status(401).json({ status: 'UNAUTHORIZED', message: 'Invalid signature' });
  }

  next();
}
