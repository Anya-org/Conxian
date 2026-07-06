# 🚀 Conxian Sandbox - Try in 5 Minutes

[![Time to First Value](https://img.shields.io/badge/TTFV-15min-green)](https://docs.conxian-labs.com)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)
[![Discord](https://img.shields.io/badge/Discord-Join-blue?logo=discord)](https://discord.gg/conxian)
[![GitHub Stars](https://img.shields.io/github/stars/Conxian/cxn-sandbox?style=social)](https://github.com/Conxian/cxn-sandbox)

> **Sovereign Bitcoin infrastructure for developers.** Send ISO 20022 payments, settle on Bitcoin, and build compliant fintech applications — without custody risk.

## ⚡ Quick Start

### Option 1: GitHub Codespaces (Recommended)

Click the button below for instant setup:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=Conxian/cxn-sandbox)

### Option 2: Gitpod

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/Conxian/cxn-sandbox)

### Option 3: Docker (One Command)

```bash
docker run -p 3000:3000 -p 3001:3001 conxian/sandbox:latest
```

### Option 4: Local Development

```bash
# Clone the sandbox
git clone https://github.com/Conxian/cxn-sandbox.git
cd cxn-sandbox

# Start the stack
docker-compose up

# Install dependencies
npm install

# Run examples
npm run example:hello-world
```

## 🎯 What You Can Build

| Example | Time | Description |
|---------|------|-------------|
| [Hello World](#1-hello-world) | 2 min | First API call |
| [ISO 20022 Payment](#2-iso-20022-payment) | 5 min | Send compliant payment |
| [Bitcoin Settlement](#3-bitcoin-settlement) | 10 min | Settle on BTC L1 |
| [Lightning Payment](#4-lightning-payment) | 3 min | Instant settlement |
| [Enclave Attestation](#5-enclave-attestation) | 10 min | TEE verification |

## 📦 What's Included

- **Conxian Gateway** - ISO 20022 ↔ Bitcoin bridge
- **Conxian Nexus** - Settlement layer
- **Conxius Enclave SDK** - TEE primitives
- **Redis + PostgreSQL** - Data layer
- **TypeScript SDK** - `@conxian/sdk`
- **20+ Examples** - Runnable code samples

## 🔥 Examples

### 1. Hello World

```typescript
import { ConxianGateway } from '@conxian/sdk';

const gateway = new ConxianGateway({ sandbox: true });

// No auth needed for sandbox!
const status = await gateway.status();
console.log(`Gateway: ${status.version}`);
console.log(`Network: ${status.network}`);
```

**Run:** `npm run example:hello-world`

### 2. ISO 20022 Payment

```typescript
import { ConxianGateway, types } from '@conxian/sdk';

const gateway = new ConxianGateway({ sandbox: true });

// Send ISO 20022 compliant payment
const payment = await gateway.payments.create({
  messageId: 'MSG-001',
  amount: '100.00',
  currency: 'USD',
  originator: {
    name: 'Acme Corp',
    lei: '5493001KJTIIGCVRYV124',
    account: 'US123456789'
  },
  beneficiary: {
    name: 'Beta GmbH',
    bic: 'COBADEFFXXX',
    account: 'DE89370400440532013000'
  },
  remittance: 'Invoice #12345'
});

console.log(`Payment created: ${payment.id}`);
console.log(`Status: ${payment.status}`);
```

**Run:** `npm run example:payment`

### 3. Bitcoin Settlement

```typescript
import { ConxianGateway } from '@conxian/sdk';

const gateway = new ConxianGateway({ sandbox: true });

// Settle on Bitcoin L1
const settlement = await gateway.settle({
  paymentId: payment.id,
  rail: 'bitcoin',
  amount: '0.001', // BTC
  beneficiaryAddress: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh'
});

console.log(`TXID: ${settlement.txid}`);
console.log(`Confirmations: ${settlement.confirmations}`);
// Wait for 1 confirmation (~10 minutes on mainnet)
```

**Run:** `npm run example:settlement`

### 4. Lightning Payment

```typescript
import { ConxianGateway } from '@conxian/sdk';

const gateway = new ConxianGateway({ sandbox: true });

// Instant settlement via Lightning
const invoice = await gateway.lightning.createInvoice({
  amount: '1000', // millisats
  description: 'Coffee payment'
});

console.log(`Invoice: ${invoice.lnbc1...}`);
console.log(`Settle instantly!`);
```

**Run:** `npm run example:lightning`

### 5. Enclave Attestation

```typescript
import { EnclaveSDK } from '@conxian/sdk';

const enclave = new EnclaveSDK({ mode: 'simulation' });

// Verify TEE attestation
const attestation = await enclave.attest({
  report: await enclave.generateReport()
});

console.log(`Quote verified: ${attestation.valid}`);
console.log(` enclave: ${attestation.tee_type}`);
console.log(` MRENCLAVE: ${attestation.mrenclave}`);
```

**Run:** `npm run example:enclave`

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DEVELOPER APPLICATION                          │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │ TypeScript SDK
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      @conxian/sdk                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │   Gateway    │  │  Lightning   │  │   Enclave    │              │
│  │   Client    │  │   Client     │  │     SDK      │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Conxian Gateway                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ ISO 20022    │  │   Compliance │  │   Settlement │              │
│  │   Parser     │  │   Engine     │  │   Adapter    │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
                    ▼             ▼             ▼
            ┌───────────┐  ┌───────────┐  ┌───────────┐
            │  Bitcoin  │  │ Lightning │  │   WBTC    │
            │    L1     │  │   Network │  │   Token   │
            └───────────┘  └───────────┘  └───────────┘
```

## 📚 Documentation

- [Quick Start Guide](https://docs.conxian-labs.com/quickstart)
- [API Reference](https://docs.conxian-labs.com/api)
- [ISO 20022 Guide](https://docs.conxian-labs.com/iso20022)
- [Bitcoin Settlement](https://docs.conxian-labs.com/settlement)
- [Security & TEE](https://docs.conxian-labs.com/security)

## 🤝 Contributing

We love contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Good first issues
- Example submission guidelines
- Code of conduct

## 📊 Metrics

| Metric | Value |
|--------|-------|
| Time to First Value | <15 min |
| Sandbox Downloads | 100+/week |
| Developer Satisfaction | ⭐ 4.8/5 |

## 🛡️ Security

- Non-custodial: We never hold your funds
- TEE-backed: Hardware security for key management
- Open source: Audit everything
- Bug bounty: [Security Policy](SECURITY.md)

## 📄 License

MIT - See [LICENSE](LICENSE)

---

<p align="center">
  <strong>Built with 💜 by Conxian Labs</strong><br>
  <a href="https://conxian-labs.com">conxian-labs.com</a> · 
  <a href="https://docs.conxian-labs.com">Docs</a> · 
  <a href="https://discord.gg/conxian">Discord</a>
</p>
