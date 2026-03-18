# Infrastructure & Cloud Roadmap

Conxian follows a "Cloud-First, Sovereignty-Anchored" approach.

## Phase 1: Rapid Iteration (Current - Year 3.5)
- **Primary Provider**: Google Cloud Platform (GCP) for Core/Gateway.
- **Secondary Provider**: Render for UI/Static sites.
- **Monitoring**: "Glass Node Architecture" using Prometheus and Grafana.
- **Security**: "cxn-arch-guardian" automated secret filtering.

## Phase 2: Progressive Sovereignty (Year 3.5 - Year 5)
- **Transition**: Begin moving critical Bitcoin/Stacks RPC nodes to self-hosted or dedicated bare metal.
- **Goal**: Reduce reliance on third-party cloud for state validation while keeping application layers in the cloud for performance.

## Resource Allocation
- **compute**: n2-standard instances (GCP).
- **storage**: Cloud SQL (Postgres) + Bitcoin Core/Stacks node storage.

---
[Return to Root README](../../README.md) | [Strategic Alignment](../legacy_docs/ALIGNMENT.md)
