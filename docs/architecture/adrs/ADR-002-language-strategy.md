# ADR-002: TypeScript for application surfaces, Rust for trusted runtime

## Status
Accepted

## Context
The Conxian ecosystem spans internal control workflows, public/operator-facing applications, trusted runtime services, and on-chain logic.

## Decision
- Use TypeScript for applications, shared schemas, and client SDKs.
- Use Rust for trusted runtime and integration-heavy services.
- Use Clarity only for on-chain logic.
- Use Python primarily for tooling and automation.

## Consequences
- Internal and product UI can share a coherent application language.
- Sensitive runtime logic remains in a language suited to reliability and performance.
- On-chain logic remains explicitly separated from application concerns.
