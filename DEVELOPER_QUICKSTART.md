# Conxian Developer Quickstart

Welcome to the Conxian Sovereign Business Operations System (BOS). This guide will help you orchestrate the entire stack locally for development and testing.

## Prerequisites

- **Docker & Docker Compose**: For running the database and local services.
- **Node.js (v18+) & pnpm**: For the UI and smart contract tooling.
- **Rust (1.75+)**: For compiling the Gateway and Nexus middleware.
- **Clarinet**: For local Stacks Devnet testing.

## 1. Local Infrastructure Setup

First, spin up the local PostgreSQL database and Redis instance required by the middleware layers.

```bash
# Start infrastructure
docker-compose up -d db redis
```

*Note: If a root `docker-compose.yml` does not exist yet, you can run Postgres locally via standard Docker commands.*

## 2. Stacks Devnet & Smart Contracts

Navigate to the Clarity workspace to initialize the local Stacks Devnet.

```bash
cd Conxian
pnpm install

# Check contracts for errors
clarinet check

# Start the local Devnet
clarinet integrate
```

## 3. Middleware Orchestration

The Conxian stack relies on two primary Rust services: the Nexus (Glass Node) and the Gateway (Institutional Pipe).

### Conxian Nexus
Synchronizes state with Stacks L1 and serves the internal API.

```bash
cd conxian-nexus
cp .env.example .env

# Run database migrations
cargo sqlx prepare
cargo run --bin conxian-nexus
```

### Conxian Gateway
Handles institutional B2B traffic and compliance.

```bash
cd conxian-gateway
cargo run --bin gateway
```

## 4. Frontend Interfaces

Conxian provides multiple UI entry points. Start the main protocol UI:

```bash
cd conxian-ui
pnpm install
pnpm dev
```

The UI will be accessible at `http://localhost:3000`.

## Next Steps

- Review the [Architecture Documentation](Conxian/docs/ARCHITECTURE.md) to understand the contract flow.
- See the [Testing Index](Conxian/tests/TEST_INDEX.md) for running the dual-mode simulation tests.
