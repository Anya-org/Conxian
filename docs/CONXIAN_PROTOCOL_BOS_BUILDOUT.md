# Conxian (Protocol) — BOS business buildout (CON-153)

This document defines the BOS-level business role, governance controls, and documentation separation guidance for the core `Conxian` protocol repository.

## 1) Business-unit role (Core Protocol)

Per the repo portfolio, `Conxian` is a **flagship** repo:

- **Portfolio classification**: `Flagship — Canonical protocol and on-chain assets.`
- **Business Purpose (External)**: Provide the authoritative source for Conxian smart contracts, traits, fee logic, and protocol-level invariants.
- **Business Purpose (Internal)**: Serve as the foundation for the entire Conxian ecosystem, defining the rules of engagement for all downstream services.

## 2) Operational Controls and Release-Adjacent Governance

- **Mainnet Standard**: `main` must remain mainnet-only. All testnet work belongs in `dev`.
- **Promotion Rule**: Promotion to `main` must go through `staged` and require a formal mainnet acceptance evidence pack (CON-396).
- **Ownership**: PRs require explicit sign-off from Protocol owners (`@botshelomokoka @admin-conxian-labs`).

## 3) Separating Product, Protocol, and Business Concerns

- **Protocol**: Smart contract source code, traits, and on-chain logic (Git).
- **Product**: Product-specific adapters and integration logic should live in Gateway/Wallet, not Protocol.
- **Business**: Fee split models, royalty specifics, and treasury management policies (Linear).

## 4) Public-Facing vs Internal Operating Documentation

- **Public (Git)**: Contract documentation, ABIs, security policy, and contribution guidelines.
- **Internal (Linear)**: Audit history detail, private key custody procedures (ZSE), and strategic roadmap specifics.

## 5) Prioritized Build/Repair List

**P0 (Protocol Integrity)**
- Complete the mainnet release plan standardization (CON-371).
- Add the `staged` branch to complete the promotion chain.

**P1 (Governance Maturity)**
- Standardize `README.md` (Purpose, Status, Ownership, Releases).
- Fix `CODEOWNERS` to ensure 100% review coverage.

**P2 (Documentation Alignment)**
- Migrate internal-only research to Linear.
- Update `CHANGELOG.md` to follow Keep a Changelog standard.
