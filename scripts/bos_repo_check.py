from __future__ import annotations

import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent


@dataclass(frozen=True)
class Check:
    label: str
    argv: tuple[str, ...]


CHECKS: tuple[Check, ...] = (
    Check(
        "Knowledge retention (ZSE)",
        (sys.executable, str(SCRIPT_DIR / "verify_knowledge_retention.py")),
    ),
    Check(
        "Tracked artifacts",
        (sys.executable, str(SCRIPT_DIR / "verify_tracked_artifacts.py")),
    ),
    Check(
        "BOS production boundary",
        (sys.executable, str(SCRIPT_DIR / "verify_bos_production_boundary.py")),
    ),
    Check(
        "Submodule integrity",
        (sys.executable, str(SCRIPT_DIR / "verify_submodule_integrity.py")),
    ),
    Check(
        "Release hygiene",
        (sys.executable, str(SCRIPT_DIR / "verify_release_hygiene.py")),
    ),
    Check(
        "Governance baseline",
        (sys.executable, str(SCRIPT_DIR / "verify_repo_governance_baseline.py")),
    ),
    Check(
        "Contamination guard",
        (sys.executable, str(SCRIPT_DIR / "verify_contamination_guard.py")),
    ),
)


def _run(check: Check) -> int:
    print(f"\n==> {check.label}")
    proc = subprocess.run(check.argv, check=False)
    return int(proc.returncode)


def main() -> int:
    failures: list[str] = []
    for check in CHECKS:
        status = _run(check)
        if status != 0:
            failures.append(f"{check.label} (exit {status})")

    if failures:
        print("\nBOS repo-check: FAILED")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("\nBOS repo-check: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
