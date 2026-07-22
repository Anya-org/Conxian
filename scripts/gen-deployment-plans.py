#!/usr/bin/env python3
"""Generate testnet and mainnet deployment plans from simnet plan."""
import argparse
from pathlib import Path
import tempfile

import yaml

DEPLOYER = "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P"
TEST_HELPERS = {
    "mock-circuit-breaker", "mock-csf-protocol",
    "mock-proposal", "mock-regulatory-adapter", "mock-token", "test-c4-helper",
}

# Keep regeneration scoped to the existing full-system release set. These
# simnet entries are useful locally but were not part of the checked-in
# testnet/mainnet plans; promoting them is a separate deployment decision.
RELEASE_PLAN_EXCLUSIONS = {
    "integration-fee-trait", "integration-registry", "alex-reserve-pool",
    "alex-swap-helper", "alex-adapter", "bns-stub", "math-lib-concentrated",
    "oracle-adapter-stub", "integration-fee-collector",
}

COST_TESTNET = 20000
COST_MAINNET = 50000


class QuotedString(str):
    """A string subclass that pyyaml will emit as a double-quoted YAML string."""
    pass


def _quoted_representer(dumper, data):
    return dumper.represent_scalar("tag:yaml.org,2002:str", data, style='"')


yaml.add_representer(QuotedString, _quoted_representer)


def q(s):
    """Wrap a string so pyyaml emits it with double quotes."""
    return QuotedString(s)


A = lambda s: q(f"'{DEPLOYER}{s}'")  # Single-quoted principal string, double-quoted in YAML

INIT_CALL_COST = 10000  # Fixed cost for each init call
INIT_CALLS = [
    {"contract-id": f"{DEPLOYER}.conxian-protocol", "expected-sender": DEPLOYER,
     "method": "set-owner", "parameters": [A("")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.operational-treasury", "expected-sender": DEPLOYER,
     "method": "initialize", "parameters": [A("")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.operational-treasury", "expected-sender": DEPLOYER,
     "method": "set-protocol-principal", "parameters": [
         q('"cxvg-token"'), A(".cxvg-token")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.operational-treasury", "expected-sender": DEPLOYER,
     "method": "set-protocol-principal", "parameters": [
         q('"regulatory-adapter"'), A(".regulatory-adapter")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.cxd-token", "expected-sender": DEPLOYER,
     "method": "add-minter", "parameters": [A(".bme-engine")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.cxd-token", "expected-sender": DEPLOYER,
     "method": "add-burner", "parameters": [A(".bme-engine")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.cxlp-token", "expected-sender": DEPLOYER,
     "method": "add-minter", "parameters": [A(".concentrated-liquidity-pool")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.cxlp-token", "expected-sender": DEPLOYER,
     "method": "add-burner", "parameters": [A(".concentrated-liquidity-pool")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.bme-engine", "expected-sender": DEPLOYER,
     "method": "add-activity-reporter",
     "parameters": [A(".swap-router")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.bme-engine", "expected-sender": DEPLOYER,
     "method": "add-activity-reporter",
     "parameters": [A(".lending-manager")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.risk-unit", "expected-sender": DEPLOYER,
     "method": "initialize", "parameters": [
         A(""), A(".agent-risk"), A(".dimensional-engine")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.risk-unit", "expected-sender": DEPLOYER,
     "method": "set-ops-engine",
     "parameters": [A(".ops-engine")], "cost": INIT_CALL_COST},
]


GENERATED_PLAN_NAMES = (
    "full-system.testnet-plan.yaml",
    "full-system.mainnet-plan.yaml",
)

REQUIRED_RELEASE_ORDER = (
    "sip-standards",
    "cxlp-token",
    "concentrated-liquidity-pool",
)


def load_simnet_plan(path):
    with path.open() as f:
        return yaml.safe_load(f)


def extract_contracts(simnet):
    """Extract contract-publish transactions, filtering out test helpers."""
    contracts = []
    seen = set()
    for batch in simnet["plan"]["batches"]:
        batch_contracts = []
        for tx in batch["transactions"]:
            if tx.get("transaction-type") != "emulated-contract-publish":
                continue
            name = tx["contract-name"]
            if name in RELEASE_PLAN_EXCLUSIONS:
                continue
            if name in TEST_HELPERS:
                continue
            if name in seen:
                print(f"WARNING: duplicate contract {name}, skipping")
                continue
            seen.add(name)
            batch_contracts.append({
                "contract-name": name,
                "path": tx["path"],
                "clarity-version": tx.get("clarity-version", 4),
            })
        if batch_contracts:
            contracts.append(batch_contracts)

    # Clarinet may emit a stale or differently grouped simnet plan after a
    # dependency is added. Normalize the release publication sequence without
    # disturbing the relative order of unrelated contracts. CXLP must be
    # published after its SIP-010 trait and before the CLP that imports it.
    locations = {}
    for batch_index, batch in enumerate(contracts):
        for item_index, item in enumerate(batch):
            name = item["contract-name"]
            if name in REQUIRED_RELEASE_ORDER:
                locations[name] = (batch_index, item_index)

    missing = [name for name in REQUIRED_RELEASE_ORDER if name not in locations]
    if missing:
        raise ValueError(
            "cannot establish required release dependency order; missing: "
            + ", ".join(missing)
        )

    first_batch_index, first_item_index = min(
        (locations[name] for name in REQUIRED_RELEASE_ORDER),
        key=lambda location: (location[0], location[1]),
    )
    required_items = {
        name: next(
            item
            for batch in contracts
            for item in batch
            if item["contract-name"] == name
        )
        for name in REQUIRED_RELEASE_ORDER
    }
    for batch in contracts:
        batch[:] = [
            item
            for item in batch
            if item["contract-name"] not in REQUIRED_RELEASE_ORDER
        ]

    insertion_index = sum(
        item["contract-name"] not in REQUIRED_RELEASE_ORDER
        for item in contracts[first_batch_index][:first_item_index]
    )
    contracts[first_batch_index][insertion_index:insertion_index] = [
        required_items[name] for name in REQUIRED_RELEASE_ORDER
    ]
    contracts = [batch for batch in contracts if batch]
    assert_release_dependency_order(contracts)

    return contracts


def assert_release_dependency_order(contracts):
    """Fail closed unless the release plans publish the required dependency edge."""
    names = [item["contract-name"] for batch in contracts for item in batch]
    positions = {}
    for name in REQUIRED_RELEASE_ORDER:
        try:
            positions[name] = names.index(name)
        except ValueError as exc:
            raise ValueError(
                "cannot establish required release dependency order; missing: "
                + name
            ) from exc

    if not (
        positions["sip-standards"]
        < positions["cxlp-token"]
        < positions["concentrated-liquidity-pool"]
    ):
        raise ValueError(
            "invalid release dependency order: expected "
            "sip-standards -> cxlp-token -> concentrated-liquidity-pool"
        )


def make_plan(contracts, network, name, stacks_node, cost):
    """Build deployment plan YAML structure."""
    assert_release_dependency_order(contracts)
    plan = {
        "id": 1,
        "name": name,
        "network": network,
        "stacks-node": stacks_node,
        "deployer": DEPLOYER,
        "plan": {"batches": []},
    }
    bid = 0
    for batch_contracts in contracts:
        transactions = []
        for c in batch_contracts:
            transactions.append({
                "contract-publish": {
                    "contract-name": c["contract-name"],
                    "expected-sender": DEPLOYER,
                    "cost": cost,
                    "path": c["path"],
                    "anchor-block-only": True,
                    "clarity-version": c["clarity-version"],
                    "epoch": 3.0,
                }
            })
        plan["plan"]["batches"].append({
            "id": bid,
            "transactions": transactions,
        })
        bid += 1

    # Add initialization batch (Phase N+1 — wiring)
    init_transactions = []
    for call in INIT_CALLS:
        init_transactions.append({"contract-call": call})
    plan["plan"]["batches"].append({
        "id": bid,
        "transactions": init_transactions,
    })

    return plan


def save_plan(plan, path):
    with path.open("w") as f:
        yaml.dump(plan, f, default_flow_style=False, sort_keys=False,
                  width=120, allow_unicode=True)


def generate_plans(simnet_path, output_dir):
    """Generate the release plans into ``output_dir`` and return their paths."""
    simnet = load_simnet_plan(simnet_path)
    contracts = extract_contracts(simnet)

    total = sum(len(b) for b in contracts)
    print(f"Extracted {total} production contracts in {len(contracts)} batches")

    # Testnet
    testnet = make_plan(contracts,
        network="testnet",
        name="Full System Deployment (July 2026)",
        stacks_node="https://api.testnet.hiro.so",
        cost=COST_TESTNET,
    )
    testnet_path = output_dir / GENERATED_PLAN_NAMES[0]
    save_plan(testnet, testnet_path)

    # Mainnet
    mainnet = make_plan(contracts,
        network="mainnet",
        name="Full System Deployment - Mainnet (July 2026)",
        stacks_node="https://stacks-node-api.mainnet.stacks.co",
        cost=COST_MAINNET,
    )
    mainnet_path = output_dir / GENERATED_PLAN_NAMES[1]
    save_plan(mainnet, mainnet_path)

    return (testnet_path, mainnet_path)


def main():
    parser = argparse.ArgumentParser(
        description="Generate or verify testnet and mainnet deployment plans."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="regenerate plans in a temporary directory and verify checked-in artifacts",
    )
    parser.add_argument(
        "--simnet-plan",
        type=Path,
        help="use a specific simnet plan as the generator source",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    deployments_dir = repo_root / "deployments"
    simnet_path = args.simnet_plan or deployments_dir / "default.simnet-plan.yaml"

    if args.check:
        with tempfile.TemporaryDirectory(prefix="conxian-release-plans-") as temp_dir:
            generated_paths = generate_plans(simnet_path, Path(temp_dir))
            mismatches = []
            for generated_path, name in zip(generated_paths, GENERATED_PLAN_NAMES):
                checked_in_path = deployments_dir / name
                if generated_path.read_bytes() != checked_in_path.read_bytes():
                    mismatches.append(name)

            if mismatches:
                print("Generator drift detected in: " + ", ".join(mismatches))
                return 1

            print("Checked-in release plans match a fresh generator run.")
            return 0

    generated_paths = generate_plans(simnet_path, deployments_dir)
    for generated_path in generated_paths:
        print(f"Generated: {generated_path.relative_to(repo_root)}")
    print("Done!")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
