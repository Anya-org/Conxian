#!/usr/bin/env python3
"""Generate testnet and mainnet deployment plans from simnet plan."""
import argparse
from pathlib import Path
import tempfile

try:
    import yaml
except ModuleNotFoundError as exc:
    raise SystemExit(
        "PyYAML==6.0.2 is required to generate deployment plans; "
        "install it with: python3 -m pip install --user --disable-pip-version-check 'PyYAML==6.0.2'"
    ) from exc

DEPLOYER = "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P"
TEST_HELPERS = {
    "mock-circuit-breaker", "mock-csf-protocol",
    "mock-proposal", "mock-regulatory-adapter", "mock-token",
    "mock-compoundable-vault", "mock-admin-forwarder", "test-c4-helper",
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
# The generated release plans wire only the canonical payment route. They do
# not publish prices/plans, configure bucket recipients, or register product
# consumers: those are governance decisions that require audited principals.
# The generic enterprise facade remains a test/integration boundary, not a
# trusted product consumer by default.
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
    {"contract-id": f"{DEPLOYER}.cxd-treasury", "expected-sender": DEPLOYER,
     "method": "set-authorized-principals", "parameters": [
         A(""), A(".revenue-distributor")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.cxd-treasury", "expected-sender": DEPLOYER,
     "method": "authorize-stx-source",
     "parameters": [A(".integration-fee-collector")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.cxd-treasury", "expected-sender": DEPLOYER,
     "method": "authorize-stx-source",
     "parameters": [A(".enterprise-subscription")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.revenue-distributor", "expected-sender": DEPLOYER,
     "method": "set-revenue-automation",
     "parameters": [A(".revenue-automation")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.revenue-distributor", "expected-sender": DEPLOYER,
     "method": "authorize-stx-source",
     "parameters": [A(".integration-fee-collector")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.revenue-distributor", "expected-sender": DEPLOYER,
     "method": "authorize-stx-source",
     "parameters": [A(".enterprise-subscription")], "cost": INIT_CALL_COST},
    {"contract-id": f"{DEPLOYER}.revenue-automation", "expected-sender": DEPLOYER,
     "method": "authorize-stx-source",
     "parameters": [A(".enterprise-subscription")], "cost": INIT_CALL_COST},
]


REQUIRED_ENTERPRISE_ROUTE_CALLS = [
    (f"{DEPLOYER}.cxd-treasury", "set-authorized-principals", [A(""), A(".revenue-distributor")]),
    (f"{DEPLOYER}.cxd-treasury", "authorize-stx-source", [A(".enterprise-subscription")]),
    (f"{DEPLOYER}.revenue-distributor", "set-revenue-automation", [A(".revenue-automation")]),
    (f"{DEPLOYER}.revenue-distributor", "authorize-stx-source", [A(".enterprise-subscription")]),
    (f"{DEPLOYER}.revenue-automation", "authorize-stx-source", [A(".enterprise-subscription")]),
]


def validate_enterprise_wiring(plan):
    """Fail fast if subscription routing drifts or governance is auto-wired."""
    calls = []
    for batch in plan["plan"]["batches"]:
        for tx in batch["transactions"]:
            call = tx.get("contract-call")
            if call:
                calls.append((call["contract-id"], call["method"], call["parameters"]))

    missing = [required for required in REQUIRED_ENTERPRISE_ROUTE_CALLS if required not in calls]
    if missing:
        raise ValueError(f"missing enterprise route wiring: {missing}")

    forbidden = {"publish-plan", "publish-feature", "register-consumer", "set-stx-bucket-recipient"}
    unexpected = [call for call in calls if call[1] in forbidden]
    if unexpected:
        raise ValueError(f"release plan must remain fail-closed for governance/product setup: {unexpected}")


GENERATED_PLAN_NAMES = (
    "full-system.testnet-plan.yaml",
    "full-system.mainnet-plan.yaml",
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
    return contracts


def make_plan(contracts, network, name, stacks_node, cost):
    """Build deployment plan YAML structure."""
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
    validate_enterprise_wiring(testnet)
    testnet_path = output_dir / GENERATED_PLAN_NAMES[0]
    save_plan(testnet, testnet_path)

    # Mainnet
    mainnet = make_plan(contracts,
        network="mainnet",
        name="Full System Deployment - Mainnet (July 2026)",
        stacks_node="https://stacks-node-api.mainnet.stacks.co",
        cost=COST_MAINNET,
    )
    validate_enterprise_wiring(mainnet)
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
