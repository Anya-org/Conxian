# Deployment evidence artifacts

The versioned manifest schema is `schema/v1/deployment-evidence.schema.json`.
The checked-in example is a shape/template only; its zero-value identifiers are
not deployment evidence and must be replaced with values captured from the
selected Hiro API.

The verifier checks the exact transaction IDs and contract principals declared
by the manifest. It requires the manifest to bind the evidence to the exact
network, deployer, deployed git commit, plan path, and plan SHA-256 supplied by
the manual verification workflow. It does not infer global nonexistence from a
missing result, and it never treats a deployment plan, workflow result, or
broadcast-only ID as proof.

There is no successful unbound or diagnostic invocation. The library and CLI
fail closed before any Hiro request unless all five binding values are present,
the deployer is network-correct, and the plan path is exactly the canonical
network path.

Run it with:

```bash
npx tsx scripts/verify-deployment-evidence.ts \
  --manifest path/to/deployment-evidence.json \
  --expected-network testnet \
  --expected-deployer ST... \
  --expected-git-commit <deployed-commit> \
  --expected-plan-path deployments/full-system.testnet-plan.yaml \
  --expected-plan-sha256 <plan-sha256> \
  --output deployment-evidence-report.json
```

The successful report says **declared evidence entries verified**. It does not
claim complete deployment-plan coverage unless a separate approved coverage
check proves every relevant publish and wiring transaction. Keep the manifest
and report with the release evidence artifact. The broadcast workflows upload
sanitized attempt metadata and the plan only; never include mnemonics, private
keys, API keys, raw environment values, or raw Clarinet session logs.
