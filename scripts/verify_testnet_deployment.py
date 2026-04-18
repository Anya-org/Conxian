from __future__ import annotations

import argparse
import dataclasses
import json
import os
import re
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
            if quote == '"':
                backslashes = 0
                j = i - 1
                while j >= 0 and value[j] == "\\":
                    backslashes += 1
                    j -= 1
                if backslashes % 2 == 1:
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


def _split_yaml_comment(line: str) -> tuple[str, str]:
    in_single = False
    in_double = False
    double_escaped = False

    i = 0
    while i < len(line):
        ch = line[i]
        if in_single:
            if ch == "'":
                if i + 1 < len(line) and line[i + 1] == "'":
                    i += 2
                    continue
                in_single = False
            i += 1
            continue

        if in_double:
            if double_escaped:
                double_escaped = False
                i += 1
                continue
            if ch == "\\":
                double_escaped = True
                i += 1
                continue
            if ch == '"':
                in_double = False
            i += 1
            continue

        if ch == "'":
            in_single = True
            i += 1
            continue

        if ch == '"':
            in_double = True
            i += 1
            continue

        if ch == "#" and (i == 0 or line[i - 1].isspace()):
            return line[:i].rstrip(), line[i + 1 :]

        i += 1

    return line.rstrip(), ""


def _escape_yaml_double_quoted(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


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


def _parse_optional_yaml_scalar(value: str) -> str | None:
    cleaned = _strip_yaml_scalar(value)
    return cleaned if cleaned else None


def _contract_from_current(current: dict[str, str | None]) -> PlanContract | None:
    name = str(current.get("contract-name") or "").strip()
    if not name:
        return None
    expected_sender = current.get("expected-sender") or None
    path = current.get("path") or None
    return PlanContract(name=name, expected_sender=expected_sender, path=path)


def parse_deployment_plan(plan_text: str) -> ParsedPlan:
    network: str | None = None
    deployer: str | None = None
    contracts: list[PlanContract] = []

    current: dict[str, str | None] | None = None
    current_indent: int | None = None

    for raw_line in plan_text.splitlines():
        stripped = raw_line.lstrip()
        indent = len(raw_line) - len(stripped)
        line = stripped.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("network:"):
            network = _parse_optional_yaml_scalar(line.split(":", 1)[1])
            continue

        if line.startswith("deployer:"):
            deployer = _parse_optional_yaml_scalar(line.split(":", 1)[1])
            continue

        if line.startswith("-"):
            if current is not None and current_indent is not None and indent <= current_indent:
                contract = _contract_from_current(current)
                if contract is not None:
                    contracts.append(contract)
                current = None
                current_indent = None

            if line.startswith("- contract-publish:"):
                current = {"contract-name": None, "expected-sender": None, "path": None}
                current_indent = indent
            continue

        if current is None:
            continue

        if line.startswith("contract-name:"):
            current["contract-name"] = _parse_optional_yaml_scalar(line.split(":", 1)[1])
        elif line.startswith("expected-sender:"):
            current["expected-sender"] = _parse_optional_yaml_scalar(line.split(":", 1)[1])
        elif line.startswith("path:"):
            current["path"] = _parse_optional_yaml_scalar(line.split(":", 1)[1])

    if current is not None:
        contract = _contract_from_current(current)
        if contract is not None:
            contracts.append(contract)

    contracts = [c for c in contracts if c.name]

    return ParsedPlan(network=network, deployer=deployer, contracts=contracts)

def normalize_deployment_plan_text(*, plan_text: str, principal: str) -> str:
    lines = plan_text.splitlines()
    out: list[str] = []

    block_scalar_start = re.compile(r":\s*[>|][+-]?[0-9]*\s*$")
    in_block_scalar = False
    block_scalar_key_indent: int | None = None

    principal_escaped = _escape_yaml_double_quoted(principal)

    for raw_line in lines:
        stripped = raw_line.lstrip()
        indent_len = len(raw_line) - len(stripped)
        content, comment = _split_yaml_comment(stripped)
        header = content

        if in_block_scalar:
            if stripped and block_scalar_key_indent is not None and indent_len <= block_scalar_key_indent:
                in_block_scalar = False
                block_scalar_key_indent = None
            else:
                out.append(raw_line)
                continue

        if block_scalar_start.search(header):
            in_block_scalar = True
            block_scalar_key_indent = indent_len
            out.append(raw_line)
            continue

        comment_suffix = ""
        if comment:
            comment_suffix = "  #" + comment

        if content.startswith("deployer:"):
            indent = raw_line[: len(raw_line) - len(stripped)]
            out.append(f'{indent}deployer: "{principal_escaped}"{comment_suffix}')
            continue

        if content.startswith("expected-sender:"):
            indent = raw_line[: len(raw_line) - len(stripped)]
            out.append(f'{indent}expected-sender: "{principal_escaped}"{comment_suffix}')
            continue

        out.append(raw_line)

    return "\n".join(out) + "\n"

class HiroRequestError(RuntimeError):
    pass


def _http_json(url: str) -> dict:
    try:
        timeout_secs = float(os.environ.get("HIRO_TIMEOUT_SECS", "30"))
    except ValueError:
        timeout_secs = 30.0
    if timeout_secs <= 0:
        timeout_secs = 30.0
    timeout_secs = max(0.1, min(timeout_secs, 120.0))
    try:
        max_attempts = int(os.environ.get("HIRO_MAX_ATTEMPTS", "4"))
    except ValueError:
        max_attempts = 4
    max_attempts = max(1, min(max_attempts, 10))

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
                data = json.loads(payload)
            except json.JSONDecodeError as e:
                last_err = e
            else:
                if not isinstance(data, dict):
                    raise HiroRequestError(
                        f"Hiro API returned unexpected JSON type: {type(data).__name__}: {url}"
                    )

                return data
        except urllib.error.HTTPError as e:
            if e.code == 404:
                raise
            if e.code == 429 or (500 <= e.code < 600):
                last_err = e
            else:
                raise
        except (urllib.error.URLError, TimeoutError) as e:
            last_err = e

        if attempt < max_attempts - 1:
            time.sleep(0.5 * (2**attempt))

    if last_err is not None:
        is_timeout = isinstance(last_err, TimeoutError) or (
            isinstance(last_err, urllib.error.URLError)
            and isinstance(getattr(last_err, "reason", None), TimeoutError)
        )
        if is_timeout:
            raise urllib.error.URLError(
                f"Hiro API request timed out after {max_attempts} attempts: {url}"
            ) from last_err

        if isinstance(last_err, urllib.error.HTTPError):
            raise urllib.error.HTTPError(
                last_err.url,
                last_err.code,
                f"Hiro API request failed after {max_attempts} attempts: {url} ({last_err})",
                last_err.hdrs,
                last_err.fp,
            ) from last_err

        raise urllib.error.URLError(
            f"Hiro API request failed after {max_attempts} attempts: {url} ({last_err})"
        ) from last_err
    raise urllib.error.URLError(
        f"Hiro API request failed after {max_attempts} attempts: {url}"
    )


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
    if source is None:
        raise HiroRequestError(
            f"Unexpected Hiro response for {principal}.{name}: missing source"
        )
    if not isinstance(source, str):
        raise HiroRequestError(
            f"Unexpected Hiro response for {principal}.{name}: source is {type(source).__name__}"
        )
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
    except urllib.error.URLError as e:
        raise urllib.error.URLError(
            f"Hiro API request failed for metadata {principal}.{name}: {e}"
        ) from e
    tx_id = data.get("tx_id")
    block_height = data.get("block_height")
    return (tx_id if isinstance(tx_id, str) else None), (
        block_height if isinstance(block_height, int) else None
    )


def _normalize_source(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = [ln.rstrip() for ln in text.split("\n")]
    return "\n".join(lines).rstrip() + "\n"


@dataclasses.dataclass(frozen=True)
class VerificationResult:
    name: str
    principal: str
    local_path: str
    expected_sender: str | None
    sender_matches_deployer: bool
    deployed: bool
    lookup_failed: bool
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
        principal_display = principal or "<missing principal>"
        chain_source: str | None = None
        lookup_failed = False
        try:
            if not principal:
                raise HiroRequestError(
                    f"Cannot determine principal for {c.name} (missing deployer, expected-sender, and principal override)"
                )
            chain_source = _fetch_contract_source(hiro_base, principal, c.name)
        except (
            HiroRequestError,
            urllib.error.HTTPError,
            urllib.error.URLError,
            json.JSONDecodeError,
        ) as e:
            lookup_failed = True
            failures.append(
                f"{c.name}: Hiro API error querying source for {principal_display}.{c.name}: {e}"
            )
        deployed = False if lookup_failed else (chain_source is not None)
        tx_id: str | None = None
        block_height: int | None = None

        if deployed:
            try:
                tx_id, block_height = _fetch_contract_meta(hiro_base, principal, c.name)
            except (
                HiroRequestError,
                urllib.error.HTTPError,
                urllib.error.URLError,
                json.JSONDecodeError,
            ) as e:
                lookup_failed = True
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
                principal=principal_display,
                local_path=abs_local_path,
                expected_sender=c.expected_sender,
                sender_matches_deployer=sender_matches,
                deployed=deployed,
                lookup_failed=lookup_failed,
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
        "--write-normalized-plan",
        default=None,
        help=(
            "Write a normalized copy of the plan with deployer + all expected-sender values set to a single principal, then exit. "
            "Uses --principal when provided; otherwise uses the plan's deployer."
        ),
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

    plan_path = os.path.abspath(args.plan)
    if args.write_normalized_plan:
        plan_text = _read_text(plan_path)
        parsed = parse_deployment_plan(plan_text)
        principal = args.principal or parsed.deployer
        if not principal:
            raise SystemExit(
                "Unable to determine principal for normalization; provide --principal or ensure the plan has a deployer field."
            )

        out_path = os.path.abspath(args.write_normalized_plan)
        if out_path == plan_path:
            raise SystemExit(
                "Refusing to overwrite the input plan in place; pass a different --write-normalized-plan output path."
            )
        out_dir = os.path.dirname(out_path)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
        normalized = normalize_deployment_plan_text(plan_text=plan_text, principal=principal)
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(normalized)
        if args.json:
            print(
                json.dumps(
                    {"normalized_plan": out_path},
                    indent=2,
                    sort_keys=True,
                )
            )
        else:
            print(out_path)
        raise SystemExit(0)

    network, deployer, results, failures = verify_plan(
        plan_path=plan_path,
        hiro_base=args.hiro_base.rstrip("/"),
        principal_override=args.principal,
        strict_expected_sender=args.strict_expected_sender,
        strict_source_match=args.strict_source_match,
    )

    if args.json:
        contracts = [dataclasses.asdict(r) for r in results]
        print(
            json.dumps(
                {
                    "network": network,
                    "deployer": deployer,
                    "plan": os.path.abspath(args.plan),
                    "contracts": contracts,
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
            if r.lookup_failed:
                status = "error"
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
