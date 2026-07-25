#!/usr/bin/env python3
"""Reject unsafe consumers of proof-of-reserves state and legacy APIs."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
POR_CONTRACT = Path("contracts/security/proof-of-reserves.clar")
SAFE_STATUS_FUNCTIONS = {"is-fully-backed", "get-proof-status"}
LEGACY_DEFINITIONS = {"sync-on-chain-balance", "set-oracle-aggregator", "get-reserve-data", "get-attestation", "get-reserve-ratio", "remove-attestor"}


def strip_comments_and_strings(source: str) -> str:
    output, i, in_string, escaped = [], 0, False, False
    while i < len(source):
        char = source[i]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            output.append(" ")
        elif char == '"':
            in_string = True
            output.append(" ")
        elif source.startswith(";;", i):
            newline = source.find("\n", i)
            if newline < 0:
                output.extend(" " * (len(source) - i))
                break
            output.extend(" " * (newline - i))
            i = newline - 1
        else:
            output.append(char)
        i += 1
    return "".join(output)


def por_calls(source: str) -> list[str]:
    clean = strip_comments_and_strings(source)
    pattern = re.compile(r"\(\s*contract-call\?\s+(?:'?[A-Z0-9]+\.)?\.?(?:proof-of-reserves)\s+([a-z0-9-]+)", re.I | re.M)
    return [match.group(1).lower() for match in pattern.finditer(clean)]


def collect_errors(root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    por_path = root / POR_CONTRACT
    if not por_path.is_file():
        return [f"missing {POR_CONTRACT}"]
    por_source = strip_comments_and_strings(por_path.read_text(encoding="utf-8"))
    for legacy in sorted(LEGACY_DEFINITIONS):
        if re.search(rf"\(\s*define-(?:public|read-only)\s+\(\s*{re.escape(legacy)}\b", por_source):
            errors.append(f"{POR_CONTRACT} retains deprecated callable {legacy}")
    if "oracle-aggregator" in por_source:
        errors.append(f"{POR_CONTRACT} conflates price-oracle configuration with PoR authority")
    for primitive in ("secp256k1-verify", "to-consensus-buff?"):
        if not re.search(rf"\(\s*{re.escape(primitive)}(?:\s|\()", por_source):
            errors.append(f"{POR_CONTRACT} is missing {primitive}")
    contracts = root / "contracts"
    if contracts.is_dir():
        for path in sorted(contracts.rglob("*.clar")):
            if path.resolve() == por_path.resolve():
                continue
            for function in por_calls(path.read_text(encoding="utf-8")):
                if function not in SAFE_STATUS_FUNCTIONS:
                    errors.append(f"{path.relative_to(root)} calls unsafe proof-of-reserves function {function}; only trait-based fail-closed status APIs are allowed")
    return errors


def main() -> int:
    errors = collect_errors()
    if errors:
        print("Proof-of-reserves boundary guard failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Proof-of-reserves boundary guard passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
