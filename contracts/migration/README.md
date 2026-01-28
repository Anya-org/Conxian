# Migration Module

## Overview

The Migration Module provides a set of contracts for managing the migration of data from legacy contracts to the enhanced Conxian Protocol. This module includes implementations for backward-compatible interfaces and data migration management.

## Core Contracts

### `legacy-adapter.clar`

This contract provides a backward-compatible interface to legacy contracts, allowing them to continue functioning during the migration period.

### `migration-manager.clar`

This contract manages the process of migrating data from legacy contracts to the new, enhanced contracts. It includes functions for:

* Tracking the status of the migration
* Migrating data in batches
* Verifying the integrity of the migrated data

## Status

**Under Development**: The contracts in this module are currently under development and are not yet considered production-ready.
