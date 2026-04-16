# Docker Compose reference stack

This repository includes a root `docker-compose.yml` that serves as a baseline operator / internal testing deployment for the Conxian runtime.

It brings up:

- Postgres (`db`)
- Redis (`redis`)
- Conxian Nexus (`nexus`)
- Conxian Gateway (`gateway`)

## Prerequisites

1. Docker + Docker Compose
2. Clone with submodules (or initialize them after cloning):

```bash
git submodule update --init --recursive
```

## Usage

Start infrastructure only:

```bash
docker-compose up -d db redis
```

Start the full stack (builds Nexus + Gateway images locally):

```bash
cp docker-compose.env.example .env
docker-compose up --build
```

## Ports

- Gateway: `http://localhost:3000`
- Nexus REST: `http://localhost:3001` (mapped from container port `3000`)
- Nexus gRPC: `localhost:50051`

All ports are bound to `127.0.0.1` by default.

## Configuration

Gateway secrets (for example `API_TOKEN`, `FIAT_WEBHOOK_SECRET`) are required and must be supplied via environment variables or an `.env` file in the repository root.

Required endpoints:

- `BITCOIN_RPC_URL` (Gateway)
- `STACKS_RPC_URL` (Gateway)
- `STACKS_NODE_RPC_URL` (Nexus)

> Note
> `BITCOIN_RPC_URL` is required for the compose stack. For production, funds-bearing, or privacy-sensitive workloads, point it to a controlled node or vetted provider before running.
