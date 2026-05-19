#!/usr/bin/env python3

from __future__ import annotations

import os
import sys
from pathlib import Path


TEMPLATE_FILES: dict[str, str] = {
    "local": "docker-compose.env.local.example",
    "testnet": "docker-compose.env.testnet.example",
    "mainnet": "docker-compose.env.mainnet.example",
}

ALIAS_FILE = "docker-compose.env.example"

EXPECTED_RPC_DEFAULTS: dict[str, dict[str, str]] = {
    "local": {
        "STACKS_NODE_RPC_URL": "http://host.docker.internal:3999",
        "STACKS_RPC_URL": "http://host.docker.internal:3999",
        "BITCOIN_RPC_URL": "http://host.docker.internal:18443",
    },
    "testnet": {
        "STACKS_NODE_RPC_URL": "https://api.testnet.hiro.so",
        "STACKS_RPC_URL": "https://api.testnet.hiro.so",
        "BITCOIN_RPC_URL": "https://bitcoin-testnet-rpc.publicnode.com",
    },
    "mainnet": {
        "STACKS_NODE_RPC_URL": "https://api.mainnet.hiro.so",
        "STACKS_RPC_URL": "https://api.mainnet.hiro.so",
        "BITCOIN_RPC_URL": "https://bitcoin-rpc.publicnode.com",
    },
}


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def normalize_rel_path(path: Path, root: Path) -> str:
    return os.path.relpath(path, root).replace(os.sep, "/")


def parse_env_assignments(path: Path, root: Path) -> tuple[dict[str, str], list[str]]:
    rel_path = normalize_rel_path(path, root)
    if not path.exists():
        return {}, [f"Missing required template: {rel_path}"]

    assignments: dict[str, str] = {}
    errors: list[str] = []

    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    for idx, raw_line in enumerate(lines, start=1):
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        if "=" not in raw_line:
            errors.append(f"{rel_path}:{idx}: expected KEY=VALUE assignment")
            continue

        key_part, value_part = raw_line.split("=", 1)
        key = key_part.strip()
        value = value_part.strip()

        if not key:
            errors.append(f"{rel_path}:{idx}: empty environment key")
            continue

        if key in assignments:
            errors.append(f"{rel_path}:{idx}: duplicate key: {key}")
            continue

        assignments[key] = value

    return assignments, errors


def verify_key_set_parity(lane_envs: dict[str, dict[str, str]]) -> list[str]:
    errors: list[str] = []
    lanes = sorted(lane_envs)
    if not lanes:
        return errors

    canonical_lane = lanes[0]
    canonical_keys = set(lane_envs[canonical_lane])

    for lane in lanes[1:]:
        keys = set(lane_envs[lane])
        if keys == canonical_keys:
            continue

        missing = sorted(canonical_keys - keys)
        extra = sorted(keys - canonical_keys)
        if missing:
            errors.append(
                f"{TEMPLATE_FILES[lane]} is missing keys present in {TEMPLATE_FILES[canonical_lane]}: {', '.join(missing)}"
            )
        if extra:
            errors.append(
                f"{TEMPLATE_FILES[lane]} has extra keys not present in {TEMPLATE_FILES[canonical_lane]}: {', '.join(extra)}"
            )

    return errors


def verify_lane_rpc_defaults(lane_envs: dict[str, dict[str, str]]) -> list[str]:
    errors: list[str] = []

    for lane, expected in EXPECTED_RPC_DEFAULTS.items():
        env_map = lane_envs.get(lane, {})
        for key, expected_value in expected.items():
            actual_value = env_map.get(key)
            if actual_value != expected_value:
                errors.append(
                    f"{TEMPLATE_FILES[lane]}: expected {key}={expected_value!r}, found {actual_value!r}"
                )

    return errors


def verify_no_cross_contamination(lane_envs: dict[str, dict[str, str]]) -> list[str]:
    errors: list[str] = []

    expected_values_by_lane = {
        lane: set(defaults.values()) for lane, defaults in EXPECTED_RPC_DEFAULTS.items()
    }

    for lane, env_map in lane_envs.items():
        forbidden_values: set[str] = set()
        for other_lane, values in expected_values_by_lane.items():
            if other_lane == lane:
                continue
            forbidden_values.update(values)

        for key, value in env_map.items():
            for forbidden in sorted(forbidden_values):
                if forbidden and forbidden in value:
                    errors.append(
                        f"{TEMPLATE_FILES[lane]}: {key} contains cross-lane RPC value {forbidden!r}"
                    )

    return errors


def verify_alias_matches_mainnet(alias_env: dict[str, str], mainnet_env: dict[str, str]) -> list[str]:
    errors: list[str] = []

    alias_keys = set(alias_env)
    mainnet_keys = set(mainnet_env)

    missing = sorted(mainnet_keys - alias_keys)
    extra = sorted(alias_keys - mainnet_keys)
    if missing:
        errors.append(
            f"{ALIAS_FILE} is missing keys present in {TEMPLATE_FILES['mainnet']}: {', '.join(missing)}"
        )
    if extra:
        errors.append(
            f"{ALIAS_FILE} has extra keys not present in {TEMPLATE_FILES['mainnet']}: {', '.join(extra)}"
        )

    for key in sorted(alias_keys & mainnet_keys):
        alias_value = alias_env[key]
        mainnet_value = mainnet_env[key]
        if alias_value != mainnet_value:
            errors.append(
                f"{ALIAS_FILE} assignment mismatch for {key}: {alias_value!r} != {mainnet_value!r}"
            )

    return errors


def main() -> int:
    root = repo_root()

    lane_envs: dict[str, dict[str, str]] = {}
    errors: list[str] = []

    for lane, rel_path in TEMPLATE_FILES.items():
        env_map, parse_errors = parse_env_assignments(root / rel_path, root)
        lane_envs[lane] = env_map
        errors.extend(parse_errors)

    alias_env, alias_parse_errors = parse_env_assignments(root / ALIAS_FILE, root)
    errors.extend(alias_parse_errors)

    if errors:
        print("Compose env template checks failed:\n")
        for err in errors:
            print(f"- {err}")
        return 1

    errors.extend(verify_key_set_parity(lane_envs))
    errors.extend(verify_lane_rpc_defaults(lane_envs))
    errors.extend(verify_no_cross_contamination(lane_envs))
    errors.extend(verify_alias_matches_mainnet(alias_env, lane_envs["mainnet"]))

    if errors:
        print("Compose env template checks failed:\n")
        for err in errors:
            print(f"- {err}")
        return 1

    print("Compose env template checks: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
