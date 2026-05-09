# Protocol-first narrowing inventory

## Purpose

This inventory breaks the `gateway/` subtree into concrete move categories so protocol-first narrowing can proceed in small reviewable steps.

## Classification labels

- **move**: belongs outside the protocol-first repo
- **split**: contains mixed concerns and should be separated before moving
- **keep**: only if a protocol-facing reference remains after cleanup

## Current file-level classification

### Runtime entrypoints

- `gateway/src/app.ts` -> **move**
- `gateway/src/index.ts` -> **move**

Reason:
- runtime entrypoints are service concerns, not protocol-first artifacts

### Handlers and service logic

- `gateway/src/handlers/settlement.ts` -> **move**
- `gateway/src/handlers/x402.ts` -> **move**
- `gateway/src/handlers/erp.ts` -> **move**

Reason:
- request handling and service logic should live with the canonical gateway runtime

### Middleware and parsing

- `gateway/src/middleware/auth.ts` -> **move**
- `gateway/src/parsers/iso20022.ts` -> **move**

Reason:
- middleware and parsing for service runtime do not belong in a protocol-first repository

### Runtime types and tests

- `gateway/src/types/settlement.ts` -> **split**
- `gateway/tests/gateway.test.ts` -> **move**

Reason:
- tests are runtime/service concerns
- runtime types may need to be split if any protocol-facing shared types are reusable elsewhere

### Runtime/package files

- `gateway/package.json` -> **move**
- `gateway/package-lock.json` -> **move**
- `gateway/tsconfig.json` -> **move**
- `gateway/vitest.config.ts` -> **move**

Reason:
- gateway-specific runtime package files belong with the runtime owner

### Gateway docs

- `gateway/README.md` -> **split**

Reason:
- runtime ownership should move out, but protocol-facing references may remain if needed to explain where integration runtime now lives

## Working rule

During narrowing:
- keep protocol identity and protocol-facing artifacts in this repo
- move gateway service/runtime concerns out
- split only where a small protocol-facing residue should remain

## Suggested PR sequence

### PR 1

- move runtime entrypoints and explicit service files

### PR 2

- move handlers, middleware, parsers, and tests

### PR 3

- split runtime types and rewrite gateway README as a protocol-facing reference if needed

### PR 4

- remove remaining runtime package/config overlap

## Target outcome

After narrowing:
- `Conxian` reads clearly as a protocol-first repo
- service/runtime ownership is visibly elsewhere
- protocol-facing materials remain intact and clear
