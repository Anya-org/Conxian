# Conxian Onsite Server Specification Sheet (2026)

This document defines the authoritative hardware, networking, and security requirements for onsite "Citadel" deployments of the Conxian ecosystem. These specifications ensure the performance and sovereignty of the **Fusion Gateway**, **Conxian Nexus**, and associated blockchain nodes.

## 1. Deployment Tiers

| Tier | Deployment Type | Target Use Case |
| :--- | :--- | :--- |
| **Tier 1: Sovereign SME** | Single Node | Small business treasuries, individual high-net-worth "Citadelists". |
| **Tier 2: Institutional** | High-Availability Cluster | Corporate treasuries, LPs, and financial institutions. |
| **Tier 3: Sovereign State** | Geo-Redundant Grid | National-level infrastructure and global settlement hubs. |

---

## 2. Hardware Requirements (Per Node)

### 2.1 Processor (CPU)
*   **Requirement**: Minimum 8 Cores / 16 Threads (Tier 1), 32+ Cores (Tier 2/3).
*   **Architecture**: x86_64 with **Intel SGX** (Software Guard Extensions) or **AMD SEV** (Secure Encrypted Virtualization) support.
*   **Rationale**: Required for TEE-enclosed state verification and "Zero Secret Egress" attestation.

### 2.2 Memory (RAM)
*   **Requirement**: 64GB DDR4/DDR5 ECC (Tier 1), 256GB+ DDR5 ECC (Tier 2/3).
*   **Rationale**: ECC is mandatory to prevent bit-flips in financial state logic. High capacity is required for in-memory Merkle Tree operations and Redis caching.

### 2.3 Storage (Disk)
*   **Primary (OS/App)**: 500GB NVMe SSD (Gen4/Gen5).
*   **Data (Blockchain/Nexus)**: 4TB+ Enterprise NVMe SSD (U.2/M.2) in RAID 1/10.
*   **Rationale**: Bitcoin and Stacks full nodes require high IOPS. The Nexus Persistent MMR (Merkle Mountain Range) peaks require low-latency storage for O(1) audit log restoration.

---

## 3. Networking & Connectivity

### 3.1 Throughput
*   **External**: 1Gbps Dedicated Symmetric Fiber (Minimum).
*   **Internal (LAN)**: 10Gbps SFP+ or Base-T for cluster synchronization.

### 3.2 Port Configuration
| Port | Service | Traffic Type | Description |
| :--- | :--- | :--- | :--- |
| **8080** | Fusion Gateway | Inbound (Restricted) | B2B Institutional API. |
| **3000** | Conxian Nexus | Inbound (Internal) | Glass Node Telemetry & State Proofs. |
| **50051** | Nexus gRPC | Internal | High-performance state synchronization. |
| **8332/8333** | Bitcoin Core | P2P / RPC | Bitcoin network connectivity. |
| **20443/20444** | Stacks Node | P2P / RPC | Stacks Nakamoto network connectivity. |
| **9090** | Prometheus | Internal | Metrics scraping for "Glass Node" visibility. |

### 3.3 Security Infrastructure
*   **Hardware Firewall**: Dedicated appliance (e.g., pfSense/OPNsense or enterprise-grade).
*   **VPN**: WireGuard-based site-to-site tunnel for remote management.

---

## 4. Security & Compliance

### 4.1 Physical Security
*   **Tier 1**: Locked server cabinet with tamper-evident seals.
*   **Tier 2/3**: Biometric-gated data center rack with 24/7 CCTV.

### 4.2 Cryptographic Root of Trust
*   **HSM**: Dedicated Hardware Security Module (FIPS 140-2 Level 3) for master key wrapping.
*   **TPM**: TPM 2.0 module for secure boot and disk encryption key storage.

### 4.3 Sovereignty Standards
*   **Zero Secret Egress**: Enforced via TEE and StrongBox-compatible SDKs.
*   **MVCR Generation**: Hardware must support the execution of Mathematically Verifiable Compliance Reports.

---

## 5. Software Stack (Baseline)

*   **OS**: Debian 12 (Bookworm) or Ubuntu 24.04 LTS (Minimal/Server).
*   **Containerization**: Docker 24+ / Docker Compose V2.
*   **Orchestration**: Kubernetes (K3s) for Tier 2/3 HA deployments.
*   **State Engines**:
    *   Conxian Nexus v0.1.7+
    *   Fusion Gateway v0.1.1+
*   **Nodes**:
    *   Bitcoin Core v27.0+
    *   Stacks Node (Nakamoto-ready) v3.1+

---

## 6. Observability & Maintenance

*   **Logging**: Centralized Graylog or ELK stack for audit trails.
*   **Metrics**: Prometheus + Grafana dashboard (Pre-configured with Conxian "Earthy Corporate" theme).
*   **Backups**: Daily off-site encrypted snapshots (S3/Wasabi/Self-hosted MinIO).

---
© 2026 Conxian. Sovereign Autonomous Business.
[Return to Strategic Alignment](../legacy_docs/ALIGNMENT.md)
