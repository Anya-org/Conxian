
## 6. Crystallized Entities (v1.9.3 - April 2026)

| ID | Type | Name/Title | Status | Relationship |
| :--- | :--- | :--- | :--- | :--- |
| `BOS_SYSTEM` | Project | Conxian BOS v1.9.3 | Stable | **anchors** all modules |
| `NEXUS` | Library | conxian-nexus (v0.5.1) | Production | **uses** `KwilAdapter` |
| `GATEWAY` | Library | conxian-gateway (v0.1.1) | Production | **uses** `StacksRpcAggregator` |
| `CONCLAVE_SDK` | Library | lib-conclave-sdk (v1.9.3) | Stable | **dependency_of** `WALLET` |
| `CORE_LIB` | Library | lib-conxian-core (v1.9.3) | Stable | **dependency_of** `GATEWAY` |
| `JUR_SHARDING` | Decision | Jurisdictional Sharding | Implemented | **isolated_by** `BNS` |
| `ZSE_MANDATE` | Decision | Zero Secret Egress | Enforced | **fixed** `PUBLIC_EXPOSURE_RISK` |
| `BITVM2_STATE` | Concept | BitVM2 State Proofs | Active | **verified_by** `CORE_LIB` |

---
*Crystallized by Jules at End-of-Sprint Review (April 2026).*
