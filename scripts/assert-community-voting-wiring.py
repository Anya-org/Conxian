#!/usr/bin/env python3
"""Assert that every supported fresh deployment wires community voting routes."""

import json
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
ROUTES = {
    "cxvg-token": ".cxvg-token",
    "regulatory-adapter": ".regulatory-adapter",
}
PUBLISHED_CONTRACTS = {"operational-treasury", "regulatory-adapter", "cxvg-token"}


def _transactions(path: Path):
    document = yaml.safe_load(path.read_text())
    batches = document.get("plan", {}).get("batches", [])
    if not batches:
        raise AssertionError(f"{path}: deployment plan has no batches")

    for batch_index, batch in enumerate(batches):
        for transaction in batch.get("transactions", []):
            if "transaction-type" in transaction:
                kind = transaction["transaction-type"]
                body = {key: value for key, value in transaction.items() if key != "transaction-type"}
            elif len(transaction) == 1:
                kind, body = next(iter(transaction.items()))
            else:
                raise AssertionError(f"{path}: unsupported transaction shape: {transaction}")
            yield batch_index, kind, body


def _clarity_string(value: str) -> str:
    if value.startswith('"') and value.endswith('"'):
        return json.loads(value)
    return value


def _principal_literal(value: str) -> str:
    if value.startswith("'") and value.endswith("'"):
        return value[1:-1]
    return value


def assert_release_wiring(path: Path, publish_kind: str, call_kind: str) -> None:
    transactions = list(_transactions(path))
    publish_batches = {
        body["contract-name"]: batch_index
        for batch_index, kind, body in transactions
        if kind == publish_kind and body.get("contract-name") in PUBLISHED_CONTRACTS
    }
    missing = PUBLISHED_CONTRACTS - publish_batches.keys()
    if missing:
        raise AssertionError(f"{path}: missing published contracts: {sorted(missing)}")

    calls = {}
    for batch_index, kind, body in transactions:
        if kind != call_kind or body.get("method") != "set-protocol-principal":
            continue
        contract_id = body.get("contract-id", "")
        if not contract_id.endswith(".operational-treasury"):
            continue
        parameters = body.get("parameters", [])
        if len(parameters) != 2:
            raise AssertionError(f"{path}: route call has unexpected parameters: {parameters}")
        route_name = _clarity_string(parameters[0])
        route_target = _principal_literal(parameters[1])
        if route_name not in ROUTES:
            continue
        if not route_target.endswith(ROUTES[route_name]):
            raise AssertionError(
                f"{path}: route {route_name} targets {route_target!r}, "
                f"expected a principal ending in {ROUTES[route_name]!r}"
            )
        if route_name in calls:
            raise AssertionError(f"{path}: duplicate route registration for {route_name}")
        calls[route_name] = batch_index

    if set(calls) != set(ROUTES):
        raise AssertionError(f"{path}: expected routes {sorted(ROUTES)}, found {sorted(calls)}")

    last_publish_batch = max(publish_batches.values())
    final_batch = max(batch_index for batch_index, _, _ in transactions)
    for route_name, call_batch in calls.items():
        if call_batch <= last_publish_batch:
            raise AssertionError(
                f"{path}: {route_name} wiring is in batch {call_batch}, "
                f"before final contract publication batch {last_publish_batch}"
            )
        if call_batch != final_batch:
            raise AssertionError(
                f"{path}: {route_name} wiring is not in the final post-deploy batch "
                f"({call_batch} != {final_batch})"
            )


def assert_simnet_bootstrap(path: Path) -> None:
    source = path.read_text()
    if "operational-treasury" not in source or "set-protocol-principal" not in source:
        raise AssertionError(f"{path}: missing operational-treasury route wiring")
    for route_name in ROUTES:
        expected = (
            f"Cl.stringAscii('{route_name}'), "
            f"Cl.contractPrincipal(deployer, '{route_name}')"
        )
        if expected not in source:
            raise AssertionError(f"{path}: missing fresh-simnet route {route_name}")


def main() -> None:
    # initSimnet regenerates the default publish plan and does not reliably
    # execute custom emulated post-deploy calls; tests/setup-test-env.ts is the
    # supported fresh-simnet wiring artifact. Release plans retain explicit
    # post-publication calls.
    assert_simnet_bootstrap(ROOT / "tests/setup-test-env.ts")
    assert_release_wiring(
        ROOT / "deployments/full-system.testnet-plan.yaml",
        "contract-publish",
        "contract-call",
    )
    assert_release_wiring(
        ROOT / "deployments/full-system.mainnet-plan.yaml",
        "contract-publish",
        "contract-call",
    )
    print("community-voting-engine deployment wiring: OK")


if __name__ == "__main__":
    main()
