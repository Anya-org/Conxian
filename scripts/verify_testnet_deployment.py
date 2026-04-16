from __future__ import annotations

import argparse
import dataclasses
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request


def repo_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def _read_text(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except UnicodeDecodeError as e:
        raise SystemExit(f"Failed to decode {path} as UTF-8: {e}") from e


def _strip_yaml_scalar(value: str) -> str:
    value = value.strip()
    if not value:
        return value

    quote = value[0]
    if quote in ('"', "'"):
        end: int | None = None
        i = 1
        while i < len(value):
            if value[i] != quote:
                i += 1
                continue
            if quote == "'" and i + 1 < len(value) and value[i + 1] == "'":
                i += 2
                continue
            if quote == '"' and i > 0 and value[i - 1] == "\\":
                i += 1
                continue
            end = i
            break
        if end is None:
            return value
        inner = value[1:end]
        if quote == "'":
            inner = inner.replace("''", "'")
        return inner

    if value.startswith("#"):
        return ""

    for i, ch in enumerate(value):
        if ch == "#" and i > 0 and value[i - 1].isspace():
            value = value[: i - 1].rstrip()
            break
    return value


def _find_clarinet_project_root(plan_path: str) -> str:
    plan_dir = os.path.dirname(os.path.abspath(plan_path))
    current = plan_dir
    while True:
        if os.path.isfile(os.path.join(current, "Clarinet.toml")):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            return plan_dir
        current = parent


@dataclasses.dataclass(frozen=True)
class PlanContract:
    name: str
    expected_sender: str | None
    path: str | None


@dataclasses.dataclass(frozen=True)
class ParsedPlan:
    network: str | None
    deployer: str | None
    contracts: list[PlanContract]


def parse_deployment_plan(plan_text: str) -> ParsedPlan:
    network: str | None = None
    deployer: str | None = None
    contracts: list[PlanContract] = []

    current: dict[str, str | None] | None = None

    for raw_line in plan_text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("network:"):
            network = _strip_yaml_scalar(line.split(":", 1)[1])
            continue

        if line.startswith("deployer:"):
            deployer = _strip_yaml_scalar(line.split(":", 1)[1])
            continue

        if line.startswith("- contract-publish:"):
            if current is not None:
                contracts.append(
                    PlanContract(
                        name=str(current.get("contract-name") or "").strip(),
                        expected_sender=current.get("expected-sender"),
                        path=current.get("path"),
                    )
                )
            current = {"contract-name": None, "expected-sender": None, "path": None}
            continue

        if current is None:
            continue

        if line.startswith("contract-name:"):
            current["contract-name"] = _strip_yaml_scalar(line.split(":", 1)[1])
        elif line.startswith("expected-sender:"):
            current["expected-sender"] = _strip_yaml_scalar(line.split(":", 1)[1])
        elif line.startswith("path:"):
            current["path"] = _strip_yaml_scalar(line.split(":", 1)[1])

    if current is not None:
        contracts.append(
            PlanContract(
                name=str(current.get("contract-name") or "").strip(),
                expected_sender=current.get("expected-sender"),
                path=current.get("path"),
            )
        )

    contracts = [c for c in contracts if c.name]

    return ParsedPlan(network=network, deployer=deployer, contracts=contracts)


class HiroRequestError(RuntimeError):
    pass


def _http_json(url: str) -> dict:
    try:
        timeout_secs = float(os.environ.get("HIRO_TIMEOUT_SECS", "30"))
    except ValueError:
        timeout_secs = 30.0
    timeout_secs = max(0.1, min(timeout_secs, 120.0))
    try:
        max_attempts = int(os.environ.get("HIRO_MAX_ATTEMPTS", "4"))
    except ValueError:
        max_attempts = 4
    max_attempts = min(max(1, max_attempts), 10)

    last_err: Exception | None = None
    for attempt in range(max_attempts):
        try:
            req = urllib.request.Request(
                url,
                headers={
                    "Accept": "application/json",
                    "User-Agent": "conxian-business-testnet-deployment-verifier",
                },
            )
            with urllib.request.urlopen(req, timeout=timeout_secs) as resp:
                payload = resp.read().decode("utf-8", "replace")
            try:
                return json.loads(payload)
            except json.JSONDecodeError as e:
                raise HiroRequestError(f"Hiro API returned invalid JSON: {url}") from e
        except urllib.error.HTTPError as e:
            if e.code == 404:
                raise
            if e.code == 429 or (500 <= e.code < 600):
                last_err = e
            else:
                raise HiroRequestError(f"Hiro API request failed: {url} (HTTP {e.code})") from e
        except (urllib.error.URLError, TimeoutError) as e:
            last_err = e

        if attempt < max_attempts - 1:
            time.sleep(0.5 * (2**attempt))

    raise HiroRequestError(f"Hiro API request failed after retries: {url} ({last_err})") from last_err


def _fetch_contract_source(hiro_base: str, principal: str, name: str) -> str | None:
    principal_q = urllib.parse.quote(principal, safe="")
    name_q = urllib.parse.quote(name, safe="")
    url = f"{hiro_base}/v2/contracts/source/{principal_q}/{name_q}"
    try:
        data = _http_json(url)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise
    source = data.get("source")
    if not isinstance(source, str):
        return None
    return source


def _fetch_contract_meta(
    hiro_base: str, principal: str, name: str
) -> tuple[str | None, int | None]:
    contract_id = f"{principal}.{name}"
    contract_id_q = urllib.parse.quote(contract_id, safe="")
    url = f"{hiro_base}/extended/v1/contract/{contract_id_q}"
    try:
        data = _http_json(url)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None, None
        raise
    except HiroRequestError as e:
        raise HiroRequestError(
            f"Hiro API request failed for metadata {principal}.{name}: {e}"
        ) from e
    tx_id = data.get("tx_id")
    block_height = data.get("block_height")
    return (tx_id if isinstance(tx_id, str) else None), (
        block_height if isinstance(block_height, int) else None
    )


def _normalize_source(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = text.rstrip("\n")
    return text + "\n"


@dataclasses.dataclass(frozen=True)
class VerificationResult:
    name: str
    principal: str
    local_path: str
    expected_sender: str | None
    sender_matches_deployer: bool
    deployed: bool
    source_lookup_failed: bool
    tx_id: str | None
    block_height: int | None
    source_matches: bool | None


def verify_plan(
    *,
    plan_path: str,
    hiro_base: str,
    principal_override: str | None,
    strict_expected_sender: bool,
    strict_source_match: bool,
) -> tuple[str, str, list[VerificationResult], list[str]]:
    if not os.path.isfile(plan_path):
        raise SystemExit(
            f"Plan not found: {plan_path}\n\nIf this references a submodule file, ensure submodules are initialized:\n  git submodule update --init --recursive"
        )

    plan = parse_deployment_plan(_read_text(plan_path))
    if not plan.deployer:
        raise SystemExit(f"Plan is missing required field: deployer ({plan_path})")
    if not plan.network:
        raise SystemExit(f"Plan is missing required field: network ({plan_path})")

    deployer = plan.deployer
    network = plan.network

    if network.strip().lower() != "testnet":
        raise SystemExit(
            f"Unexpected plan network {network!r}; this verifier is intended for 'testnet'."
        )
    project_root = _find_clarinet_project_root(plan_path)

    failures: list[str] = []
    results: list[VerificationResult] = []

    for c in plan.contracts:
        local_source: str | None = None
        abs_local_path = ""
        local_path = c.path or ""
        if not local_path:
            if strict_source_match:
                failures.append(f"{c.name}: missing path in plan")
        else:
            if os.path.isabs(local_path):
                abs_local_path = os.path.abspath(local_path)
            else:
                abs_local_path = os.path.abspath(os.path.join(project_root, local_path))
            if os.path.isfile(abs_local_path):
                local_source = _read_text(abs_local_path)
            elif strict_source_match:
                failures.append(f"{c.name}: local contract source missing: {abs_local_path}")

        sender_matches = True if not c.expected_sender else (c.expected_sender == deployer)
        if strict_expected_sender and c.expected_sender and not sender_matches:
            failures.append(
                f"{c.name}: expected-sender {c.expected_sender!r} does not match deployer {deployer!r}"
            )

        principal = principal_override or c.expected_sender or deployer
        chain_source: str | None = None
        lookup_failed = False
        try:
            chain_source = _fetch_contract_source(hiro_base, principal, c.name)
        except HiroRequestError as e:
            lookup_failed = True
            failures.append(
                f"{c.name}: Hiro API error querying source for {principal}.{c.name}: {e}"
            )
        deployed = chain_source is not None
        tx_id: str | None = None
        block_height: int | None = None

        if deployed:
            try:
                tx_id, block_height = _fetch_contract_meta(hiro_base, principal, c.name)
            except HiroRequestError as e:
                failures.append(
                    f"{c.name}: Hiro API error querying metadata for {principal}.{c.name}: {e}"
                )

        source_matches: bool | None = None
        if deployed and local_source is not None:
            local_source_norm = _normalize_source(local_source)
            chain_source_norm = _normalize_source(chain_source)
            source_matches = local_source_norm == chain_source_norm
            if strict_source_match and not source_matches:
                failures.append(f"{c.name}: source drift vs {abs_local_path}")

        results.append(
            VerificationResult(
                name=c.name,
                principal=principal,
                local_path=abs_local_path,
                expected_sender=c.expected_sender,
                sender_matches_deployer=sender_matches,
                deployed=deployed,
                source_lookup_failed=lookup_failed,
                tx_id=tx_id,
                block_height=block_height,
                source_matches=source_matches,
            )
        )

        if not deployed and not lookup_failed:
            failures.append(f"{c.name}: missing on-chain contract {principal}.{c.name}")

    return network, deployer, results, failures


def main() -> None:
    default_plan = os.path.join(
        repo_root(), "Conxian", "deployments", "full-system.testnet-plan.yaml"
    )
    parser = argparse.ArgumentParser(
        description=(
            "Verify that a testnet deployment plan's contract-publish set exists on-chain and (optionally) matches local sources."
        )
    )
    parser.add_argument(
        "--plan",
        default=default_plan,
        help=f"Path to a Clarinet deployment plan YAML (default: {default_plan})",
    )
    parser.add_argument(
        "--hiro-base",
        default="https://api.testnet.hiro.so",
        help="Hiro API base URL (default: https://api.testnet.hiro.so)",
    )
    parser.add_argument(
        "--principal",
        default=None,
        help=(
            "Override the principal used for on-chain lookups. If omitted, each contract uses its plan 'expected-sender' (falling back to the plan 'deployer')."
        ),
    )
    parser.add_argument(
        "--strict-expected-sender",
        action="store_true",
        help="Fail if any contract-publish expected-sender differs from the plan deployer.",
    )
    parser.add_argument(
        "--strict-source-match",
        action="store_true",
        help="Fail if any deployed contract source differs from the local file referenced by the plan.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output machine-readable JSON instead of human text.",
    )
    args = parser.parse_args()

    network, deployer, results, failures = verify_plan(
        plan_path=os.path.abspath(args.plan),
        hiro_base=args.hiro_base.rstrip("/"),
        principal_override=args.principal,
        strict_expected_sender=args.strict_expected_sender,
        strict_source_match=args.strict_source_match,
    )

    if args.json:
        print(
            json.dumps(
                {
                    "network": network,
                    "deployer": deployer,
                    "plan": os.path.abspath(args.plan),
                    "contracts": [dataclasses.asdict(r) for r in results],
                    "failures": failures,
                },
                indent=2,
                sort_keys=True,
            )
        )
    else:
        print(f"network={network}")
        print(f"deployer={deployer}")
        print(f"plan={os.path.abspath(args.plan)}")
        print(f"contracts_in_plan={len(results)}")

        for r in results:
            if r.source_lookup_failed:
                status = "unknown"
            elif not r.deployed:
                status = "missing"
            elif r.source_matches is True:
                status = "ok"
            elif r.source_matches is False:
                status = "drift"
            else:
                status = "deployed"

            sender_flag = "ok" if r.sender_matches_deployer else "mismatch"
            meta = []
            if r.block_height is not None:
                meta.append(f"height={r.block_height}")
            if r.tx_id:
                meta.append(f"tx={r.tx_id}")
            meta_text = " " + " ".join(meta) if meta else ""
            print(
                f"- {r.name}: {status} principal={r.principal} expected-sender={sender_flag}{meta_text} local={r.local_path}"
            )

        if failures:
            print("\nFailures:")
            for f in failures:
                print(f"- {f}")

    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
