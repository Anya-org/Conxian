# Compliance Module

## Overview

The Compliance Module provides a suite of tools for managing regulatory requirements within the Conxian Protocol. It includes contracts for handling sanctions screening, KYC/AML, and the FATF Travel Rule.

## Architecture

This module is designed as an intelligence layer that can be integrated with other protocol components to ensure that all operations are compliant with the relevant regulations. It includes a central manager, a mock oracle for sanctions screening, a service for Travel Rule compliance, and a trait that defines the core compliance interface.

### Core Contracts

-   **`compliance-manager.clar`**: The central orchestration contract for the module. It manages the overall compliance status and integrates with the other components to perform checks.
-   **`sanctions-oracle.clar`**: A mock oracle for checking if a user address is on a sanctions list.
-   **`travel-rule-service.clar`**: A service for logging and verifying FATF Travel Rule data.
-   **`compliance-trait.clar`**: A trait that defines the standard interface for compliance-related functions.
-   **`compliance-api.clar`**: A placeholder contract that is currently empty.

## Public Functions

### `compliance-manager.clar`

-   `set-owner(new-owner principal)`: (Owner Only) Sets the owner of the contract.
-   `set-compliance-enabled(enabled bool)`: (Owner Only) Enables or disables compliance checks.
-   `check-user-compliance(user principal)`: Checks the compliance status of a user.
-   `is-compliant(user principal)`: (Read-Only) Returns the compliance status of a user.

### `sanctions-oracle.clar`

-   `is-sanctioned(user principal)`: (Read-Only) Checks if a user is on the sanctions list.
-   `set-sanctioned(user principal, status bool)`: Sets the sanctioned status of a user.

### `travel-rule-service.clar`

-   `log-travel-rule-data(transaction-ref (buff 32), ivms101-hash (buff 32), originator-vasp (string-ascii 20), beneficiary-vasp (string-ascii 20), amount uint, token principal)`: Logs the data for a transaction that is subject to the Travel Rule.
-   `requires-travel-rule(amount uint)`: (Read-Only) Checks if a transaction requires Travel Rule data.
