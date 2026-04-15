# Sovereign & Decentralized Node Research Summary

## 1. Competitor Analysis
| System | Type | Decentralization | Best Features |
| --- | --- | --- | --- |
| Glassnode | Analytics | Low (SaaS) | Deep on-chain metrics, exchange flows. |
| The Graph | Indexing | High (Decentralized Network) | Subgraphs, GraphQL, incentivized indexers. |
| POKT Network | RPC | High (P2P RPC) | Decentralized RPC relay, censorship resistance. |
| Akash | Compute | High (Marketplace) | Permissionless cloud, lower cost than AWS/GCP. |
| Umbrel/Start9 | Personal Node | High (Self-hosted) | App store for self-hosted services, easy UI. |

## 2. Enhancement Vectors for Nexus
- **P2P State Propagation**: Move away from single-node PostgreSQL/Redis dependencies for state verification. Use libp2p Gossipsub for state-root consensus between Nexus nodes.
- **Jurisdictional Sharding**: Enhance Kwil integration to support multi-region data sovereignty as per BOS v2.1.
- **Autonomous Recovery**: Extend the `AutonomousOrchestrator` to trigger Akash redeployments if a node becomes unhealthy.

## 3. Enhancement Vectors for Gateway
- **Provider Pooling**: Integrate POKT Network as a fallback provider in `StacksRpcAggregator`.
- **Offline Ingress**: Finalize the "Offline POS" mode for low-connectivity environments (CON-166).
