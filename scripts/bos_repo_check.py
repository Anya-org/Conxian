from __future__ import annotations

import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent


def _repo_root() -> Path:
    try:
        out = subprocess.check_output(
            ["git", "-C", str(SCRIPT_DIR), "rev-parse", "--show-toplevel"],
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except (FileNotFoundError, OSError, subprocess.CalledProcessError) as exc:
        raise RuntimeError(f"Failed to determine repo root via git: {exc}") from exc
    return Path(out.strip())


@dataclass(frozen=True)
class Check:
    label: str
    argv: tuple[str, ...]
    env: dict[str, str] | None = None


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
        env={"BOS_REQUIRE_PORTFOLIO_DOCS": "true"},
    ),
    Check(
        "Promotion controls",
        (sys.executable, str(SCRIPT_DIR / "verify_promotion_controls.py")),
    ),
    Check(
        "Wallet lifecycle control gates",
        (sys.executable, str(SCRIPT_DIR / "verify_wallet_lifecycle_control_gates.py")),
    ),
    Check(
        "Contamination guard",
        (sys.executable, str(SCRIPT_DIR / "verify_contamination_guard.py")),
    ),
)


def _run(check: Check, *, cwd: Path) -> int:
    print(f"\n==> {check.label}", flush=True)
    env = os.environ.copy()
    if check.env:
        # Treat per-check env as defaults so callers can override via their shell.
        for key, value in check.env.items():
            env.setdefault(key, value)

    proc = subprocess.run(check.argv, check=False, cwd=str(cwd), env=env)
    return int(proc.returncode)


def main() -> int:
    try:
        repo_root = _repo_root()
    except RuntimeError as exc:
        print(f"\nBOS repo-check: FAILED\n- {exc}", flush=True)
        return 1

    print(f"Repo root: {repo_root}", flush=True)

    failures: list[str] = []
    for check in CHECKS:
        status = _run(check, cwd=repo_root)
        if status != 0:
            failures.append(f"{check.label} (exit {status})")

    if failures:
        print("\nBOS repo-check: FAILED", flush=True)
        for failure in failures:
            print(f"- {failure}", flush=True)
        return 1

    print("\nBOS repo-check: OK", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
