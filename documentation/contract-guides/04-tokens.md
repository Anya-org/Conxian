# Contract Guide: Protocol Tokens (SIP-010)

**Primary Contracts:** `contracts/cxvg-token.clar`, `contracts/cxlp-token.clar`, `contracts/gov-token.clar`, `contracts/creator-token.clar`

## 1. Introduction

The Conxian ecosystem utilizes a multi-token model to facilitate governance, reward liquidity providers, and incentivize contributors. All protocol tokens adhere to the Stacks `SIP-010` standard for fungible tokens. This guide provides an overview of each token's purpose and utility within the protocol.

The primary tokens are:
-   **CXVG Token (`cxvg-token`):** The core governance token.
-   **CXLP Token (`cxlp-token`):** The liquidity provider (LP) token.
-   **Governance Token (`gov-token`):** The token used for voting in the DAO. (Note: This may be the same as CXVG or a separate token depending on the final tokenomics).
-   **Creator Token (`creator-token`):** A merit-based rewards token for contributors.

## 2. Token Details

### CXVG Token (`cxvg-token.clar`)

-   **Purpose:** `CXVG` is the main governance token of the Conxian protocol. Its primary role is to give holders a say in the future direction of the platform.
-   **Utility:**
    -   **Revenue Share:** A significant portion of the protocol's revenue is distributed to `CXVG` holders.
    -   **Governance:** While `.gov-token` is used for voting, `CXVG` may be the token that is staked or locked to receive `.gov-token`. The exact mechanism is defined in the tokenomics.
-   **How to Acquire:**
    -   Migrating from `CXLP` tokens during specific epochs.
    -   Purchasing on the open market (DEX).
    -   Receiving as a reward for certain protocol activities.

### CXLP Token (`cxlp-token.clar`)

-   **Purpose:** `CXLP` is a reward token for users who provide liquidity to the Conxian protocol, either by depositing into the main vault or by adding liquidity to the DEX.
-   **Utility:**
    -   **Migration to CXVG:** `CXLP` tokens can be converted into `CXVG` tokens. The conversion rate may change over time to incentivize early liquidity providers.
    -   **Yield Farming:** `CXLP` can be staked in yield farms to earn additional rewards.
-   **How to Acquire:**
    -   Automatically earned by depositing assets into the `vault.clar` contract.
    -   Earned by providing liquidity to pools in the Conxian DEX.

### Governance Token (`gov-token.clar`)

-   **Purpose:** This is the specific token used for voting in the `dao-governance.clar` contract.
-   **Utility:**
    -   **Voting Power:** The number of `gov-token` you hold determines your voting power in DAO proposals.
    -   **Proposal Creation:** A minimum balance of `gov-token` is required to create a new proposal.
-   **How to Acquire:**
    -   Typically acquired by staking or locking `CXVG` tokens. This separation allows for more flexible governance models (e.g., time-weighted voting power based on lock duration).

### Creator Token (`creator-token.clar`)

-   **Purpose:** A unique, merit-based token designed to reward individuals who contribute to the Conxian ecosystem through non-financial means.
-   **Utility:**
    -   **Bounties:** Awarded for completing development bounties, fixing bugs, or creating new features.
    -   **Community Contributions:** Can be awarded for creating documentation, tutorials, providing community support, or other valuable contributions.
    -   **Reputation:** Serves as an on-chain record of a user's positive contributions to the protocol.
-   **How to Acquire:**
    -   Awarded by the DAO through the `bounty-system.clar` contract or by direct grants for valuable work.

## 3. Token Interaction Flow

The tokens are designed to work together to create a balanced and sustainable economic system.

1.  **Users provide liquidity** (to the vault or DEX) and receive **`CXLP`** tokens as a reward.
2.  **`CXLP` holders can choose to migrate** their tokens to **`CXVG`** tokens to gain governance rights and a share of protocol revenue.
3.  **`CXVG` holders can stake or lock** their tokens to receive **`gov-token`**, which is used to vote on DAO proposals.
4.  **Contributors perform work**, complete bounties, and are rewarded with **`creator-token`**, which may grant them special status or future benefits.

This system aligns the incentives of different user groups: liquidity providers are rewarded, long-term holders govern the protocol, and valuable contributors are recognized and compensated.
