# TECHNICAL SPECIFICATION: SAP/ORACLE ODATA ADAPTER (v1.0.0)

## 1. Executive Summary
The Conxian ERP Adapter acts as a high-integrity bridge between legacy Enterprise Resource Planning (ERP) systems (SAP S/4HANA, Oracle NetSuite, Microsoft Dynamics) and the Stacks/Bitcoin settlement layer. It translates institutional OData v4 accounting events into x402 Sovereign Mandates for 1-click settlement in sBTC.

## 2. Architectural Overview
- **Protocol**: OData v4 (RESTful/JSON)
- **Security**: Hardware-Attested (TEE) Sandbox
- **Settlement**: Stacks L2 (sBTC)
- **Compliance**: ISO 20022 XML Egress (pacs.008)

## 3. Endpoints
### 3.1 `GET /api/v1/erp/$metadata`
Returns the OData metadata document defining the Conxian Entity Data Model (EDM).
- **Entities**: `Settlement`, `Mandate`, `TaxReceipt`, `AuditTrail`.

### 3.2 `POST /api/v1/erp/Settle`
Primary entry point for ERP accounting triggers.
- **Input**: OData Action payload containing invoice/payroll details.
- **Process**:
    1. Parse OData payload.
    2. Map fields to ISO 20022 pacs.008.
    3. Calculate 1% (100 bps) Sovereign Tax.
    4. Generate x402 Mandate for TEE signing.
    5. Trigger sBTC transfer on Stacks.

## 4. Sovereign Tax Engine (1% Moat)
Every settlement processed via the ERP adapter automatically triggers a 100 bps fee redirection to the Conxian Treasury (`cxn-treasury-oracle`).
- **Formula**: `TotalSettlement = BaseAmount + (BaseAmount * 0.01)`
- **Transparency**: Tax receipts are linked via MMR (Merkle Mountain Range) proofs to the Stacks burn-block.

## 5. Security & Isolation
The ERP Adapter **MUST** run within a TEE (Trusted Execution Environment). No PII or raw ERP credentials ever leave the enclave. Only signed settlement receipts and anonymized metrics are exported to the public Nexus.

---
© 2026 Conxian-Labs. "Bridge the Gap."
