# Specifications: Enterprise Sovereignty Requirements

(Note: Technical specifications are formally defined in `specs/enterprise-sovereignty/spec.md` as per OpenSpec standards).

## 1. Business Logic Specs
- **SPEC-CX-001**: **Zero Secret Egress**. Private keys MUST never leave the StrongBox TEE.
- **SPEC-CX-002**: **BIP-322 Verification**. All mobile logins MUST be verified via BIP-322 on-device.
- **SPEC-CSF-001**: **CXIP-013 Revenue Distribution**. The 6-way split MUST be calculated in Clarity based on GCR.
- **SPEC-CSF-002**: **Principal Injection**. All module-to-module calls MUST be traversable via the core registry.
- **SPEC-FU-001**: **Deterministic Sync**. ERP webhooks MUST be queued with a minimum 5-retry exponential backoff.
- **SPEC-FU-002**: **ISO 20022 Compliance**. All institutional egress MUST match ISO 20022 XML standards.
- **SPEC-NX-001**: **Nexus-First State**. The Nexus MUST be the authoritative source for block height for the Gateway.
- **SPEC-NX-002**: **Glass Node Telemetry**. All risk metrics MUST be exported via Prometheus on port 3000 (internal).

## 2. Asset Specs
- **SPEC-AS-001**: **Reserve Attestation**. Every ART mint MUST have a TEE-attested 1:1 reserve proof.
- **SPEC-AS-002**: **SIP-010 Alignment**. All fungible assets MUST implement the SIP-010 trait.
- **SPEC-AS-003**: **Bridge Monitoring**. The sBTC bridge status MUST be updated by Nexus every 10 minutes.

## 3. Submodule & Module Requirements
- **SPEC-MD-001**: **Standard Header**. All Clarity files MUST include a version header (Clarity 4 / March 2026).
- **SPEC-MD-002**: **Error Mapping**. All module-level errors MUST map to the `contracts/errors/` module.

## 4. Remediation Standards
- **SPEC-RM-001**: **Documentation Alignment**. Module READMEs MUST be updated to reflect current function signatures.
- **SPEC-RM-002**: **Truth Baseline**. The root PRD MUST be the definitive source for business unit mapping.
