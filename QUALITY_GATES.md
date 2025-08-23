# Quality Gates and Enhanced Post-Deployment Verification

This repository provides an enhanced verification pipeline that enforces functional, security, performance, and production-readiness gates for the AutoVault stack.

## Commands

- Run core checks (lint/type + unit tests):
  - npm run check
  - npm test

- Run basic post-deployment checks (legacy):
  - npm run verify-post

- Run enhanced post-deployment verification and generate a detailed report:
  - npm run verify:enhanced

- Run the full quality-gates pipeline (check + tests + enhanced verify):
  - npm run quality-gates

All root-level commands delegate into the `stacks` workspace and use ts-node + Clarinet.

## Output

- On success, the enhanced verifier writes `POST_DEPLOYMENT_VERIFICATION_REPORT.md` in the repo root, summarizing:
  - Deployed contracts and addresses
  - Functional results for: vault, batch, caching, load distribution, oracle aggregator, dex factory
  - Security controls (admin/timelock/pausable)
  - Performance targets evaluation
  - Production readiness score and blockers

- Exit codes:
  - 0: All gates passed
  - 1: Functional or security gate failed
  - 2: Performance or readiness thresholds not met

## Environment

Before running, ensure:
- Contracts are deployed (testnet or clarinet devnet)
- `scripts/deploy-enhanced-contracts.sh` DRY_RUN=false for live deploys
- `stacks/package.json` devDependencies installed (Clarinet, ts-node, vitest)

Optional env vars consumed by the verifier:
- NETWORK (default: testnet)
- DEPLOYMENT_REGISTRY (path to JSON with contract addresses)
- TPS_TARGET (override performance target)

