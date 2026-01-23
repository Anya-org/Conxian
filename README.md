# Conxius Wallet

Mobile-first sovereign wallet with a hardened local enclave model.

## What This Repo Contains

- React + Vite UI bundled with Tailwind CSS (offline-safe; no CDN dependency)
- Android app via Capacitor
- **Native Enclave Core**
  - Encrypted wallet state persisted on-device (Android Keystore)
  - Memory-only seed handling for zero-leak operations
  - Native key derivation for Bitcoin, Stacks, Liquid, Rootstock, and Nostr
  - Embedded Greenlight (Breez SDK) node with direct enclave access

## Wallet Lifecycle

- If an encrypted wallet exists on-device, the app resumes it by showing the lock screen.
- If no wallet exists, the app starts onboarding to create/import a new wallet.
- From the lock screen, you can wipe the vault and create a new wallet (destructive).

## Development

**Prerequisites**

- Node.js (v18+)
- Android Studio + Android SDK (for device installs)
- Java 17+

**Install**

- `npm install`

**Run web (Mock Enclave)**

- `npm run dev`

**Build web**

- `npm run build`

## Android (Production Environment)

**Build + install debug**

- `cd android && ./gradlew :app:installDebug`

**Sync web assets into Android**

- `npx cap sync android`

**Run Unit Tests**

- `cd android && ./gradlew :app:testDebugUnitTest`

## Key Architecture

- **SecureEnclavePlugin**: Native Java bridge handling all sensitive key operations.
- **BreezPlugin**: Lightning Network node running in a foreground service, connected natively to the Enclave.
- **IdentityService**: Manages D.iD and Nostr identity using 0-gas enclave derivation.

## Roadmap

- See [ROADMAP.md](ROADMAP.md)

## Project Docs

- [WHITEPAPER.md](WHITEPAPER.md)
- [PRD.md](PRD.md) - **Source of Truth**
- [CHANGELOG.md](CHANGELOG.md)
