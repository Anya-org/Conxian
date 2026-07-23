#!/usr/bin/env python3
"""Fail closed if the quarantined ZKML verifier regresses.

This guard is intentionally static and dependency-free. It checks the source,
active release artifacts, release classification, and current documentation
without attempting to parse or validate cryptographic proofs.
"""

from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parent.parent
CONTRACT_PATH = ROOT / "contracts/compliance/zkml-verifier.clar"
SIMNET_PLAN_PATH = ROOT / "deployments/default.simnet-plan.yaml"
RELEASE_PLAN_PATHS = (
    ROOT / "deployments/full-system.testnet-plan.yaml",
    ROOT / "deployments/full-system.mainnet-plan.yaml",
    ROOT / "deployments/mainnet-release-plan.yaml",
)
RELEASE_CLASSIFICATION_PATHS = (
    ROOT / "scripts/gen-deployment-plans.py",
    ROOT / "scripts/release_plan_validation.py",
)
ACTIVE_DOC_PATHS = (
    ROOT / "contracts/compliance/README.md",
    ROOT / "PRD.md",
    ROOT / "docs/SYSTEM_ALIGNMENT_AUDIT_MARCH_2026.md",
    ROOT / "docs/CONXIAN_SYSTEM_RESEARCH_SYNOPSIS.md",
)
HISTORICAL_DOC_PATH = ROOT / "docs/STANDARDS_VALIDATION_SESSION_25.md"

ZKML_RE = re.compile(r"\b(?:zkml(?:-verifier)?|zero[- ]knowledge machine learning|groth16|plonk)\b", re.I)
POSITIVE_RE = re.compile(
    r"\b(?:implemented|production(?:[- ]ready)?|internally verified|verified|active|operational)\b",
    re.I,
)
NEGATIVE_RE = re.compile(
    r"\b(?:not|no|never|without|pending|unavailable|quarantin\w*|scaffold\w*|"
    r"fail(?:s|ed)?[- ]closed|superseded|historical|excluded|absent|cannot|unqualified)\b",
    re.I,
)
PLAN_ENTRY_RE = re.compile(r"(?im)^\s*(?:contract-name|path):\s*[\"']?zkml-verifier\b")


def read_text(path: Path, errors: list[str]) -> str:
    if not path.is_file():
        errors.append(f"missing required file: {path.relative_to(ROOT)}")
        return ""
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        errors.append(f"could not read {path.relative_to(ROOT)}: {exc}")
        return ""


def verify_contract(errors: list[str]) -> None:
    source = read_text(CONTRACT_PATH, errors)
    if not source:
        return

    start = source.find("(define-public (verify-proof")
    end = source.find("\n;; Admin functions", start)
    if start < 0 or end < 0:
        errors.append("verify-proof public function or admin boundary is missing")
        return
    verify_body = source[start:end]

    if "ERR_VERIFIER_UNAVAILABLE" not in source or "(err u7003)" not in source:
        errors.append("distinct unavailable-verifier error u7003 is missing")
    if "ERR_VERIFIER_UNAVAILABLE" not in verify_body:
        errors.append("verify-proof does not return the unavailable-verifier error")
    if re.search(r"\(\s*len\b", verify_body):
        errors.append("verify-proof contains a length-only verification marker")
    if re.search(r"\(\s*ok\s+true\s*\)", verify_body, re.I):
        errors.append("verify-proof contains an unconditional success path")
    if re.search(r"\(\s*print\b", verify_body, re.I):
        errors.append("verify-proof emits an event despite the quarantine")
    if re.search(r"zkml-verified", source, re.I):
        errors.append("zkml-verified event marker is still present")

    status_start = source.find("(define-read-only (get-protocol-status)")
    status = source[status_start:] if status_start >= 0 else ""
    if not re.search(r"compliant:\s*false", status, re.I):
        errors.append("protocol status is not explicitly non-compliant")
    if not re.search(r'mode:\s*"ZKML-PAUSED"', status):
        errors.append("protocol status is not explicitly ZKML-PAUSED")
    if re.search(r"ZKML-ACTIVE", status, re.I):
        errors.append("protocol status still advertises ZKML-ACTIVE")


def verify_release_classification(errors: list[str]) -> None:
    for path in RELEASE_CLASSIFICATION_PATHS:
        source = read_text(path, errors)
        if source and not re.search(r"[\"']zkml-verifier[\"']", source):
            errors.append(f"{path.relative_to(ROOT)} does not explicitly classify zkml-verifier")

    simnet = read_text(SIMNET_PLAN_PATH, errors)
    if simnet and not PLAN_ENTRY_RE.search(simnet):
        errors.append("default.simnet-plan.yaml no longer retains zkml-verifier for local regression testing")

    for path in RELEASE_PLAN_PATHS:
        plan = read_text(path, errors)
        if plan and PLAN_ENTRY_RE.search(plan):
            errors.append(f"{path.relative_to(ROOT)} still includes the quarantined zkml-verifier")


def verify_active_docs(errors: list[str]) -> None:
    for path in ACTIVE_DOC_PATHS:
        text = read_text(path, errors)
        if not text:
            continue
        if not ZKML_RE.search(text):
            errors.append(f"{path.relative_to(ROOT)} does not document the ZKML quarantine boundary")
        if not re.search(r"scaffold|quarantin|unavailable|fail[- ]closed|not claimed", text, re.I):
            errors.append(f"{path.relative_to(ROOT)} lacks explicit fail-closed/scaffold wording")

        for match in re.finditer(
            rf"(?:{ZKML_RE.pattern}).{{0,140}}(?:{POSITIVE_RE.pattern})|"
            rf"(?:{POSITIVE_RE.pattern}).{{0,140}}(?:{ZKML_RE.pattern})",
            text,
            re.I | re.S,
        ):
            context = text[max(0, match.start() - 80) : min(len(text), match.end() + 80)]
            if not NEGATIVE_RE.search(context):
                errors.append(
                    f"{path.relative_to(ROOT)} contains an active positive ZKML implementation/verification claim: "
                    f"{context.strip().replace(chr(10), ' ')[:220]}"
                )

        if re.search(r"ZKML-ACTIVE|compliant:\s*true", text, re.I):
            errors.append(f"{path.relative_to(ROOT)} contains an active ZKML status marker")


def verify_historical_disclaimer(errors: list[str]) -> None:
    text = read_text(HISTORICAL_DOC_PATH, errors)
    if text and not re.search(r"historical", text, re.I):
        errors.append("STANDARDS_VALIDATION_SESSION_25.md lacks a historical disclaimer")
    if text and not re.search(r"superseded", text, re.I):
        errors.append("STANDARDS_VALIDATION_SESSION_25.md lacks a superseded disclaimer")


def main() -> int:
    errors: list[str] = []
    verify_contract(errors)
    verify_release_classification(errors)
    verify_active_docs(errors)
    verify_historical_disclaimer(errors)

    if errors:
        print("FAIL: ZKML quarantine guard detected regression(s):", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("PASS: ZKML quarantine guard confirms fail-closed source, release exclusion, and documentation boundaries.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
