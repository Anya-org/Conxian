# Spec: Enterprise Sovereignty Remediation

## ADDED Requirements

### Requirement: Business Unit Consolidation
The ecosystem MUST be organized into four standalone businesses: Conxius, CSF, Fusion, and Nexus.

#### Scenario: Business Logic Alignment
- **Given** an unbundled architecture
- **When** defining business logic
- **Then** each unit MUST have dedicated logic and state management as specified in design.md.

### Requirement: Zero Secret Egress Standard
All mobile-based sovereign services MUST adhere to the Zero Secret Egress standard.

#### Scenario: Private Key Security
- **Given** a mobile wallet (Conxius)
- **When** signing a transaction
- **Then** the private key MUST never leave the StrongBox TEE.

### Requirement: Nexus-First State Authority
The Conxian Nexus MUST be the authoritative source for blockchain state for the Gateway.

#### Scenario: State Synchronization
- **Given** a Gateway request for block height
- **When** fetching state
- **Then** the Gateway MUST prioritize the Nexus API over external RPCs.

### Requirement: CXIP-013 Revenue Logic
The 6-way revenue split MUST be calculated in Clarity based on the Global Collateral Ratio (GCR).

#### Scenario: Revenue Distribution
- **Given** a protocol fee event
- **When** distributing tokens
- **Then** the Treasury module MUST apply CXIP-013 logic.

### Requirement: ISO 20022 Compliance
All institutional egress MUST match ISO 20022 XML standards.

#### Scenario: ERP Integration
- **Given** a transaction ready for ERP synchronization
- **When** the Engine generates the payload
- **Then** the output MUST follow ISO 20022 specifications.
