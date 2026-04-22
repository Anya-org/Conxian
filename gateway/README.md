# Conxian Intent Solver Gateway

## Overview
The Conxian Gateway is an off-chain bridging service that translates institutional intents (ISO 20022, OData v4) into on-chain mandates for the Conxian Protocol.

## Features
- **ERP Integration**: Production-grade OData v4 parser for SAP and Oracle (CON-63).
- **ISO 20022**: Support for pacs.008 and pacs.009 credit transfers.
- **x402 Protocol**: Native mapping of HTTP 402 Payment Required mandates.
- **Security**: HMAC SHA-256 webhook verification.

## API Specification
- `POST /v1/erp/sync`: Process ERP settlement intents.
- `POST /v1/industrial/payment`: Handle x402 payment requirements.
- `POST /v1/iso20022/pacs008`: Ingress for customer credit transfers.

## Status
- **Standard**: Zero Secret Egress (ZSE) Compliant.
- **Maturity**: Production Ready (April 2026).
