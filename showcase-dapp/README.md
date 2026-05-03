# Showcase dapp

A demo & integration showcase for Conxian UI patterns.

## Purpose

A lightweight Next.js app used to demonstrate Conxian UI patterns and end-to-end integration in local/dev environments. It serves as a playground for verifying component behavior against real protocol and gateway state.

## Status

alpha — This app is intended for demos and experimentation rather than production deployment.

## Ownership

Ownership and review requirements are defined in [`CODEOWNERS`](../CODEOWNERS).

## Audience

- UI/UX developers building Conxian-compatible interfaces.
- Protocol engineers verifying front-end integration.

## Relationship to the Conxian stack

This repository demonstrates integration between:
- [`conxian-ui`](https://github.com/Conxian/Conxian_UI): Shared component library.
- [`conxian-gateway`](https://github.com/Conxian/conxian-gateway): State aggregation and compliance.
- [`lib-conxian-core`](https://github.com/Conxian/lib-conxian-core): Shared models and conventions.

## Getting Started

First, install dependencies:

```bash
cd showcase-dapp
npm install
```

Then, run the development server:

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

## Governance and security

This module is part of the Conxian Sovereign Autonomous Business (SAB).

For general support and non-security bug reports, open a GitHub issue. For security vulnerabilities, follow the private reporting process in `SECURITY.md`.

- [**CONTRIBUTING.md**](../CONTRIBUTING.md): Guidelines for contributing to the Conxian ecosystem.
- [**SECURITY.md**](../SECURITY.md): How to report vulnerabilities and our security posture.
- [**LICENSE**](../LICENSE): GNU GPL v3.0.
