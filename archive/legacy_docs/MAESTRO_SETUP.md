---
title: Maestro Setup
layout: page
permalink: /./MAESTRO_SETUP
---

# Maestro On-Device Testing Setup

This document outlines the setup and usage of Maestro for automated UI testing
of the Conxius Wallet on Android devices.

## 1. Prerequisites

- **Java JDK 17+**: Required for running Maestro.
- **Android Device**: Connected via USB with USB Debugging enabled.
- **Maestro Binary**: Installed in `.maestro/maestro/bin`.

## 2. Environment Setup

We have created a helper script `run_maestro.bat` in the root directory to
handle environment variables (`JAVA_HOME`, `PATH`) automatically.

**Usage:**

```powershell
.\run_maestro.bat <command>
```

## 3. Running Tests

To run the standard flow on a connected device:

```powershell
.\run_maestro.bat test tests\maestro\flow.yaml
```

## 4. Test Flows

### `tests/maestro/flow.yaml`

A basic smoke test that:

1. Launches `com.conxius.wallet`.
2. Takes a screenshot (`lock_screen_state`).
3. Asserts that the text "CONXIUS ENCLAVE" is visible on the Lock Screen.

## 5. Troubleshooting

If elements are not found:

1. Run the hierarchy command to inspect the UI tree:

   ```powershell
   .\run_maestro.bat hierarchy
   ```

2. Verify the `resource-id` or `text` attributes in the output.
3. Ensure the device screen is on and unlocked (if not testing the lock screen itself).
