#!/usr/bin/env python3
"""Semantic validation helpers for Conxian release deployment plans.

The active ``Clarinet.toml`` manifest is the source of contract names, source
paths, and declared dependency edges.  The generated release plans are a
separate, network-specific artifact and must prove that they contain the same
release set in a dependency-safe order.
"""

from __future__ import annotations

from dataclasses import dataclass
import heapq
from pathlib import Path
import re
from typing import Any, Iterable, Mapping
import tomllib


TEST_HELPERS = frozenset(
    {
        "mock-circuit-breaker",
        "mock-csf-protocol",
        "mock-proposal",
        "mock-regulatory-adapter",
        "mock-token",
        "mock-compoundable-vault",
        "mock-admin-forwarder",
        "mock-pox-adapter",
        "mock-pox-adapter-2",
        "mock-reward-token",
        "mock-settlement-intermediary",
        "mock-stacking-adapter",
        "mock-stacking-adapter-2",
        "test-c4-helper",
    }
)

# These simnet entries are intentionally not promoted to the checked-in
# testnet/mainnet release plans.  They remain an explicit classification, not
# an implicit "missing contract" exception.
RELEASE_PLAN_EXCLUSIONS = frozenset(
    {
        "integration-fee-trait",
        "integration-registry",
        "alex-reserve-pool",
        "alex-swap-helper",
        "alex-adapter",
        "bns-stub",
        "math-lib-concentrated",
        "oracle-adapter-stub",
        "integration-fee-collector",
        # Production fee-source authorization remains intentionally out of
        # release scope; #488 leaves this collector and its artifacts unchanged.
        "protocol-fee-collector",
    }
)

STACKS_PRINCIPAL_RE = re.compile(r"\b(?:SP|ST|SN|SM)[0-9A-Z]+\b")
STACKS_ADDRESS_RE = re.compile(r"^(?:ST|SP|SN|SM)[0-9A-HJ-KM-NP-TV-Z]{39}$")

EXPECTED_PLAN_IDS = {"testnet": 1, "mainnet": 1}
EXPECTED_PLAN_NAMES = {
    "testnet": "Full System Deployment (July 2026)",
    "mainnet": "Full System Deployment - Mainnet (July 2026)",
}
EXPECTED_STACKS_NODES = {
    "testnet": "https://api.testnet.hiro.so",
    "mainnet": "https://stacks-node-api.mainnet.stacks.co",
}
EXPECTED_PUBLISH_COSTS = {"testnet": 20000, "mainnet": 50000}
EXPECTED_CALL_COST = 10000


class ReleasePlanValidationError(ValueError):
    """Raised when a manifest or release-plan invariant is violated."""

    def __init__(self, errors: Iterable[str]):
        self.errors = tuple(str(error) for error in errors)
        super().__init__("\n".join(self.errors))


@dataclass(frozen=True)
class ContractDefinition:
    name: str
    source_path: str
    clarity_version: int
    depends_on: tuple[str, ...]


@dataclass(frozen=True)
class PublishTransaction:
    contract_name: str
    path: str
    clarity_version: int
    expected_sender: str
    cost: Any
    batch_index: int
    transaction_index: int
    ordinal: int


@dataclass(frozen=True)
class PlannedCall:
    contract_id: str
    contract_name: str
    method: str
    parameters: tuple[Any, ...]
    expected_sender: str
    cost: Any
    batch_index: int
    transaction_index: int
    ordinal: int


@dataclass(frozen=True)
class ParsedReleasePlan:
    path_label: str
    network: str
    plan_id: Any
    name: str
    stacks_node: str
    deployer: str
    batch_ids: tuple[Any, ...]
    publishes: tuple[PublishTransaction, ...]
    calls: tuple[PlannedCall, ...]
    topology: tuple[tuple[tuple[Any, ...], ...], ...]


def _raise_if_errors(errors: list[str]) -> None:
    if errors:
        raise ReleasePlanValidationError(errors)


def _is_mapping(value: Any) -> bool:
    return isinstance(value, Mapping)


def _is_positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _source_file(repo_root: Path, source_path: str) -> Path | None:
    """Return a safe source path, or ``None`` when it escapes/is absent."""

    try:
        candidate = (repo_root / source_path).resolve()
        candidate.relative_to(repo_root.resolve())
    except (OSError, ValueError):
        return None
    return candidate


def _find_cycle(graph: Mapping[str, Iterable[str]], nodes: Iterable[str]) -> tuple[str, ...] | None:
    """Find one deterministic dependency cycle and return its path."""

    visiting: set[str] = set()
    visited: set[str] = set()
    stack: list[str] = []
    stack_index: dict[str, int] = {}

    def visit(name: str) -> tuple[str, ...] | None:
        if name in visiting:
            start = stack_index[name]
            return tuple(stack[start:] + [name])
        if name in visited:
            return None

        visiting.add(name)
        stack_index[name] = len(stack)
        stack.append(name)
        for dependency in graph.get(name, ()):
            cycle = visit(dependency)
            if cycle is not None:
                return cycle
        stack.pop()
        stack_index.pop(name, None)
        visiting.remove(name)
        visited.add(name)
        return None

    for name in nodes:
        cycle = visit(name)
        if cycle is not None:
            return cycle
    return None


def load_clarinet_manifest(manifest_path: Path, repo_root: Path | None = None) -> dict[str, ContractDefinition]:
    """Load and semantically validate the active Clarinet manifest.

    ``Clarinet.complete.toml`` is intentionally never consulted.  The caller
    must pass the active ``Clarinet.toml`` path explicitly.
    """

    manifest_path = Path(manifest_path)
    repo_root = Path(repo_root) if repo_root is not None else manifest_path.parent
    if manifest_path.name != "Clarinet.toml":
        raise ReleasePlanValidationError(
            [
                "release validation must use the active Clarinet.toml manifest; "
                f"refusing {manifest_path.name}"
            ]
        )
    errors: list[str] = []

    try:
        with manifest_path.open("rb") as manifest_file:
            document = tomllib.load(manifest_file)
    except FileNotFoundError:
        raise ReleasePlanValidationError([f"active Clarinet manifest does not exist: {manifest_path}"])
    except tomllib.TOMLDecodeError as exc:
        raise ReleasePlanValidationError([f"active Clarinet manifest is invalid TOML: {manifest_path}: {exc}"])

    contracts_value = document.get("contracts")
    if not _is_mapping(contracts_value):
        raise ReleasePlanValidationError([f"active Clarinet manifest has no [contracts] table: {manifest_path}"])

    contracts: dict[str, ContractDefinition] = {}
    for name, raw_definition in contracts_value.items():
        if not isinstance(name, str) or not name:
            errors.append(f"active Clarinet manifest has an invalid contract name: {name!r}")
            continue
        if not _is_mapping(raw_definition):
            errors.append(f"contract {name!r} in Clarinet.toml must be a table")
            continue

        source_path = raw_definition.get("path")
        if not isinstance(source_path, str) or not source_path:
            errors.append(f"contract {name} has no non-empty source path in Clarinet.toml")
            continue
        source_file = _source_file(repo_root, source_path)
        if source_file is None:
            errors.append(f"contract {name} source path is outside the repository: {source_path}")
        elif not source_file.is_file():
            errors.append(f"contract {name} source file does not exist: {source_path}")

        clarity_version = raw_definition.get("clarity-version", 4)
        if not isinstance(clarity_version, int):
            errors.append(f"contract {name} clarity-version must be an integer")
            clarity_version = 4

        dependencies = raw_definition.get("depends_on", [])
        if not isinstance(dependencies, list) or not all(isinstance(item, str) and item for item in dependencies):
            errors.append(f"contract {name} depends_on must be a list of non-empty contract names")
            dependencies = []
        if len(set(dependencies)) != len(dependencies):
            errors.append(f"contract {name} declares a duplicate dependency in depends_on")

        contracts[name] = ContractDefinition(
            name=name,
            source_path=source_path,
            clarity_version=clarity_version,
            depends_on=tuple(dependencies),
        )

    for name, definition in contracts.items():
        for dependency in definition.depends_on:
            if dependency not in contracts:
                errors.append(
                    f"contract {name} declares unknown dependency {dependency}; "
                    "add it to the active Clarinet.toml manifest or remove the edge"
                )

    graph = {name: definition.depends_on for name, definition in contracts.items()}
    cycle = _find_cycle(graph, contracts)
    if cycle is not None:
        errors.append("dependency cycle in active Clarinet.toml: " + " -> ".join(cycle))

    _raise_if_errors(errors)
    return contracts


def release_contract_names(contracts: Mapping[str, ContractDefinition]) -> set[str]:
    """Return the active release set after explicit exclusions/helpers."""

    return set(contracts) - TEST_HELPERS - RELEASE_PLAN_EXCLUSIONS


def _require_simnet_batches(document: Mapping[str, Any], path_label: str) -> list[Mapping[str, Any]]:
    plan = document.get("plan")
    if not _is_mapping(plan) or not isinstance(plan.get("batches"), list):
        raise ReleasePlanValidationError([f"{path_label}: simnet plan.batches must be a list"])
    return plan["batches"]


def extract_simnet_publish_batches(document: Mapping[str, Any], path_label: str = "default.simnet-plan.yaml") -> list[list[PublishTransaction]]:
    """Extract simnet publishes and reject duplicate/malformed entries."""

    errors: list[str] = []
    batches: list[list[PublishTransaction]] = []
    seen: dict[str, tuple[int, int]] = {}
    ordinal = 0

    for batch_index, raw_batch in enumerate(_require_simnet_batches(document, path_label)):
        if not _is_mapping(raw_batch):
            errors.append(f"{path_label}: batch {batch_index} must be a mapping")
            continue
        raw_transactions = raw_batch.get("transactions")
        if not isinstance(raw_transactions, list):
            errors.append(f"{path_label}: batch {batch_index}.transactions must be a list")
            continue

        publish_batch: list[PublishTransaction] = []
        for transaction_index, raw_transaction in enumerate(raw_transactions):
            if not _is_mapping(raw_transaction):
                errors.append(
                    f"{path_label}: batch {batch_index} transaction {transaction_index} must be a mapping"
                )
                continue
            if raw_transaction.get("transaction-type") != "emulated-contract-publish":
                continue

            name = raw_transaction.get("contract-name")
            source_path = raw_transaction.get("path")
            if not isinstance(name, str) or not name:
                errors.append(
                    f"{path_label}: batch {batch_index} transaction {transaction_index} has no contract-name"
                )
                continue
            if not isinstance(source_path, str) or not source_path:
                errors.append(
                    f"{path_label}: {name} at batch {batch_index} transaction {transaction_index} has no path"
                )
                continue
            if name in seen:
                prior_batch, prior_transaction = seen[name]
                errors.append(
                    f"{path_label}: duplicate contract publish {name} at batch {batch_index} transaction "
                    f"{transaction_index}; first published at batch {prior_batch} transaction {prior_transaction}"
                )
                continue

            clarity_version = raw_transaction.get("clarity-version", 4)
            if not isinstance(clarity_version, int):
                errors.append(
                    f"{path_label}: {name} clarity-version must be an integer at batch "
                    f"{batch_index} transaction {transaction_index}"
                )
                clarity_version = 4

            seen[name] = (batch_index, transaction_index)
            publish_batch.append(
                PublishTransaction(
                    contract_name=name,
                    path=source_path,
                    clarity_version=clarity_version,
                    expected_sender="",
                    cost=None,
                    batch_index=batch_index,
                    transaction_index=transaction_index,
                    ordinal=ordinal,
                )
            )
            ordinal += 1

        if publish_batch:
            batches.append(publish_batch)

    _raise_if_errors(errors)
    return batches


def validate_simnet_source(
    document: Mapping[str, Any],
    contracts: Mapping[str, ContractDefinition],
    repo_root: Path,
    path_label: str = "default.simnet-plan.yaml",
    *,
    allow_stale_clarity_versions: bool = False,
) -> list[list[PublishTransaction]]:
    """Validate simnet-to-manifest mapping and return release-filtered batches.

    The pinned Clarinet SDK can rewrite the local simnet artifact with stale
    Clarity 1 metadata (and the existing community-voting Clarity 3
    compatibility entry) even when the active manifest is Clarity 4. Callers
    may opt into that narrowly scoped compatibility mode for the simnet source
    only; generated release plans remain strictly validated against the active
    manifest.
    """

    batches = extract_simnet_publish_batches(document, path_label)
    errors: list[str] = []
    present_names: set[str] = set()

    for batch in batches:
        for entry in batch:
            present_names.add(entry.contract_name)
            definition = contracts.get(entry.contract_name)
            if definition is None:
                errors.append(
                    f"{path_label}: unknown contract publish {entry.contract_name} at batch "
                    f"{entry.batch_index} transaction {entry.transaction_index}; add it to Clarinet.toml "
                    "or classify it explicitly as a helper/exclusion"
                )
                continue
            if entry.path != definition.source_path:
                errors.append(
                    f"{path_label}: contract {entry.contract_name} path {entry.path} does not match "
                    f"active Clarinet.toml path {definition.source_path}"
                )
            if (
                entry.clarity_version != definition.clarity_version
                and not (
                    allow_stale_clarity_versions
                    and (
                        entry.clarity_version == 1
                        or (
                            entry.clarity_version == 3
                            and entry.contract_name == "community-voting-engine"
                        )
                    )
                )
            ):
                errors.append(
                    f"{path_label}: contract {entry.contract_name} clarity-version {entry.clarity_version} "
                    f"does not match active Clarinet.toml value {definition.clarity_version}"
                )
            source_file = _source_file(repo_root, entry.path)
            if source_file is None or not source_file.is_file():
                errors.append(
                    f"{path_label}: contract {entry.contract_name} references missing source file {entry.path}"
                )

    release_names = release_contract_names(contracts)
    for name in sorted(release_names - present_names):
        errors.append(
            f"{path_label}: active release contract {name} is missing from the simnet source plan; "
            "only explicit helper/exclusion classifications may be absent"
        )

    _raise_if_errors(errors)

    # Filter only after validating the complete source plan.  This keeps a
    # production contract from disappearing silently behind the release filter.
    return [
        [entry for entry in batch if entry.contract_name not in TEST_HELPERS | RELEASE_PLAN_EXCLUSIONS]
        for batch in batches
        if any(entry.contract_name not in TEST_HELPERS | RELEASE_PLAN_EXCLUSIONS for entry in batch)
    ]


def dependency_ordered_batches(
    source_batches: list[list[PublishTransaction]],
    contracts: Mapping[str, ContractDefinition],
) -> list[list[PublishTransaction]]:
    """Topologically order release publishes with original order as tie-breaker.

    The original filtered batch sizes are retained, so the release keeps its
    existing nine publish batches and final wiring batch.  Only the publish
    transaction assignment/order changes as required to satisfy the active
    manifest's dependency edges.
    """

    flattened = [entry for batch in source_batches for entry in batch]
    by_name = {entry.contract_name: entry for entry in flattened}
    release_names = release_contract_names(contracts)
    errors: list[str] = []

    for name in sorted(release_names - set(by_name)):
        errors.append(f"release source is missing active contract {name}")

    graph: dict[str, list[str]] = {name: [] for name in by_name}
    indegree = {name: 0 for name in by_name}
    for name in by_name:
        definition = contracts[name]
        for dependency in definition.depends_on:
            if dependency in TEST_HELPERS:
                errors.append(
                    f"release contract {name} depends on test helper {dependency}, which is intentionally excluded"
                )
            elif dependency in RELEASE_PLAN_EXCLUSIONS:
                errors.append(
                    f"release contract {name} depends on explicitly excluded contract {dependency}; "
                    "the exclusion must be resolved before release"
                )
            elif dependency not in by_name:
                errors.append(
                    f"release contract {name} is missing dependency {dependency}; "
                    "the dependency is active but absent from the release source"
                )
            else:
                graph[dependency].append(name)
                indegree[name] += 1

    _raise_if_errors(errors)

    heap: list[tuple[int, str]] = []
    for name, degree in indegree.items():
        if degree == 0:
            heapq.heappush(heap, (by_name[name].ordinal, name))

    ordered_names: list[str] = []
    while heap:
        _, name = heapq.heappop(heap)
        ordered_names.append(name)
        for dependent in sorted(graph[name], key=lambda item: (by_name[item].ordinal, item)):
            indegree[dependent] -= 1
            if indegree[dependent] == 0:
                heapq.heappush(heap, (by_name[dependent].ordinal, dependent))

    if len(ordered_names) != len(flattened):
        cycle_graph = {name: [dependency for dependency in contracts[name].depends_on if dependency in by_name] for name in by_name}
        cycle = _find_cycle(cycle_graph, sorted(by_name, key=lambda item: by_name[item].ordinal))
        detail = " -> ".join(cycle) if cycle else "unresolved cycle"
        raise ReleasePlanValidationError([f"dependency cycle prevents release ordering: {detail}"])

    ordered_entries = [by_name[name] for name in ordered_names]
    batch_sizes = [len(batch) for batch in source_batches]
    result: list[list[PublishTransaction]] = []
    cursor = 0
    for size in batch_sizes:
        result.append(ordered_entries[cursor : cursor + size])
        cursor += size
    return result


def _normalize_principals(value: Any) -> Any:
    if isinstance(value, str):
        return STACKS_PRINCIPAL_RE.sub("<principal>", value)
    if isinstance(value, list):
        return tuple(_normalize_principals(item) for item in value)
    if isinstance(value, tuple):
        return tuple(_normalize_principals(item) for item in value)
    if isinstance(value, dict):
        return tuple(sorted((key, _normalize_principals(item)) for key, item in value.items()))
    return value


def _require_release_batches(document: Mapping[str, Any], path_label: str) -> list[Mapping[str, Any]]:
    plan = document.get("plan")
    if not _is_mapping(plan) or not isinstance(plan.get("batches"), list):
        raise ReleasePlanValidationError([f"{path_label}: release plan.plan.batches must be a list"])
    return plan["batches"]


def parse_release_plan(document: Mapping[str, Any], path_label: str) -> ParsedReleasePlan:
    """Parse release transactions and create a normalized topology."""

    errors: list[str] = []
    network = document.get("network")
    plan_id = document.get("id")
    plan_name = document.get("name")
    stacks_node = document.get("stacks-node")
    deployer = document.get("deployer")
    if not isinstance(network, str) or not network:
        errors.append(f"{path_label}: release plan network is missing")
        network = ""
    if not _is_positive_int(plan_id):
        errors.append(f"{path_label}: release plan id must be a positive integer")
        plan_id = None
    if not isinstance(plan_name, str) or not plan_name:
        errors.append(f"{path_label}: release plan name is missing")
        plan_name = ""
    if not isinstance(stacks_node, str) or not stacks_node:
        errors.append(f"{path_label}: release plan stacks-node is missing")
        stacks_node = ""
    if not isinstance(deployer, str) or not deployer:
        errors.append(f"{path_label}: release plan deployer is missing")
        deployer = ""
    elif STACKS_ADDRESS_RE.fullmatch(deployer) is None:
        errors.append(
            f"{path_label}: release plan deployer must be a 41-character Stacks address "
            "with an ST/SP/SN/SM prefix; signer authorization is validated separately"
        )

    publishes: list[PublishTransaction] = []
    calls: list[PlannedCall] = []
    batch_ids: list[Any] = []
    topology: list[tuple[tuple[Any, ...], ...]] = []
    ordinal = 0

    for batch_index, raw_batch in enumerate(_require_release_batches(document, path_label)):
        batch_ids.append(None)
        if not _is_mapping(raw_batch):
            errors.append(f"{path_label}: batch {batch_index} must be a mapping")
            continue
        raw_batch_id = raw_batch.get("id")
        batch_ids[-1] = raw_batch_id
        if "id" not in raw_batch:
            errors.append(f"{path_label}: batch {batch_index} is missing required id")
        elif not _is_nonnegative_int(raw_batch_id):
            errors.append(f"{path_label}: batch {batch_index} id must be a non-negative integer")
        raw_transactions = raw_batch.get("transactions")
        if not isinstance(raw_transactions, list):
            errors.append(f"{path_label}: batch {batch_index}.transactions must be a list")
            continue

        normalized_batch: list[tuple[Any, ...]] = []
        for transaction_index, raw_transaction in enumerate(raw_transactions):
            if not _is_mapping(raw_transaction):
                errors.append(
                    f"{path_label}: batch {batch_index} transaction {transaction_index} must be a mapping"
                )
                continue

            has_publish = "contract-publish" in raw_transaction
            has_call = "contract-call" in raw_transaction
            if has_publish == has_call:
                errors.append(
                    f"{path_label}: batch {batch_index} transaction {transaction_index} must contain exactly "
                    "one contract-publish or contract-call"
                )
                continue

            if has_publish:
                body = raw_transaction.get("contract-publish")
                if not _is_mapping(body):
                    errors.append(
                        f"{path_label}: batch {batch_index} transaction {transaction_index} contract-publish must be a mapping"
                    )
                    continue
                contract_name = body.get("contract-name")
                source_path = body.get("path")
                if not isinstance(contract_name, str) or not contract_name:
                    errors.append(
                        f"{path_label}: batch {batch_index} transaction {transaction_index} publish has no contract-name"
                    )
                    continue
                if not isinstance(source_path, str) or not source_path:
                    errors.append(f"{path_label}: release publish {contract_name} has no source path")
                    continue
                expected_sender = body.get("expected-sender")
                if not isinstance(expected_sender, str) or not expected_sender:
                    errors.append(
                        f"{path_label}: release publish {contract_name} expected-sender must be a non-empty string"
                    )
                    expected_sender = ""
                cost = body.get("cost")
                if not _is_positive_int(cost):
                    errors.append(
                        f"{path_label}: release publish {contract_name} cost must be a positive integer"
                    )
                clarity_version = body.get("clarity-version", 4)
                if not isinstance(clarity_version, int):
                    errors.append(f"{path_label}: release publish {contract_name} clarity-version must be an integer")
                    clarity_version = 4
                publishes.append(
                    PublishTransaction(
                        contract_name=contract_name,
                        path=source_path,
                        clarity_version=clarity_version,
                        expected_sender=expected_sender,
                        cost=cost,
                        batch_index=batch_index,
                        transaction_index=transaction_index,
                        ordinal=ordinal,
                    )
                )
                normalized_batch.append(
                    (
                        "publish",
                        contract_name,
                        source_path,
                        clarity_version,
                        bool(body.get("anchor-block-only", False)),
                        body.get("epoch"),
                        _normalize_principals(expected_sender),
                        cost,
                    )
                )
            else:
                body = raw_transaction.get("contract-call")
                if not _is_mapping(body):
                    errors.append(
                        f"{path_label}: batch {batch_index} transaction {transaction_index} contract-call must be a mapping"
                    )
                    continue
                contract_id = body.get("contract-id")
                method = body.get("method")
                parameters = body.get("parameters", [])
                if not isinstance(contract_id, str) or not contract_id:
                    errors.append(f"{path_label}: release call has no contract-id")
                    continue
                if not isinstance(method, str) or not method:
                    errors.append(f"{path_label}: release call {contract_id} has no method")
                    continue
                expected_sender = body.get("expected-sender")
                if not isinstance(expected_sender, str) or not expected_sender:
                    errors.append(
                        f"{path_label}: release call {contract_id}.{method} expected-sender must be a non-empty string"
                    )
                    expected_sender = ""
                cost = body.get("cost")
                if not _is_positive_int(cost):
                    errors.append(
                        f"{path_label}: release call {contract_id}.{method} cost must be a positive integer"
                    )
                if not isinstance(parameters, list):
                    errors.append(f"{path_label}: release call {contract_id}.{method} parameters must be a list")
                    parameters = []
                contract_name = contract_id.rsplit(".", 1)[-1]
                if contract_name == contract_id:
                    errors.append(
                        f"{path_label}: release call contract-id {contract_id} must include an address and contract name"
                    )
                calls.append(
                    PlannedCall(
                        contract_id=contract_id,
                        contract_name=contract_name,
                        method=method,
                        parameters=tuple(parameters),
                        expected_sender=expected_sender,
                        cost=cost,
                        batch_index=batch_index,
                        transaction_index=transaction_index,
                        ordinal=ordinal,
                    )
                )
                normalized_batch.append(
                    (
                        "call",
                        _normalize_principals(contract_id),
                        method,
                        _normalize_principals(parameters),
                        _normalize_principals(expected_sender),
                        cost,
                    )
                )
            ordinal += 1
        topology.append(tuple(normalized_batch))

    valid_batch_ids = all(_is_nonnegative_int(batch_id) for batch_id in batch_ids)
    if valid_batch_ids:
        duplicate_batch_ids = sorted(
            batch_id
            for batch_id in set(batch_ids)
            if batch_ids.count(batch_id) > 1
        )
        if duplicate_batch_ids:
            errors.append(
                f"{path_label}: batch ids must be unique; duplicate ids: "
                + ", ".join(str(batch_id) for batch_id in duplicate_batch_ids)
            )
        expected_batch_ids = tuple(range(len(batch_ids)))
        if tuple(batch_ids) != expected_batch_ids:
            errors.append(
                f"{path_label}: batch ids must be the deterministic sequence "
                f"0..{len(batch_ids) - 1}; found {batch_ids!r}"
            )

    if not publishes:
        errors.append(f"{path_label}: release plan contains no contract-publish transactions")
    if publishes:
        last_publish_ordinal = max(entry.ordinal for entry in publishes)
        early_calls = [entry for entry in calls if entry.ordinal < last_publish_ordinal]
        for call in early_calls:
            errors.append(
                f"{path_label}: contract call {call.contract_name}.{call.method} at batch "
                f"{call.batch_index} transaction {call.transaction_index} occurs before the final publish"
            )

    _raise_if_errors(errors)
    return ParsedReleasePlan(
        path_label=path_label,
        network=network,
        plan_id=plan_id,
        name=plan_name,
        stacks_node=stacks_node,
        deployer=deployer,
        batch_ids=tuple(batch_ids),
        publishes=tuple(publishes),
        calls=tuple(calls),
        topology=tuple(topology),
    )


def validate_release_plan(
    parsed: ParsedReleasePlan,
    contracts: Mapping[str, ContractDefinition],
    repo_root: Path,
    expected_network: str | None = None,
) -> ParsedReleasePlan:
    """Validate one generated release plan against the active manifest."""

    errors: list[str] = []
    if expected_network is not None and parsed.network != expected_network:
        errors.append(
            f"{parsed.path_label}: network is {parsed.network!r}, expected {expected_network!r}"
        )

    metadata_network = parsed.network if parsed.network in EXPECTED_PLAN_IDS else expected_network
    if metadata_network in EXPECTED_PLAN_IDS:
        expected_plan_id = EXPECTED_PLAN_IDS[metadata_network]
        if parsed.plan_id != expected_plan_id:
            errors.append(
                f"{parsed.path_label}: plan id is {parsed.plan_id!r}, expected {expected_plan_id} "
                f"for {metadata_network}"
            )
        expected_name = EXPECTED_PLAN_NAMES[metadata_network]
        if parsed.name != expected_name:
            errors.append(
                f"{parsed.path_label}: plan name is {parsed.name!r}, expected {expected_name!r}"
            )
        expected_node = EXPECTED_STACKS_NODES[metadata_network]
        if parsed.stacks_node != expected_node:
            errors.append(
                f"{parsed.path_label}: stacks-node is {parsed.stacks_node!r}, expected "
                f"{expected_node!r} for {metadata_network}"
            )
    else:
        errors.append(
            f"{parsed.path_label}: network {parsed.network!r} is not a supported testnet/mainnet release network"
        )

    if STACKS_ADDRESS_RE.fullmatch(parsed.deployer) is None:
        errors.append(
            f"{parsed.path_label}: deployer {parsed.deployer!r} is not a supported ST/SP/SN/SM "
            "Stacks address; this syntax check does not authorize a signer"
        )

    positions: dict[str, tuple[int, int]] = {}
    duplicate_positions: dict[str, list[tuple[int, int]]] = {}
    for entry in parsed.publishes:
        position = (entry.batch_index, entry.transaction_index)
        duplicate_positions.setdefault(entry.contract_name, []).append(position)
        if entry.expected_sender != parsed.deployer:
            errors.append(
                f"{parsed.path_label}: publish {entry.contract_name} at batch {entry.batch_index} "
                f"transaction {entry.transaction_index} expected-sender {entry.expected_sender!r} "
                f"does not equal plan deployer {parsed.deployer!r}"
            )
        expected_publish_cost = EXPECTED_PUBLISH_COSTS.get(parsed.network)
        if expected_publish_cost is not None and entry.cost != expected_publish_cost:
            errors.append(
                f"{parsed.path_label}: publish {entry.contract_name} at batch {entry.batch_index} "
                f"transaction {entry.transaction_index} cost {entry.cost!r} does not match the "
                f"{parsed.network} publish cost {expected_publish_cost}"
            )
        if entry.contract_name in positions:
            continue
        positions[entry.contract_name] = position

        definition = contracts.get(entry.contract_name)
        if definition is None:
            errors.append(
                f"{parsed.path_label}: unknown contract publish {entry.contract_name} at batch "
                f"{entry.batch_index} transaction {entry.transaction_index}; it is not in active Clarinet.toml"
            )
            continue
        if entry.contract_name in TEST_HELPERS:
            errors.append(
                f"{parsed.path_label}: contract {entry.contract_name} is a test helper and is intentionally excluded"
            )
        elif entry.contract_name in RELEASE_PLAN_EXCLUSIONS:
            errors.append(
                f"{parsed.path_label}: contract {entry.contract_name} is explicitly excluded from release plans"
            )
        if entry.path != definition.source_path:
            errors.append(
                f"{parsed.path_label}: contract {entry.contract_name} path {entry.path} does not match "
                f"active Clarinet.toml path {definition.source_path}"
            )
        if entry.clarity_version != definition.clarity_version:
            errors.append(
                f"{parsed.path_label}: contract {entry.contract_name} clarity-version {entry.clarity_version} "
                f"does not match active Clarinet.toml value {definition.clarity_version}"
            )
        source_file = _source_file(repo_root, entry.path)
        if source_file is None or not source_file.is_file():
            errors.append(
                f"{parsed.path_label}: contract {entry.contract_name} references missing source file {entry.path}"
            )

    for name, positions_for_name in sorted(duplicate_positions.items()):
        if len(positions_for_name) > 1:
            errors.append(
                f"{parsed.path_label}: duplicate contract publish {name} at "
                + ", ".join(f"batch {batch} transaction {transaction}" for batch, transaction in positions_for_name)
            )

    expected_names = release_contract_names(contracts)
    for name in sorted(expected_names - set(positions)):
        errors.append(
            f"{parsed.path_label}: active release contract {name} is missing from the generated plan"
        )

    for call in parsed.calls:
        if call.expected_sender != parsed.deployer:
            errors.append(
                f"{parsed.path_label}: call {call.contract_id}.{call.method} at batch {call.batch_index} "
                f"transaction {call.transaction_index} expected-sender {call.expected_sender!r} "
                f"does not equal plan deployer {parsed.deployer!r}"
            )
        if call.cost != EXPECTED_CALL_COST:
            errors.append(
                f"{parsed.path_label}: call {call.contract_id}.{call.method} at batch {call.batch_index} "
                f"transaction {call.transaction_index} cost {call.cost!r} does not match the "
                f"release call cost {EXPECTED_CALL_COST}"
            )
        definition = contracts.get(call.contract_name)
        if definition is None:
            errors.append(
                f"{parsed.path_label}: call {call.contract_id}.{call.method} targets unknown contract "
                f"{call.contract_name}"
            )
        elif call.contract_name in TEST_HELPERS:
            errors.append(
                f"{parsed.path_label}: call {call.contract_id}.{call.method} targets test helper "
                f"{call.contract_name}, which is intentionally excluded"
            )
        elif call.contract_name in RELEASE_PLAN_EXCLUSIONS:
            errors.append(
                f"{parsed.path_label}: call {call.contract_id}.{call.method} targets explicitly excluded "
                f"contract {call.contract_name}"
            )
        elif call.contract_name not in positions:
            errors.append(
                f"{parsed.path_label}: call {call.contract_id}.{call.method} targets contract "
                f"{call.contract_name}, which is missing from the release plan"
            )

    for name in sorted(expected_names & set(positions)):
        dependent_position = positions[name]
        for dependency in contracts[name].depends_on:
            if dependency in TEST_HELPERS:
                errors.append(
                    f"{parsed.path_label}: release contract {name} depends on test helper {dependency}, "
                    "which is intentionally excluded"
                )
                continue
            if dependency in RELEASE_PLAN_EXCLUSIONS:
                errors.append(
                    f"{parsed.path_label}: release contract {name} depends on explicitly excluded contract "
                    f"{dependency}; the exclusion must be resolved before release"
                )
                continue
            dependency_position = positions.get(dependency)
            if dependency_position is None:
                errors.append(
                    f"{parsed.path_label}: release contract {name} is missing dependency {dependency}"
                )
            elif dependency_position >= dependent_position:
                errors.append(
                    f"{parsed.path_label}: dependency inversion: {dependency} (batch "
                    f"{dependency_position[0]} transaction {dependency_position[1]}) must be published before "
                    f"{name} (batch {dependent_position[0]} transaction {dependent_position[1]})"
                )

    _raise_if_errors(errors)
    return parsed


def compare_plan_topology(testnet: ParsedReleasePlan, mainnet: ParsedReleasePlan) -> None:
    """Ensure network plans have equivalent ordered publish/call topology.

    The generated pair currently shares one declared deployer.  Comparing that
    metadata is a consistency check for the artifacts, not signer approval;
    mainnet authorization remains outside this validator and blocked by the
    preflight workflow until the approved signer gate is satisfied.
    """

    if testnet.deployer != mainnet.deployer:
        raise ReleasePlanValidationError(
            [
                "testnet/mainnet release deployer drift: "
                f"testnet={testnet.deployer!r}, mainnet={mainnet.deployer!r}; "
                "the generated pair must use one declared deployer"
            ]
        )

    if testnet.topology == mainnet.topology:
        return

    max_batches = max(len(testnet.topology), len(mainnet.topology))
    for batch_index in range(max_batches):
        left = testnet.topology[batch_index] if batch_index < len(testnet.topology) else None
        right = mainnet.topology[batch_index] if batch_index < len(mainnet.topology) else None
        if left is not None and right is not None and len(left) == len(right):
            for transaction_index, (left_tx, right_tx) in enumerate(zip(left, right)):
                if left_tx == right_tx:
                    continue
                if (
                    left_tx
                    and right_tx
                    and left_tx[0] == "publish"
                    and right_tx[0] == "publish"
                    and left_tx[:-1] == right_tx[:-1]
                    and left_tx[-1] == EXPECTED_PUBLISH_COSTS["testnet"]
                    and right_tx[-1] == EXPECTED_PUBLISH_COSTS["mainnet"]
                ):
                    continue
                raise ReleasePlanValidationError(
                    [
                        "testnet/mainnet release topology drift at batch "
                        f"{batch_index} transaction {transaction_index}: "
                        f"testnet={left_tx!r}, mainnet={right_tx!r}; "
                        "only the intentional testnet/mainnet publish-cost difference "
                        "and network/deployer-specific fields may differ"
                    ]
                )
            continue

        max_transactions = max(len(left or ()), len(right or ()))
        for transaction_index in range(max_transactions):
            left_tx = left[transaction_index] if left is not None and transaction_index < len(left) else None
            right_tx = right[transaction_index] if right is not None and transaction_index < len(right) else None
            if left_tx != right_tx:
                raise ReleasePlanValidationError(
                    [
                        "testnet/mainnet release topology drift at batch "
                        f"{batch_index} transaction {transaction_index}: "
                        f"testnet={left_tx!r}, mainnet={right_tx!r}; "
                        "only the intentional testnet/mainnet publish-cost difference "
                        "and network/deployer-specific fields may differ"
                    ]
                )
        raise ReleasePlanValidationError(
            [
                "testnet/mainnet release topology drift at batch "
                f"{batch_index}: transaction counts differ (testnet={len(left or ())}, mainnet={len(right or ())})"
            ]
        )


def validate_release_plan_files(
    testnet_path: Path,
    mainnet_path: Path,
    manifest_path: Path,
    repo_root: Path,
    yaml_loader: Any,
) -> tuple[ParsedReleasePlan, ParsedReleasePlan]:
    """Load and validate both generated network plans in strict mode."""

    contracts = load_clarinet_manifest(manifest_path, repo_root)
    plans: list[ParsedReleasePlan] = []
    for path, expected_network in ((Path(testnet_path), "testnet"), (Path(mainnet_path), "mainnet")):
        try:
            with path.open() as plan_file:
                document = yaml_loader.safe_load(plan_file)
        except FileNotFoundError:
            raise ReleasePlanValidationError([f"generated release plan does not exist: {path}"])
        except Exception as exc:
            yaml_error = getattr(yaml_loader, "YAMLError", None)
            if yaml_error is not None and isinstance(exc, yaml_error):
                raise ReleasePlanValidationError([f"{path}: generated release plan YAML is malformed: {exc}"])
            raise
        if not _is_mapping(document):
            raise ReleasePlanValidationError([f"{path}: generated release plan must be a YAML mapping"])
        parsed = parse_release_plan(document, str(path))
        plans.append(validate_release_plan(parsed, contracts, repo_root, expected_network))

    compare_plan_topology(plans[0], plans[1])
    return plans[0], plans[1]
