#!/usr/bin/env python3
"""Verify generated repository facts in AGENTS.md against source artifacts."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import sys
import tomllib
from typing import Any

try:
    import yaml
except ImportError as error:  # pragma: no cover - exercised by CI configuration
    raise SystemExit(
        "PyYAML is required; install the pinned dependency with "
        "`python3 -m pip install PyYAML==6.0.2`."
    ) from error


BLOCK_START = "<!-- BEGIN GENERATED KNOWLEDGE-BASE FACTS -->"
BLOCK_END = "<!-- END GENERATED KNOWLEDGE-BASE FACTS -->"
EXPECTED_ALIAS_PATH = "contracts/math/concentrated-math.clar"
EXPECTED_ALIAS_NAMES = ("concentrated-math", "math-lib-concentrated")
CLP_V2_CONTRACTS = {
    "concentrated-math-v2": "contracts/math/concentrated-math-v2.clar",
    "concentrated-liquidity-pool-v2": "contracts/dex/concentrated-liquidity-pool-v2.clar",
}
PLAN_PATHS = (
    "deployments/full-system.testnet-plan.yaml",
    "deployments/full-system.mainnet-plan.yaml",
)


class KnowledgeBaseError(ValueError):
    """Raised when a source artifact violates a knowledge-base invariant."""


@dataclass(frozen=True)
class RepositoryFacts:
    physical_contracts: int
    manifest_entries: int
    test_sources: int
    release_publishes: int
    release_publish_batches: int
    release_total_batches: int
    release_calls: int


def _load_manifest(root: Path) -> dict[str, dict[str, Any]]:
    manifest_path = root / "Clarinet.toml"
    with manifest_path.open("rb") as manifest_file:
        document = tomllib.load(manifest_file)
    contracts = document.get("contracts")
    if not isinstance(contracts, dict):
        raise KnowledgeBaseError("Clarinet.toml does not contain a contracts table")
    return contracts


def _verify_manifest(root: Path, contracts: dict[str, dict[str, Any]]) -> tuple[int, int]:
    physical_paths = {
        path.relative_to(root).as_posix()
        for path in (root / "contracts").rglob("*.clar")
        if path.is_file()
    }
    manifest_paths: dict[str, list[str]] = {}
    for name, definition in contracts.items():
        source_path = definition.get("path")
        if not isinstance(source_path, str):
            raise KnowledgeBaseError(f"manifest contract {name} has no string path")
        manifest_paths.setdefault(source_path, []).append(name)

    missing_entries = sorted(physical_paths - set(manifest_paths))
    nonexistent_paths = sorted(set(manifest_paths) - physical_paths)
    if missing_entries or nonexistent_paths:
        details = []
        if missing_entries:
            details.append(f"physical contracts missing from manifest: {missing_entries}")
        if nonexistent_paths:
            details.append(f"manifest paths missing on disk: {nonexistent_paths}")
        raise KnowledgeBaseError("; ".join(details))

    aliases = {
        source_path: tuple(sorted(names))
        for source_path, names in manifest_paths.items()
        if len(names) > 1
    }
    expected_aliases = {EXPECTED_ALIAS_PATH: tuple(sorted(EXPECTED_ALIAS_NAMES))}
    if aliases != expected_aliases:
        raise KnowledgeBaseError(
            f"unexpected manifest aliases: expected {expected_aliases}, found {aliases}"
        )

    for contract_name, expected_path in CLP_V2_CONTRACTS.items():
        actual_path = contracts.get(contract_name, {}).get("path")
        if actual_path != expected_path:
            raise KnowledgeBaseError(
                f"active manifest must map {contract_name} to {expected_path}; found {actual_path!r}"
            )

    return len(physical_paths), len(contracts)


def _plan_facts(root: Path, relative_path: str) -> tuple[int, int, int, int]:
    plan_path = root / relative_path
    document = yaml.safe_load(plan_path.read_text(encoding="utf8"))
    try:
        batches = document["plan"]["batches"]
    except (KeyError, TypeError) as error:
        raise KnowledgeBaseError(f"{relative_path} has no plan.batches list") from error
    if not isinstance(batches, list):
        raise KnowledgeBaseError(f"{relative_path} plan.batches is not a list")

    publish_count = 0
    call_count = 0
    publish_batch_count = 0
    planned_contracts: dict[str, str] = {}
    for batch in batches:
        transactions = batch.get("transactions", [])
        batch_has_publish = False
        for transaction in transactions:
            if "contract-publish" in transaction:
                batch_has_publish = True
                publish_count += 1
                publish = transaction["contract-publish"]
                planned_contracts[publish.get("contract-name")] = publish.get("path")
            if "contract-call" in transaction:
                call_count += 1
        publish_batch_count += int(batch_has_publish)

    for contract_name, expected_path in CLP_V2_CONTRACTS.items():
        actual_path = planned_contracts.get(contract_name)
        if actual_path != expected_path:
            raise KnowledgeBaseError(
                f"{relative_path} must publish {contract_name} from {expected_path}; "
                f"found {actual_path!r}"
            )

    return publish_count, publish_batch_count, len(batches), call_count


def collect_facts(root: Path) -> RepositoryFacts:
    root = root.resolve()
    contracts = _load_manifest(root)
    physical_contracts, manifest_entries = _verify_manifest(root, contracts)
    test_sources = sum(
        1
        for pattern in ("*.test.ts", "*.spec.ts")
        for path in (root / "tests").rglob(pattern)
        if path.is_file()
    )

    plan_results = [_plan_facts(root, plan_path) for plan_path in PLAN_PATHS]
    if len(set(plan_results)) != 1:
        compared = dict(zip(PLAN_PATHS, plan_results, strict=True))
        raise KnowledgeBaseError(f"release-plan fact mismatch: {compared}")
    release_publishes, release_publish_batches, release_total_batches, release_calls = (
        plan_results[0]
    )

    return RepositoryFacts(
        physical_contracts=physical_contracts,
        manifest_entries=manifest_entries,
        test_sources=test_sources,
        release_publishes=release_publishes,
        release_publish_batches=release_publish_batches,
        release_total_batches=release_total_batches,
        release_calls=release_calls,
    )


def render_fact_block(facts: RepositoryFacts) -> str:
    return "\n".join(
        [
            BLOCK_START,
            (
                f"- **Contract inventory**: {facts.physical_contracts} physical "
                "`contracts/**/*.clar` files and "
                f"{facts.manifest_entries} active `Clarinet.toml` contract entries. "
                "The intentional `math-lib-concentrated` alias shares "
                "`contracts/math/concentrated-math.clar` with `concentrated-math`."
            ),
            (
                f"- **Test inventory**: {facts.test_sources} `*.test.ts`/`*.spec.ts` "
                "source files under `tests/`."
            ),
            (
                f"- **Production release plans**: {facts.release_publishes} contract "
                f"publishes in {facts.release_publish_batches} publish batches and "
                f"{facts.release_total_batches} total batches, including "
                f"{facts.release_calls} wiring/call transactions, in each checked-in "
                "testnet and mainnet plan."
            ),
            (
                "- **CLP V2 release inclusion**: `concentrated-math-v2` and "
                "`concentrated-liquidity-pool-v2` are present in the active manifest "
                "and both production release plans."
            ),
            BLOCK_END,
        ]
    )


def replace_fact_block(document: str, replacement: str) -> str:
    start = document.find(BLOCK_START)
    end = document.find(BLOCK_END)
    if start == -1 or end == -1 or end < start:
        raise KnowledgeBaseError(
            f"AGENTS.md must contain one block delimited by {BLOCK_START!r} and {BLOCK_END!r}"
        )
    if document.find(BLOCK_START, start + len(BLOCK_START)) != -1:
        raise KnowledgeBaseError("AGENTS.md contains multiple generated fact blocks")
    end += len(BLOCK_END)
    return document[:start] + replacement + document[end:]


def check_repository(root: Path, write: bool = False) -> list[str]:
    facts = collect_facts(root)
    agents_path = root / "AGENTS.md"
    current = agents_path.read_text(encoding="utf8")
    expected_block = render_fact_block(facts)
    expected_document = replace_fact_block(current, expected_block)
    if current == expected_document:
        return []
    if write:
        agents_path.write_text(expected_document, encoding="utf8")
        return []
    return [
        "AGENTS.md generated knowledge-base facts are stale; run "
        "`npm run update:knowledge-base` and review the diff"
    ]


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="verify without writing (default)")
    mode.add_argument("--write", action="store_true", help="update the generated AGENTS.md block")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="repository root")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        errors = check_repository(args.root.resolve(), write=args.write)
    except (KnowledgeBaseError, FileNotFoundError, tomllib.TOMLDecodeError, yaml.YAMLError) as error:
        print(f"Knowledge-base verification failed: {error}", file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(f"Knowledge-base verification failed: {error}", file=sys.stderr)
        return 1
    action = "updated" if args.write else "verified"
    print(f"Knowledge-base facts {action} successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
