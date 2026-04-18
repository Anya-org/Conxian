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

To run the full reference stack (Postgres + Redis + Nexus + Gateway):

```bash
cp docker-compose.env.example .env
docker-compose up --build
```

Nexus REST will be available at `http://localhost:3001` (container port `3000`), and Gateway at `http://localhost:3000`.

See [docs/operations/DOCKER_COMPOSE_REFERENCE_STACK.md](docs/operations/DOCKER_COMPOSE_REFERENCE_STACK.md) for details.

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

Gateway defaults to the public Bitcoin mainnet RPC endpoint `https://bitcoin-rpc.publicnode.com` whenever `BITCOIN_RPC_URL` is unset. This default is only appropriate for non-production, non-funds-bearing local development and low-traffic open-tier environments (see [environment tier definitions](docs/BOS_BUSINESS_BUILDOUT.md)).

> **Warning: public Bitcoin mainnet RPC default**
>
> - This default is only suitable for non-production, non-funds-bearing, low-traffic usage. For production, funds-bearing, or privacy-sensitive workloads, set `BITCOIN_RPC_URL` explicitly to a controlled node or vetted provider before running.
> - Traffic to this default endpoint is handled by a third-party public RPC operator and may be logged (including IP addresses and request metadata).
> - To avoid hitting mainnet in local testing, set `BITCOIN_RPC_URL` explicitly (for example to a testnet or regtest node). If you use the default endpoint, treat all traffic as live mainnet traffic: use disposable keys and small amounts you can afford to lose.
>
> See [conxian-gateway/README.md](conxian-gateway/README.md) for full configuration details.

```bash
cd conxian-gateway

# Recommended for local testing: set BITCOIN_RPC_URL explicitly (for example to a local regtest node) to avoid sending traffic to the public Bitcoin mainnet RPC default.
# Adjust host/port to match your node.
export BITCOIN_RPC_URL=http://127.0.0.1:18443

# If your node requires RPC auth:
# export BITCOIN_RPC_USER=your_rpc_user
# export BITCOIN_RPC_PASS=your_rpc_pass

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
