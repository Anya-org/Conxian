# Documentation Structure

## 1. Overview

This document outlines the official, audience-centric structure for all documentation in the Conxian Protocol repository. The goal is to provide a clear, consistent, and easily navigable "codewiki" for all stakeholders, from core developers to community members.

## 2. Core Principles

1.  **Audience-Centric**: All documentation should be organized based on its primary audience (e.g., developers, enterprise users, governance participants).
2.  **Single Source of Truth**: There should be no duplicate information. Documents should link to a single, canonical source whenever possible.
3.  **Code-Adjacent**: All technical documentation, especially for smart contract modules, must live as close to the code as possible (i.e., in a `README.md` file within the module's directory).
4.  **Minimal but Complete**: Documentation should be concise but provide all necessary information for the target audience to understand and interact with the system.

## 3. Directory Structure

The canonical source for all high-level documentation is the `/documentation/` directory.

### 3.1 Top-Level Documents (`/documentation/`)

This directory serves as the main hub and should contain the following key documents:

-   `README.md`: The main entry point and table of contents for all documentation.
-   `PRD.md`: The central "source of truth" for the Conxian Protocol, outlining its architecture, governance model, and development roadmap.
-   `CHANGELOG.md`: A log of all notable changes to the protocol.

### 3.2 Audience-Specific Subdirectories

-   `/documentation/developer/`: Guides and resources specifically for developers contributing to or building on top of the protocol.
-   `/documentation/enterprise/`: Integration guides and documentation for institutional partners.
-   `/documentation/whitepaper/`: The complete technical vision and protocol design.
-   `/documentation/security/`: Security policies, audit reports, and best practices.

## 4. Module-Level Documentation (`/contracts/[module]/`)

Every smart contract module directory (e.g., `/contracts/core/`, `/contracts/governance/`) **must** contain a `README.md` file. This file is the single source of truth for the module's architecture, functionality, and public-facing functions.

A module `README.md` should include:

1.  An **Overview** of the module's purpose and role in the protocol.
2.  An **Architecture** section describing the design patterns used (e.g., Pure Facade, Logic-Rich Facade).
3.  A **Control Flow Diagram** (using Mermaid) to visualize the interactions between the contracts in the module.
4.  A complete list of all **Public Functions** with their signatures and a brief description.
5.  A **Status** section indicating the current state of the module (e.g., Under Review, Production-Ready).

## 5. Forbidden Files

To maintain a clean and focused documentation suite, the following types of files are forbidden:

-   Duplicate or outdated documentation.
-   Temporary analysis or progress reports.
-   Conversation summaries or meeting notes.
