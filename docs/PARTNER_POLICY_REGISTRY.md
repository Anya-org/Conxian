# Dormant Partner Policy Registry

## Scope

`contracts/integrations/partner-policy-registry.clar` implements the dormant
schema and control boundary approved for GitHub issue #528. It does not approve
or activate live partner payouts. It does not modify the legacy integration
collector, revenue distributor, or the existing 100%-protocol settlement path.

The contract stores only public-safe role bindings, numeric modes, burn-block
periods, and `(buff 32)` policy commitments. Raw KYC, tax, legal, sanctions,
jurisdiction, customer, and commercial-document data must remain at the
regulated edge or in an approved off-chain evidence system.

## Approved v1 Technical Defaults

| Field | Dormant v1 value |
|---|---|
| Asset/unit | Native STX in microSTX (`u1`) |
| Billing | Per-use (`u1`) |
| Fee base | Accepted, settled partnership fee (`u1`) |
| Split | Partner `floor(fee / 2)`; protocol receives the remainder |
| Protocol period | 4,320 burn blocks; not a promised calendar month |
| Corrections | Append-only before settlement; future-period compensating entries after settlement; no automatic clawback |
| Lifecycle | Immutable versioned policy commitments, revalidated fail-closed |

The split preview is read-only. No STX or SIP-010 transfer, custody, payout, or
settlement function exists in this contract.

## Policy Lifecycle

Policies are keyed by `(policy-id, version)` and move only:

```text
absent -> draft -> active -> revoked
```

- The first version is `u1`; later versions must be sequential.
- Effective ranges use `effective-start <= burn-block-height < effective-end`.
- A later version cannot overlap or move behind the preceding version's end.
- Publication writes the immutable policy hash, asset, billing/fee/correction
  modes, exact split, period length, and effective range.
- Activation and revocation update lifecycle markers only. Revoked records
  cannot be reactivated; a replacement is a new version.
- Validation rejects missing, draft, future, expired, revoked, mismatched, or
  unsupported policy combinations.

## Partner Lifecycle

Partner registrations bind an integration principal to distinct owner, payer,
beneficiary, and reporter roles plus one immutable policy reference/hash.

```text
absent -> registered -> active -> inactive or revoked
```

Inactive/revoked historical records are never reactivated. A beneficiary
change creates a new active registration version and marks the previous version
inactive, preserving both records for audit. The reporter has no mutation
authority and no API parameter through which to choose policy-controlled
beneficiary, asset, split, billing, policy, or jurisdiction values.

## Authorization

The contract resolves these principals from `operational-treasury`:

- `partner-policy-admin`: policy create/activate/revoke and partner revocation.
- `partner-policy-registrar`: partner registration, activation, beneficiary
  versioning, and deactivation.

The publish-time principal is a bootstrap administrator only while
`bootstrap-active` is true. `finalize-bootstrap-authorization` requires both
dynamic routes to exist, then permanently removes the fallback. Missing routes
after finalization deny authorization.

## Deployment and Legal Boundary

The source is registered in the active manifest and local simnet plan for
compilation and focused tests. It is explicitly excluded from generated
testnet/mainnet release plans. No deployment, production activation, legal
matrix, permitted jurisdiction, named commercial/legal owner, tax treatment,
beneficiary verification, signer SLA, or live payout route is claimed here.

Any future partnership settlement contract must be separately versioned,
snapshot this registry's exact policy/registration version during usage, and
revalidate the same immutable reference before settlement. That future work
must not reinterpret or modify the legacy `integration-fee-collector` route.
