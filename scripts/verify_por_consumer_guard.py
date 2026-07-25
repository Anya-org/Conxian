#!/usr/bin/env python3
"""Fail closed when production code consumes non-authoritative PoR state."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
SAFE_STATUS_FUNCTIONS = {"is-fully-backed", "get-proof-status"}
DIAGNOSTIC_OR_LEGACY_SYMBOLS = {
    "get-accepted-reserve", "get-snapshot-candidate", "get-attestation",
    "snapshot-candidates", "snapshot-approvals", "accepted-reserves",
    "asset-reserves", "sync-on-chain-balance", "off-chain-amount",
    "candidate-state", "raw-attestation",
}
SCRIPT_SUFFIXES = {".py", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".sh"}
RELEVANT_SCRIPT_TERMS = {
    "treasury", "compliance", "settlement", "routing", "router", "readiness",
    "release", "deployment", "mainnet", "audit", "reserve",
}
CONTRACT_CALL_RE = re.compile(r"\(contract-call\?\s+([^\s()]+)\s+([^\s()]+)")
ALIAS_RE = re.compile(r"\(define-constant\s+([^\s()]+)\s+([^\s()]*proof-of-reserves)\s*\)")


def _por_targets(text: str) -> set[str]:
    targets = {".proof-of-reserves"}
    for alias, target in ALIAS_RE.findall(text):
        targets.add(alias)
        targets.add(target)
    return targets


def scan_clarity_text(text: str, path: str) -> list[str]:
    violations: list[str] = []
    targets = _por_targets(text)
    has_por_reference = "proof-of-reserves" in text or len(targets) > 1
    for target, function in CONTRACT_CALL_RE.findall(text):
        if target in targets or "proof-of-reserves" in target:
            if function not in SAFE_STATUS_FUNCTIONS:
                violations.append(f"{path}: PoR call `{function}` is not an approved fail-closed status interface")
    if has_por_reference:
        for symbol in sorted(DIAGNOSTIC_OR_LEGACY_SYMBOLS):
            if re.search(rf"(?<![\w-]){re.escape(symbol)}(?![\w-])", text):
                violations.append(f"{path}: references diagnostic/legacy PoR authority `{symbol}`")
    return violations


def scan_script_text(text: str, path: str) -> list[str]:
    lowered = text.lower()
    if "proof-of-reserves" not in lowered and "proof of reserves" not in lowered:
        return []
    violations: list[str] = []
    for symbol in sorted(DIAGNOSTIC_OR_LEGACY_SYMBOLS):
        if re.search(rf"(?<![\w-]){re.escape(symbol)}(?![\w-])", lowered):
            violations.append(f"{path}: operational script references diagnostic/legacy PoR authority `{symbol}`")
    queried_methods = set(re.findall(r"\b(?:function|method|function-name)\s*[=:]\s*['\"]?([\w-]+)", lowered))
    for method in sorted(queried_methods - SAFE_STATUS_FUNCTIONS):
        if "reserve" in method or method in DIAGNOSTIC_OR_LEGACY_SYMBOLS:
            violations.append(f"{path}: operational PoR query `{method}` is not fail closed")
    return violations


def production_clarity_files(root: Path) -> Iterable[Path]:
    por_contract = root / "contracts/security/proof-of-reserves.clar"
    for path in (root / "contracts").rglob("*.clar"):
        relative = path.relative_to(root)
        if path == por_contract or any(part in {"test-helpers", "mocks", "stubs"} for part in relative.parts):
            continue
        yield path


def relevant_script_files(root: Path) -> Iterable[Path]:
    for path in (root / "scripts").rglob("*"):
        if not path.is_file() or path.suffix not in SCRIPT_SUFFIXES or path.name == Path(__file__).name:
            continue
        relative = str(path.relative_to(root)).lower()
        text = path.read_text(encoding="utf-8", errors="ignore").lower()
        if any(term in relative or term in text for term in RELEVANT_SCRIPT_TERMS):
            yield path


def verify(root: Path = ROOT) -> list[str]:
    violations: list[str] = []
    for path in production_clarity_files(root):
        violations.extend(scan_clarity_text(path.read_text(encoding="utf-8"), str(path.relative_to(root))))
    for path in relevant_script_files(root):
        violations.extend(scan_script_text(path.read_text(encoding="utf-8", errors="ignore"), str(path.relative_to(root))))
    return violations


def main() -> int:
    violations = verify()
    if violations:
        print("CRITICAL: proof-of-reserves consumer boundary violations found:")
        for violation in violations:
            print(f"  - {violation}")
        return 1
    print("SUCCESS: production PoR consumers use only explicit fail-closed status interfaces.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
