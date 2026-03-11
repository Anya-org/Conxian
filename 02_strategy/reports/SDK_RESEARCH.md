# SDK Research Report: Full Bitcoin Ecosystem Enhancements

**Date:** 2026-02-18
**Status:** DRAFT
**Context:** Researching SDKs for Taproot Musig2, RGB Client-Side Validation, and Device Integrity.

---

## 1. RGB Protocol (Client-Side Validation)

### Recommended SDK: `rgb-lib-wasm`
The `rgb-lib` (developed by Bitmask/DIBA) is the most mature implementation for client-side validation of RGB assets on mobile/web.

- **Capabilities:**
    - Full DAG validation of state transitions.
    - AluVM execution for contract logic.
    - Stash management (local storage of consignments).
    - Blinded UTXO creation and invoice handling.
- **Integration Path:**
    1. Import the WASM module into the `Persistent Crypto Worker`.
    2. Initialize the `Stash` using a persistent storage adapter (e.g., indexedDB).
    3. Use `validate_consignment()` within the `services/rgb.ts` validation flow.
- **Dependency:** `@bitmask/rgb-lib-wasm` (or latest from LNP-BP).

---

## 2. Musig2 (BIP-327) Multi-Sig

### Recommended SDK: `noble-curves` + `musig2-js`
While `bitcoinjs-lib` handles Taproot (BIP-341/342), Musig2 (BIP-327) requires specific partial signature aggregation logic.

- **Capabilities:**
    - Deterministic and non-deterministic nonce generation.
    - Key aggregation (creating the `P = sum(L_i * X_i)` public key).
    - Partial signature generation and verification.
    - Final signature aggregation into a valid Schnorr signature.
- **Integration Path:**
    - Utilize `@noble/curves/secp256k1` for the underlying point math.
    - Implement the Musig2 state machine (Nonce Gen -> Sign -> Aggregate) in `services/multisig.ts`.
- **Reference:** [BIP-327 Spec](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki).

---

## 3. Android Play Integrity (Attestation)

### Recommended SDK: `com.google.android.play:integrity`
This is essential for the "User Safety & Trust" phase to ensure the app is running in a genuine, uncompromised environment.

- **Capabilities:**
    - `MEETS_DEVICE_INTEGRITY`: Confirms the device is genuine.
    - `MEETS_STRONG_INTEGRITY`: Confirms hardware-backed security (TEE/StrongBox) is active.
    - `MEETS_VIRTUAL_INTEGRITY`: Detects emulators.
- **Integration Path:**
    - **Native (Java):** Call the Play Integrity API in `DeviceIntegrityPlugin.java` to obtain an integrity token.
    - **Backend (Node.js):** Send the token to the Conxian Gateway for verification using the Google Play Integrity API.
    - **App Logic:** If verification fails, restrict access to the Enclave for large transactions.

---

## 4. Next Steps for Implementation

1. **POC for RGB:** Integrate the WASM loader in `worker-manager.ts` and verify a sample NIA (Non-Inflatable Asset) consignment.
2. **Musig2 Prototype:** Create a test suite in `tests/musig2.test.ts` verifying the aggregation of 3 partial signatures into a valid Taproot witness.
3. **Integrity Hook:** Update the Conxian Gateway to include a `/api/v1/compliance/verify-integrity` endpoint.


---

## 5. Privacy - CoinJoin (WabiSabi)

### Recommended SDK: `wabisabi-client-js`
For privacy-preserving transactions, a real-world coordinator is needed.

- **Capabilities:**
    - Blame logic for non-cooperative participants.
    - Zero-knowledge proofs for input/output amounts.
    - Tor-routing for all communications with the coordinator.
- **Integration Path:**
    - Use `services/coinjoin.ts` to handle the registration and signing phases.
    - Connect to the Wasabi or zkSNACKs coordinator.
