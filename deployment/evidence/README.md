# Deployment evidence artifacts

The versioned manifest schema is `schema/v1/deployment-evidence.schema.json`.
The checked-in example is a shape/template only; its zero-value identifiers are
not deployment evidence and must be replaced with values captured from the
selected Hiro API.

The verifier checks the exact transaction IDs and contract principals declared
by the manifest. It does not infer global nonexistence from a missing result,
and it never treats a deployment plan, workflow result, or broadcast-only ID as
proof.

Run it with:

```bash
npx tsx scripts/verify-deployment-evidence.ts \
  --manifest path/to/deployment-evidence.json \
  --output deployment-evidence-report.json
```

The report is bounded to the documented transaction IDs and addresses. Keep
the manifest and report with the release evidence artifact, but never include
mnemonics, private keys, API keys, or raw environment values.
