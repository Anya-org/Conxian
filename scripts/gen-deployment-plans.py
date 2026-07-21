#!/usr/bin/env python3
"""Generate testnet and mainnet deployment plans from simnet plan."""
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
    "alex-swap-helper", "bns-stub", "math-lib-concentrated",
    "oracle-adapter-stub", "integration-fee-collector",
}
RELEASE_PATH_OVERRIDES = {
    "alex-adapter": "contracts/integrations/alex-adapter.clar",
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
    {"contract-id": f"{DEPLOYER}.conxian-protocol", "expected-sender": DEPLOYER,
     "method": "register-module", "parameters": [
         q('"alex-adapter"'), A(".alex-adapter")], "cost": INIT_CALL_COST},
]


def load_simnet_plan():
    with open("deployments/default.simnet-plan.yaml") as f:
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
                "path": RELEASE_PATH_OVERRIDES.get(name, tx["path"]),
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
    with open(path, "w") as f:
        yaml.dump(plan, f, default_flow_style=False, sort_keys=False,
                  width=120, allow_unicode=True)


def main():
    simnet = load_simnet_plan()
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
    save_plan(testnet, "deployments/full-system.testnet-plan.yaml")
    print("Generated: deployments/full-system.testnet-plan.yaml")

    # Mainnet
    mainnet = make_plan(contracts,
        network="mainnet",
        name="Full System Deployment - Mainnet (July 2026)",
        stacks_node="https://stacks-node-api.mainnet.stacks.co",
        cost=COST_MAINNET,
    )
    save_plan(mainnet, "deployments/full-system.mainnet-plan.yaml")
    print("Generated: deployments/full-system.mainnet-plan.yaml")

    print("Done!")


if __name__ == "__main__":
    main()
