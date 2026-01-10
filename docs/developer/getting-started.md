# Getting Started for Developers

This guide provides the essential steps to set up your local development environment, run the test suite, and deploy the Conxian Protocol contracts.

## Development Setup

### Prerequisites

1.  **Clarinet**: Version 2.0+
2.  **Node.js**: Version 18+
3.  **Git**: For version control

### Installation

To get started, clone the repository and install the required npm dependencies.

```bash
git clone https://github.com/anyachainlabs/Conxian.git
cd Conxian
npm install
```

## Testing

The protocol includes a comprehensive test suite to ensure code quality and correctness.

### Running the Core Test Suite

This command runs all standard unit and integration tests.

```bash
npm test
```

### Advanced Testing Suites

For more targeted testing, you can use the following commands:

-   **System End-to-End**: `npm run test:system`
-   **Performance Benchmark**: `npm run test:performance`
-   **Fuzz Testing**: `npm run test:fuzz`
-   **Security Audit**: `npm run test:security`

## Deployment

The protocol uses a staged deployment process managed by a dedicated deployment script.

### Verified Principal Placeholders

When deploying to mainnet, ensure the following principals are used or replaced with your specific addresses:

| Role                 | Principal / Placeholder                      | Notes                                    |
| -------------------- | -------------------------------------------- | ---------------------------------------- |
| Devnet Deployer      | `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM`   | Standard Clarinet Devnet Address         |
| Mainnet Deployer     | `SP1CONXIANPROTOCOLDEPLOYERADDRESS`          | Replace with your deployer               |
| Protocol Coordinator | `SP1CONXIANPROTOCOLCOORDINATOR`              | Address of the deployed coordinator contract |
| SIP-010 Trait        | `SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE`   | Standard Mainnet SIP-010 Trait           |
| POX Contract         | `SP000000000000000000002Q6VF78`               | Stacks Mainnet POX Contract              |

### Deployment Commands

#### Devnet Deployment

This command deploys all protocol contracts to a local Clarinet devnet.

```bash
# Deploys to local Clarinet devnet
npm run deploy:core
```

#### Mainnet Deployment

For mainnet deployment, please refer to the `settings/Mainnet.toml` configuration file and ensure you have a valid deployer key.
