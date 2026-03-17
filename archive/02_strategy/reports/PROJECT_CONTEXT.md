# Conxius Wallet: Project Context

**Last Updated:** 2026-02-18
**Context:** Phase 5 Final Alignment & Ecosystem Expansion Complete

---

## 🛡️ The Citadel (Mobile Core)

Conxius is an Android-first, TEE-backed sovereign interface for the Full Bitcoin Ecosystem (BTC, L2, Sidechains, RGB, Ark, BitVM). It handles all private key operations within the "Conclave."

## 🚀 The Gateway (B2B Expansion)

The **Conxian Gateway** is the institutional expansion layer for Conxius. It is a standalone web app that provides:

- **Corporate Treasury**: Advanced DEX and liquidity management.
- **B2B Shielded Payments**: Privacy-focused enterprise transactions.
- **Institutional Launchpad**: Token issuance for businesses.

---

## 🔍 Context Refresh & Alignment (2026-02-18)

A comprehensive review of the codebase, documentation, and operational status was conducted to ensure full alignment with the Roadmap and PRD.

- **Status**: **Fully Aligned**. Codebase reflects the "Production Ready" state described in documentation.
- **Android Build**: Fixed and verified on physical hardware (Samsung A10).
- **Core Services**: `signer.ts`, `protocol.ts`, and layer-specific services (`ark.ts`, `rgb.ts`, etc.) are implemented and integrated.
- **Verification**: `DEVICE_READINESS_REPORT.md` and `IMPLEMENTATION_REGISTRY.md` are up to date.

---

## 🔧 Phase 5 Final Alignment (Completed 2026-02-18)

The final alignment for the Phase 5 Bitcoin Ecosystem expansion was executed, bringing all documentation and code into a synchronized state:

- **Protocol Parity**:
  - Verified and documented PRODUCTION status for 14+ Bitcoin layers (Alpen, Zulu, Bison, Hemi, Nubit, Lorenzo, Citrea, Babylon, Merlin, Bitlayer, etc.).
  - Hardened fetchers in `protocol.ts` with API failure resilience (empty fallback).
- **Automated Verification**:
  - Initialized **Maestro On-Device Testing** protocol with `run_maestro.bat` and `MAESTRO_SETUP.md`.
  - Verified **BitVM / ZK Verifier** cryptographic integrity on-device.
- **Documentation & Maintenance**:
  - Harmonized system versioning to **v1.5.0** across `package.json`, `metadata.json`, and the Implementation Registry.
  - Updated `CHANGELOG.md` with all recent institutional-grade enhancements.

### 📱 Android Build & Device Verification (2026-02-18)

- **Build Environment**: Fixed `JAVA_HOME` compatibility (Downgraded Capacitor plugins to Java 17).
- **Native Layer**:
  - Reverted `MainActivity` to Java to resolve `ClassNotFoundException`.
  - Configured `build.gradle` for correct dependency resolution (Biometrics, Capacitor).
- **Device Status**: Verified installation and startup on **Samsung Galaxy A10 (SM-A105F)**.
- **Testing**: Confirmed successful Maestro flow execution on physical hardware.

---

## 🧪 Technical State

- **Frontend**: React 19 + Vite 7 + Tailwind 4.
- **Native**: SecureEnclavePlugin (TEE), BreezPlugin (Lightning).
- **Hardening**: Zero-Leak memory enforcement (.fill(0)) in all cryptographic modules.
- **Protocols**: Full support for L1, Lightning, Stacks, Liquid, RSK, BOB, RGB, Ark, BitVM, State Chains, Maven, and all Phase 5 L2s.

---

*Precision is non-negotiable. Sovereignty is the goal.*
