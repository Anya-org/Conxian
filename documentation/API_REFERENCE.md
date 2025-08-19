# Stacks API Integration Guide

This guide shows how to interact with the Clarity contracts in this repo via the Stacks Blockchain API (Hiro) and local dev environments.

References:

- API Docs: <https://docs.stacks.co/reference/api>
- Mainnet API (Hiro): <https://api.mainnet.hiro.so>
- Testnet API (Hiro): <https://api.testnet.hiro.so>
- Hiro API Hub: <https://platform.hiro.so/api-hub>

Note: Transactions must be signed client-side (wallet, stacks.js, or your signer). The API broadcasts signed payloads and provides read-only simulation endpoints.

## Using Hiro API Hub keys

Some endpoints and plans support API keys. We keep usage flexible via environment variables so you can pass either a Bearer token or an API-key header.

- Set in your shell (do not commit secrets):

```bash
export HIRO_API_KEY="<your-key>"
# Default header is Authorization: Bearer <key>
# If your key uses a different header (e.g., X-API-Key), override:
export HIRO_API_HEADER="X-API-Key:"

# Optional: pick base URL (default testnet)
export STACKS_API_BASE="https://api.testnet.hiro.so"
```

Our helper scripts in `scripts/` will include the header when `HIRO_API_KEY` is set.

## Read-only contract calls (simulate)

Endpoint: `POST /v2/contracts/call-read/{contract_address}/{contract_name}/{function_name}`

Example: read balance call for `vault.clar` on testnet

```bash
curl -s \
  -X POST \
  -H 'Content-Type: application/json' \
  -H "${HIRO_API_HEADER:-Authorization: Bearer} ${HIRO_API_KEY:-}" \
  'https://api.testnet.hiro.so/v2/contracts/call-read/{deployer-address}/vault/get-balance' \
  -d '{
    "sender": "{caller-address}",
    "arguments": ["0x{hex-encoded-principal}"]
  }'
```

Arguments for read-only are Clarity Value hex-encoded. For principals, use their CV encoding (e.g., via stacks.js or npx clarinet console).

## Broadcast a signed transaction

Endpoint: `POST /v2/transactions`

```bash
curl -s \
  -X POST \
  -H 'Content-Type: application/octet-stream' \
  -H "${HIRO_API_HEADER:-Authorization: Bearer} ${HIRO_API_KEY:-}" \
  --data-binary @signed_tx.bin \
  'https://api.testnet.hiro.so/v2/transactions'
```

- `signed_tx.bin` is a fully signed Stacks transaction (e.g., contract-call to `deposit`).
- Build and sign with stacks.js or a backend signer; then broadcast using this endpoint.

## Get transaction status

Extended endpoint: `GET /extended/v1/tx/{txid}`

```bash
curl -s 'https://api.testnet.hiro.so/extended/v1/tx/0xYOUR_TXID'
```

## Contract interface and ABI

Endpoint: `GET /v2/contracts/interface/{contract_address}/{contract_name}`

```bash
curl -s 'https://api.testnet.hiro.so/v2/contracts/interface/{deployer-address}/vault'
```

## Events (indexer)

Get events for a contract (Extended API):

```bash
curl -s 'https://api.testnet.hiro.so/extended/v1/contract/{deployer-address}.vault/events?limit=50'
```

## Helper scripts

In `scripts/` we provide small utilities that respect env vars and inject the API key header if present:

- `scripts/ping.sh` — sanity check against `/v2/info`
- `scripts/call-read.sh` — POST call-read for read-only functions
- `scripts/get-abi.sh` — GET ABI for a contract
- `scripts/broadcast-tx.sh` — POST a signed tx binary

Make them executable and run:

```bash
chmod +x scripts/*.sh

# Example: call-read get-fees (no args)
CONTRACT_ADDR=SP... CONTRACT_NAME=vault FN=get-fees ./scripts/call-read.sh

# Example: ping with API key header
export HIRO_API_KEY="<your-key>"
./scripts/ping.sh | jq .network_id
```

## Local development (Clarinet)

Note: This repo pins Clarinet SDK v3.5.0 via npm. Use `npx clarinet` to ensure the correct version.

- `npx clarinet check` — compile and static analysis.
- `npx clarinet console` — ephemeral devnet + REPL to call functions:

```clj
;; inside console
(contract-call? .vault deposit u100)
(contract-call? .vault get-balance tx-sender)
(contract-call? .vault withdraw u50)
```

Clarinet console uses a local stacks-devnet under the hood; to interact programmatically from a script, you can point clients to the local API exposed by the devnet (Clarinet will show the URL when running the console).

## Suggested client stack

- Browser dApp: `@stacks/connect`, `@stacks/transactions`, `@stacks/network`
- Backend signer (optional): `@stacks/transactions` in Node.js for assembling and signing txs
- Monitoring: poll `extended/v1/tx`, consume events via extended API

## Notes

- Always test on testnet/devnet before mainnet.
- Use post-conditions in contract-calls to guard against unintended transfers.
- Keep arguments small to minimize gas and payload size.
