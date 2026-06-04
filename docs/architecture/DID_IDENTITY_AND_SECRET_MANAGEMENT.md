# DID-Based Identity and Secret Management (CON-DID)

> **Status**: Design Proposal v1  
> **Scope**: BOS identity plane, CI/CD auth, service-to-service auth, governance  
> **Relation**: Extends `BOS_SOVEREIGN_ENTERPRISE_IDENTITY_ARCHITECTURE.md` with DID primitives  
> **ZSE Classification**: Architecture — public-safe, no secret material

---

## 1. Problem Statement

The BOS currently manages service identities and secrets through:

1. **GitHub Actions secrets** (37 references across 17 workflows, 10 unique names, 7 configured)
2. **Environment variables** in conxian-nexus (25+ vars across 13 service domains)
3. **Static shared secrets** (API tokens, HMAC keys) without cryptographic binding to a root identity

This creates:
- **Secret sprawl**: Each service has independently managed credentials with no common root of trust
- **Rotation complexity**: No hierarchical key derivation — rotating one secret requires updating N consumers
- **No cryptographic audit**: Cannot prove which service identity generated which action (no non-repudiation)
- **Governance gap**: No programmable recovery or quorum-based admin operations

## 2. DID Architecture

### 2.1 Root DID

The system defines a root DID as its cryptographic anchor. All service identities are derived from this root.

```
did:key:z6MkhaXgBZDvBfvABrX5jHkfMzFcLtaLqB4CThe Root DID
│
├── did:key:z6Mk...a  →  conxian-nexus (Rust middleware)
├── did:key:z6Mk...b  →  conxius-wallet (Android client)
├── did:key:z6Mk...c  →  conxius-orbit (Deployment toolkit)
├── did:key:z6Mk...d  →  Nostr telemetry bridge
├── did:key:z6Mk...e  →  Admin API governance
├── did:key:z6Mk...f  →  GitHub Actions (CI/CD OIDC)
├── did:key:z6Mk...g  →  Kwil database provider
├── did:key:z6Mk...h  →  Stacks/Clarity contract deployer
└── did:key:z6Mk...i  →  Oracle service (yield/LSAT)
```

**DID Method Selection**:

| Method | Use Case | Status |
|---|---|---|
| `did:key` | Static key pairs, CI/CD, service identities | **Recommended** — no on-chain dependency |
| `did:stacks` | On-chain Clarity contract identities | Available via Stacks blockchain |
| `did:ion` | Long-form, recoverable DIDs (Sidetree) | Future — when BOS needs DID recovery without Stacks |
| `did:web` | Public enterprise discovery | Future — public documentation |

For v1, **`did:key`** is the primary method for all service identities, with `did:stacks` for on-chain contract governance.

### 2.2 Hierarchical Key Derivation (BIP-32 pattern)

Service keys are deterministically derived from the root seed using a purpose-defined derivation path:

```
m / purpose' / did_method' / service_type' / index'
```

| Component | Value | Description |
|---|---|---|
| `purpose'` | `784'` | DID purpose (IANA-registered for DIDs) |
| `did_method'` | `0'` | `did:key` method |
| `service_type'` | See table | Service category |
| `index'` | `0..N` | Instance number |

**Service type registry**:

| Code | Service | Derivation Path |
|---|---|---|
| `0'` | Root / master | `m/784'/0'/0'/0'` |
| `1'` | conxian-nexus | `m/784'/0'/1'/i'` |
| `2'` | conxius-wallet | `m/784'/0'/2'/i'` |
| `3'` | conxius-orbit | `m/784'/0'/3'/i'` |
| `4'` | Nostr telemetry | `m/784'/0'/4'/i'` |
| `5'` | Admin API | `m/784'/0'/5'/i'` |
| `6'` | CI/CD (GitHub Actions) | `m/784'/0'/6'/i'` |
| `7'` | Kwil provider | `m/784'/0'/7'/i'` |
| `8'` | Stacks deployer | `m/784'/0'/8'/i'` |
| `9'` | Oracle service | `m/784'/0'/9'/i'` |
| `10'` | Governance multisig | `m/784'/0'/10'/i'` |

### 2.3 DID Document Structure

Each service DID resolves to a DID Document containing:

```json
{
  "@context": ["https://www.w3.org/ns/did/v1"],
  "id": "did:key:z6Mk...a",
  "verificationMethod": [{
    "id": "did:key:z6Mk...a#key-1",
    "type": "JsonWebKey2020",
    "controller": "did:key:z6Mk...a",
    "publicKeyJwk": { ... }
  }],
  "authentication": ["did:key:z6Mk...a#key-1"],
  "assertionMethod": ["did:key:z6Mk...a#key-1"],
  "capabilityDelegation": ["did:key:z6Mk...a#key-1"],
  "capabilityInvocation": ["did:key:z6Mk...a#key-1"],
  "service": [{
    "id": "did:key:z6Mk...a#nexus-api",
    "type": "ConxianNexusService",
    "serviceEndpoint": "https://nexus.conxian.com/api/v1"
  }]
}
```

## 3. Secret Management with DID

### 3.1 From Static Secrets to DID-Auth

Current state (static secrets in GitHub):

| Secret | Currently Used By | DID Replacement |
|---|---|---|
| `CI_SUBMODULES_PAT` | All CI workflows (submodule checkout) | **GitHub OIDC** — exchange JWT for submodule access token at runtime |
| `APP_PRIVATE_KEY` | Gemini workflows (GitHub App auth) | **DID Auth** — derive ephemeral signing key from CI/CD DID path |
| `GEMINI_API_KEY` | Gemini workflows | **DID-issued VC** — access wrapped in Verifiable Credential with expiry |
| `GOOGLE_API_KEY` | Gemini workflows | **DID-issued VC** — same pattern |
| `VERCEL_*` | showcase-dapp deployment | **DID Auth** — OIDC federation with Vercel |
| `GCP_PROJECT_ID`, `GCP_SA_KEY` | gateway-cloud-run deployment | **Workload Identity Federation** — GCP natively supports OIDC |
| `NEXUS_ADMIN_API_TOKEN` | Admin API auth (conxian-nexus) | **DID Auth** — request signed with service DID key |
| `NOSTR_SECRET_KEY` | Nostr telemetry bridge | **DID-derived** — derive Nostr nsec from service DID path |

### 3.2 GitHub OIDC Integration (CI/CD)

GitHub Actions natively supports OIDC tokens. The workflow:

```
┌─────────────────┐     OIDC Token (JWT)     ┌──────────────────┐
│  GitHub Actions  │ ──────────────────────▶  │  OIDC Provider    │
│  (workflow run)   │                          │  (e.g., GCP/AWS)  │
└─────────────────┘                          └──────────────────┘
        │                                            │
        │ 1. Request OIDC token                       │ 2. Verify token
        │    with subject claim                        │    Validate `sub` claim
        │    `repo:Conxian-Labs/conxian-business:ref:*` │    matches allowed pattern
        ▼                                            ▼
┌─────────────────────────────────────────────────────────┐
│  3. Exchange OIDC token for short-lived credentials      │
│     - GCP: workload identity federation                  │
│     - Vercel: OIDC-compatible deployment token           │
│     - Submodule: PAT minted from OIDC-authed identity    │
└─────────────────────────────────────────────────────────┘
```

**Workflow YAML pattern** (replace static secrets):

```yaml
jobs:
  build:
    permissions:
      id-token: write  # Required for OIDC
      contents: read
    steps:
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: 'projects/.../locations/global/workloadIdentityPools/.../providers/...'
          service_account: 'nexus-ci@project.iam.gserviceaccount.com'
      
      - name: Authenticate to Vercel
        run: |
          # Use OIDC token to get Vercel deployment token
          oidc_token=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=vercel")
          vercel_token=$(curl -s -X POST https://api.vercel.com/v2/oidc/exchange-token \
            -H "Content-Type: application/json" \
            -d "{\"oidc_token\": \"$oidc_token\"}")
          echo "VERCEL_TOKEN=$vercel_token" >> $GITHUB_ENV
```

### 3.3 Service-to-Service DID Auth (conxian-nexus)

Services authenticate to each other using DID Auth (a.k.a. DIDComm v2 or SIOP v2):

```
1. Service A (did:key:z6Mk...a)
   ──▶ Generates ephemeral challenge: nonce + timestamp
   ──▶ Signs with its DID private key
   ──▶ Sends to Service B: { did: "...a", signature: "...", nonce: "..." }

2. Service B (did:key:z6Mk...b)
   ──▶ Resolves did:key:z6Mk...a → retrieves public key
   ──▶ Verifies signature
   ──▶ Issues PoP-bound session (per BOS_SOVEREIGN_ENTERPRISE_IDENTITY_ARCHITECTURE.md)
   ──▶ Returns session token

3. Service A
   ──▶ Uses session token for subsequent requests (15-min TTL)
```

**Rust implementation sketch** (for conxian-nexus):

```rust
use did_key::{DIDKey, KeyPair, DIDCore};
use std::str::FromStr;

/// DID-based identity for a nexus service
pub struct DidIdentity {
    pub did: String,
    key_pair: KeyPair,
}

impl DidIdentity {
    /// Create from derived key (BIP-32 path)
    pub fn from_seed(seed: &[u8], path: &str) -> Self {
        let key_pair = KeyPair::derive_from_seed(seed, path);
        let did = DIDKey::from_key_pair(&key_pair).to_did_string();
        Self { did, key_pair }
    }
    
    /// Sign a challenge for DID Auth
    pub fn sign_challenge(&self, nonce: &str, audience: &str) -> Vec<u8> {
        let payload = format!("{}:{}", nonce, audience);
        self.key_pair.sign(payload.as_bytes())
    }
    
    /// Verify a DID Auth response
    pub fn verify(did: &str, signature: &[u8], nonce: &str, audience: &str) -> bool {
        if let Ok(key_pair) = DIDKey::from_did_string(did) {
            let payload = format!("{}:{}", nonce, audience);
            key_pair.verify(payload.as_bytes(), signature).is_ok()
        } else {
            false
        }
    }
}

/// DID-Auth middleware for axum
pub async fn did_auth_middleware(
    req: Request<Body>,
    next: Next,
) -> Result<impl IntoResponse, StatusCode> {
    // Extract DID Auth headers
    let did = req.headers()
        .get("x-did")
        .and_then(|v| v.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;
    let signature = req.headers()
        .get("x-did-signature")
        .and_then(|v| v.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;
    let nonce = req.headers()
        .get("x-did-nonce")
        .and_then(|v| v.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;
    
    if !DidIdentity::verify(did, signature.as_bytes(), nonce, "nexus-api") {
        return Err(StatusCode::UNAUTHORIZED);
    }
    
    // Inject DID into request extensions
    req.extensions_mut().insert(did.to_string());
    Ok(next.run(req).await)
}
```

## 4. Governance Integration

### 4.1 Multisig DID for Admin Operations

Critical BOS operations require quorum approval. A multisig DID manages this:

```
did:key:z6Mk...gov  (Governance Multisig)
│
├── signer-1: did:key:z6Mk...ops1  (Operations Lead)
├── signer-2: did:key:z6Mk...ops2  (Security Lead)  
├── signer-3: did:key:z6Mk...ops3  (CTO)
│
├── Threshold: 2-of-3
├── Admin operations requiring multisig:
│   ├── Release approval (promotion from staged → main)
│   ├── Governance decision execution
│   ├── Treasury withdrawal (via Clarity contract)
│   ├── Emergency pause/unpause
│   └── DID key rotation
```

**On-chain Clarity binding** (for Stacks contract governance):

```clarity
;; @desc DID-based governance for contract admin operations
;; @param did-multisig - The governance multisig DID document hash
;; @param signers - List of authorized signer DIDs
;; @param threshold - Minimum number of signatures required

(define-map governance-dids
    { did-hash: (buff 32) }
    { signers: (list 10 (buff 64)), threshold: uint }
)

(define-public (execute-governance-action
    (action (buff 32))
    (signatures (list 10 { signer: (buff 64), sig: (buff 64) }))
)
    ;; Verify quorum
    (let ((valid-sigs (fold verify-did-signature signatures (list))))
        (asserts! (>= (len valid-sigs) threshold) err-u403)
        ;; Execute action
        ...
    )
)
```

### 4.2 DID-Based Recovery (W3C DID Recovery Spec)

Three recovery paths, ordered by decentralization:

| Type | Mechanism | Use Case | Latency |
|---|---|---|---|
| **A — Social ZKP** | N-of-M signers generate zero-knowledge proofs of identity | Lost operator device | 24h |
| **B — Deterministic Seedling** | Pre-computed recovery DID embedded in secure backup | Catastrophic key loss | 48h (time-lock) |
| **C — MPC-Mediated** | Multi-party computation shards distributed across signers | Enterprise key rotation | 1h |

## 5. Migration Path

### Phase 1 — Foundation (Current Sprint)
- [ ] Generate root DID seed for BOS development environment
- [ ] Implement `did_key` Rust crate integration in conxian-nexus
- [ ] Add DID Auth middleware for axum routes
- [ ] Create DID derivation CLI tool (`conxius-orbit did derive`)

### Phase 2 — CI/CD Integration (Next Sprint)
- [ ] Configure GitHub OIDC provider for GCP workload identity federation
- [ ] Replace `GCP_PROJECT_ID` / `GCP_SA_KEY` with OIDC auth in `gateway-cloud-run.yml`
- [ ] Replace `VERCEL_TOKEN` with OIDC exchange in `showcase-dapp-deploy.yml`
- [ ] Implement CI_SUBMODULES_PAT replacement via OIDC token exchange

### Phase 3 — Service Mesh (Sprint +2)
- [ ] Deploy DID Auth between all conxian-nexus internal services
- [ ] Migrate Nostr telemetry from static `NOSTR_SECRET_KEY` to DID-derived key
- [ ] Migrate Admin API from `NEXUS_ADMIN_API_TOKEN` to DID Auth
- [ ] Deploy governance multisig DID for admin operations

### Phase 4 — Production (Sprint +3)
- [ ] Deploy governance multisig Clarity contract on testnet
- [ ] Configure W3C DID Recovery paths
- [ ] Deprecate all long-lived GitHub secrets
- [ ] Audit: zero static secrets in CI/CD

## 6. Key Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Root DID key compromise | All derived keys compromised | HSM-backed root key; separate dev/test/prod roots |
| GitHub OIDC token leak | Temporary CI/CD access | OIDC tokens are short-lived (5 min); bound to workflow ref |
| DID method deprecation | `did:key` may be superseded | Abstract behind `DIDProvider` trait; add methods as needed |
| Key rotation complexity | N services need re-derivation | Derivation paths are deterministic; rotate root seed → all derived keys rotate |
| Audit gap | No on-chain DID registry | Use `did:stacks` for on-chain operations; hash DID docs to Clarity contracts |

## 7. Implementation References

- **W3C DID Core 1.0**: https://www.w3.org/TR/did-core/
- **did:key method**: https://w3c-ccg.github.io/did-method-key/
- **did:stacks method**: https://github.com/stacksgov/did-method-stacks
- **SIOP v2 (Self-Issued OpenID Provider)**: https://openid.net/specs/openid-connect-self-issued-v2-1_0.html
- **GitHub OIDC**: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
- **GCP Workload Identity Federation**: https://cloud.google.com/iam/docs/workload-identity-federation
- **W3C DID Recovery Spec**: https://w3c-ccg.github.io/did-recovery/
- **did_key Rust crate**: https://crates.io/crates/did_key
