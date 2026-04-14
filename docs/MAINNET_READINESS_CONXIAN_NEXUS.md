# Mainnet Readiness Checklist — Conxian Nexus (CON-396)

## Status: READY FOR MAINNET (v0.4.0)

This checklist tracks the mainnet readiness for the `conxian-nexus` repository (Glass Node).

### 1) Production Sanitization
- [x] **CON-384**: Testnet principals (ST...) removed from source.
- [x] **Wallet Alignment**: Bootstrap wallet (`SPSZXAKV7DWTDZN2601WR31BM51BD3YTQWE97VRM`) integrated for identity.
- [x] **Contamination Guard**: `scripts/check_production_boundary.sh` integrated and passing.

### 2) Core Implementation
- [x] **FSOC Sequencer**: First-Seen-On-Chain logic verified for MEV mitigation.
- [x] **MMR Persistence**: Persistent MMR peaks and nodes in PostgreSQL verified.
- [x] **Reorg Handling**: Microblock reorg detection and automated rollback implemented.

### 3) Institutional Ingress
- [x] **CON-166**: Global settlement ingress (ISO 20022/PAPSS/BRICS) wired.
- [x] **TEE Verification**: Mandatory TEE attestation for external triggers enforced.
- [x] **Time-Locks**: 144-block time-lock for institutional state proposals implemented.

### 4) Release & Hygiene
- [x] **README**: Standardized with Purpose, Status, Ownership, and Releases.
- [x] **Changelog**: Initial mainnet-ready CHANGELOG.md created.
- [x] **BOS Boundary**: Strict mainnet-only production boundary enforced.

---
© 2026 Conxian-Labs (Pty) Ltd.
