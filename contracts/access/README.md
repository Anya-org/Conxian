---
layout: default
title: Access Module
permalink: /modules/access/
---

# Access Module

## Overview

The Access Module provides a simple Role-Based Access Control (RBAC) system for the Conxian Protocol. It allows for the granting and revoking of specific roles to different principals, which can then be used by other contracts to authorize administrative or privileged actions.

## Architecture

The module consists of a single contract, `roles.clar`, which manages a map of users and their assigned roles.

## Core Contracts

-   **`roles.clar`**: A centralized contract for managing user roles.

## Public Functions

### `roles.clar`

#### Role Management
-   `grant-role(user principal, role-id uint)`: (Admin Only) Grants a specific role to a user.
-   `revoke-role(user principal, role-id uint)`: (Admin Only) Revokes a specific role from a user.

#### Read-Only Functions
-   `has-role(user principal, role-id uint)`: (Read-Only) Checks if a user has a specific role.
-   `is-admin(user principal)`: (Read-Only) Checks if a user is an admin (either the contract owner or has the admin role).

## Status

**Production-Ready**: The contract in this module is simple and considered stable for use.
