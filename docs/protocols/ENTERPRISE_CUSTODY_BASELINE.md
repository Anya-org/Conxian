# Enterprise Control & Custody Baseline (CON-460)

## 1. Key Management
- **Hardware Anchor**: Mandatory Android Keystore (StrongBox) or TEE for all key material.
- **Multi-sig**: Minimum 2-of-3 threshold for institutional treasury triggers.

## 2. Policy Controls
- **144-block Time-lock**: Required for all settlements above R100k equivalent.
- **Compliance Gating**: Real-time sanctions screening (ZKML-backed).

## 3. Auditability
- **Public Audit**: `AUDIT_MANIFEST.json` anchored to Stacks L1.
- **Private Log**: Detailed OData history maintained in SAB-controlled Supabase.

---
© 2026 Conxian-Labs (Pty) Ltd | Omphile Ndaloenhle Legacy Trust
