# Akash Autonomous Deployment Specification (BaaP v2.1)
**Date:** April 18, 2026
**Subject:** Transitioning Conxian Sovereign Nodes to Akash Network

## 1. Objective
To achieve zero-downtime, censorship-resistant deployment of the Conxian Sovereign Node (Nexus + Gateway + UI) using the Akash Network marketplace. This replaces centralized dependencies (Cloud Run/Render) with a Bitcoin-native orchestration layer.

## 2. Akash SDL Template (Sovereign Node)
The following template defines the service architecture for a Conxian Sovereign Node:

```yaml
version: "2.0"

services:
  nexus:
    image: ghcr.io/conxian/conxian-nexus:v0.5.1
    env:
      - DATABASE_URL=postgres://nexus:nexus@postgres:5432/nexus
      - REDIS_URL=redis://redis:6379/
      - BOOTSTRAP_SENDER=SPSZXAKV7DWTDZN2601WR31BM51BD3YTQWE97VRM
      - NOSTR_RELAYS=ws://relay.damus.io,ws://nostr.mom
    expose:
      - port: 3000
        as: 80
        to:
          - global: true
      - port: 50051
        to:
          - global: true
    params:
      storage:
        data:
          mount: /var/lib/nexus

  gateway:
    image: ghcr.io/conxian/conxian-gateway:v0.1.1
    env:
      - NEXUS_URL=http://nexus:3000
    expose:
      - port: 8080
        to:
          - global: true

profiles:
  compute:
    nexus:
      resources:
        cpu:
          units: 2
        memory:
          size: 4Gi
        storage:
          - size: 10Gi
          - name: data
            size: 100Gi
            attributes:
              persistent: true
              class: beta3
    gateway:
      resources:
        cpu:
          units: 1
        memory:
          size: 2Gi

  placement:
    dcloud:
      attributes:
        host: akash
      pricing:
        nexus:
          denom: uakt
          amount: 1000
        gateway:
          denom: uakt
          amount: 500

deployment:
  nexus:
    dcloud:
      profile: nexus
      count: 1
  gateway:
    dcloud:
      profile: gateway
      count: 1
```

## 3. Persistent State (Kwil/Tableland Integration)
- **Kwil**: Used for active relational state (OData reconciliation). Requires `KWIL_PROVIDER_URL` and `KWIL_DB_ID` in the `nexus` env block.
- **Tableland**: Used for state-root anchoring. Does not require persistent local volumes as it is a decentralized SQL mirror.

## 4. Implementation Steps (Q3 2026)
1.  **Containerization**: Ensure all modules (Nexus, Gateway, UI) have multi-arch (AMD64/ARM64) Docker images in GHCR.
2.  **Wallet Management**: Use Akash's secure env handling for `NOSTR_SECRET_KEY` and `KWIL_PRIVATE_KEY_HEX`.
3.  **Deployment Operator**: Implement a script that bids on Akash resources using sBTC/AKT liquidity from the Fiscal Vault.

---
*Created by Jules. Aligned with CON-474.*
