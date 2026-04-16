# Unified RPC Configuration Contract (v1)

This document defines a minimal, machine-consumable configuration contract for Conxian RPC routing.

It captures the approved packaging decisions from https://linear.app/conxian-labs/issue/CON-457:

- Personas are tiers (not separate codebases): Home = `Public-Only`, Retail = `Mixed`, Enterprise = `Sovereign-First`.
- Add-ons are optional packs (extensible catalog).
- Default posture is remote RPC first, with a unified configuration screen to override endpoints / strategy.

## 1. Goals

1. Define a minimal schema for `rpcStrategy` + endpoint overrides + add-on toggles.
2. Keep it 1:1 mappable to the current env surface so it can drive `.env` generation without surprises.

## 2. Contract format

- Shape: JSON
- JSON Schema: `rpc-config.v1.schema.json`
- Contract identifier (config `schema` field): `conxian.rpc-config.v1`
- JSON Schema `$id`: `urn:conxian:rpc-config:v1`

### 2.1 Example (Home / open tier)

```json
{
  "schema": "conxian.rpc-config.v1",
  "rpcStrategy": "Public-Only",
  "bitcoin": {
    "rpcUrl": "https://bitcoin-rpc.publicnode.com"
  },
  "stacks": {
    "gatewayRpcUrl": "https://api.mainnet.hiro.so",
    "nodeRpcUrl": "https://api.mainnet.hiro.so"
  },
  "addOns": {
    "bisq": { "enabled": false },
    "rgb": { "enabled": false },
    "bitvm": { "enabled": false }
  }
}
```

## 3. Field-to-env mapping (v1)

The contract is designed so `.env` generation is a straightforward projection.

### 3.1 `rpcStrategy` semantics

`rpcStrategy` communicates the intended routing posture for consumers of this config (UI, admin tooling, orchestration). It is not projected into `.env` variables directly.

- `Public-Only`: remote/public RPC is allowed and preferred.
- `Mixed`: remote/public RPC is allowed, but local/sovereign endpoints should be used when available.
- `Sovereign-First`: local/private RPC is preferred; remote endpoints should be treated as a fallback (or disabled) depending on the distribution.

Tier defaults (from https://linear.app/conxian-labs/issue/CON-457): Home = `Public-Only`, Retail = `Mixed`, Enterprise = `Sovereign-First`.

### 3.2 Core routing

| Config field | Env var | Consumer |
| :--- | :--- | :--- |
| `bitcoin.rpcUrl` | `BITCOIN_RPC_URL` | `conxian-gateway` |
| `bitcoin.rpcAuth.user` | `BITCOIN_RPC_USER` | `conxian-gateway` |
| `bitcoin.rpcAuth.pass` | `BITCOIN_RPC_PASS` | `conxian-gateway` |
| `stacks.gatewayRpcUrl` | `STACKS_RPC_URL` | `conxian-gateway` |
| `stacks.nodeRpcUrl` | `STACKS_NODE_RPC_URL` | `conxian-nexus` |

Notes:

- If a field is omitted, the consuming service’s built-in default applies.
- If `bitcoin.rpcAuth` is present, both `user` and `pass` are required.
- `bitcoin.rpcAuth.pass` is a secret. Producers should avoid committing RPC credentials into version control; prefer injecting secrets at deploy time.

### 3.3 Add-on packs

Known packs in v1: `bisq`, `rgb`, `bitvm`.

`addOns` keys are extensible but must be stable and deterministic for `.env` projection. The authoritative validation rules are defined in `rpc-config.v1.schema.json` under `addOns.propertyNames`.

In short: pack identifiers must be lowercase alphanumeric strings that start with a letter, may include `-` separators between segments (for example `my-pack-1`), and must be no longer than 64 characters.

Custom packs (producer-defined `addOns.<pack>` keys) **MUST** use the same shape as known packs: an `enabled` boolean and an optional `rpc` object (`rpc.host` is required when enabled; `rpc.port` is optional).

| Pack | Config field | Env var | Consumer |
| :--- | :--- | :--- | :--- |
| `bisq` | `addOns.bisq.rpc.host` | `BISQ_RPC_HOST` | `conxius-platform` |
| `bisq` | `addOns.bisq.rpc.port` | `BISQ_RPC_PORT` | `conxius-platform` |
| `rgb` | `addOns.rgb.rpc.host` | `RGB_RPC_HOST` | `conxius-platform` |
| `bitvm` | `addOns.bitvm.rpc.host` | `BITVM_RPC_HOST` | `conxius-platform` |

Notes:

- When `addOns.<pack>.enabled` is `true`, the pack **MUST** include `addOns.<pack>.rpc.host`.
- If `addOns` is omitted, all packs are treated as disabled.
- If `addOns.<pack>` is omitted, that pack is treated as disabled.
- If `addOns.<pack>.enabled` is `false` and `addOns.<pack>.rpc` is present, the pack is still treated as disabled; the RPC details may be retained for UI defaults but must not be used for runtime routing until enabled.
- In the current `conxius-platform/.env.schema`, only Bisq declares an explicit `*_RPC_PORT` variable (Bisq is `host` + `port`; RGB/BitVM are `host` only).
- Consumers **MUST** ignore `addOns.<pack>.rpc.port` unless the pack’s env surface explicitly declares a `<PACK>_RPC_PORT` variable.

For future packs, env var names **SHOULD** follow the convention:

- `addOns.<pack>.rpc.host` → `<PACK>_RPC_HOST`
- `addOns.<pack>.rpc.port` → `<PACK>_RPC_PORT` (optional)

Where `<PACK>` is the `addOns` key uppercased, with non-alphanumeric characters replaced by `_`.

Because pack identifiers are restricted to lowercase letters, digits, and `-`, the above normalization is equivalent to `-` → `_`.

### 3.4 Metadata

The config may include a top-level `metadata` object for producer-specific annotations (for example, UI hints or provenance).

Consumers **must** ignore `metadata` for routing decisions and `.env` generation.
