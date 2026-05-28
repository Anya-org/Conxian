from __future__ import annotations

import re
import subprocess
import sys
import traceback
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
CHECKLIST_REL_PATH = "docs/WALLET_LIFECYCLE_CONTROL_CHECKLIST.md"

REQUIRED_GATE_HEADINGS: tuple[str, ...] = (
    "Verify gate",
    "Release gate",
    "Operate gate",
)

REQUIRED_CONTROL_IDS: tuple[str, ...] = (
    "VER-1",
    "VER-2",
    "REL-1",
    "REL-2",
    "OPS-1",
    "OPS-2",
)

REQUIRED_CROSS_REFERENCE_LINKS: tuple[str, ...] = (
    "./OPERATING_MODEL_LIFECYCLE_CONTROL_OWNERSHIP.md",
    "./PROMOTION_CHECKLISTS.md",
    "./MAINNET_READINESS_CONXIUS_WALLET.md",
    "./WALLET_SIGNER_CONTROL_VERIFICATION_REPORT.md",
    "./COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md",
    "./DEPLOYMENT_VERIFICATION_MATRIX.md",
)


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


def _has_heading(text: str, heading: str) -> bool:
    return bool(
        re.search(
            rf"(?im)^\s{{0,3}}#{{1,6}}\s+.*\b{re.escape(heading)}\b",
            text,
        )
    )


def _has_control_id(text: str, control_id: str) -> bool:
    # Use alphanumeric/dash boundaries so IDs like VER-1 are matched exactly.
    return bool(
        re.search(
            rf"(?<![A-Za-z0-9-]){re.escape(control_id)}(?![A-Za-z0-9-])",
            text,
        )
    )


def _has_markdown_link(text: str, target: str) -> bool:
    return bool(re.search(rf"\[[^\]]+\]\({re.escape(target)}\)", text))


def verify() -> None:
    repo_root = _repo_root()
    checklist_path = repo_root / CHECKLIST_REL_PATH

    errors: list[str] = []

    if not checklist_path.exists():
        errors.append(f"Missing required checklist: {CHECKLIST_REL_PATH}")
    elif not checklist_path.is_file():
        errors.append(f"Checklist path is not a file: {CHECKLIST_REL_PATH}")

    if errors:
        lines = [
            "Wallet lifecycle control gates check failed:",
            "",
            *[f"- {e}" for e in errors],
        ]
        raise RuntimeError("\n".join(lines))

    text = checklist_path.read_text(encoding="utf-8", errors="replace")

    for heading in REQUIRED_GATE_HEADINGS:
        if not _has_heading(text, heading):
            errors.append(
                f"{CHECKLIST_REL_PATH}: missing required gate heading containing '{heading}'"
            )

    for control_id in REQUIRED_CONTROL_IDS:
        if not _has_control_id(text, control_id):
            errors.append(
                f"{CHECKLIST_REL_PATH}: missing required lifecycle control identifier '{control_id}'"
            )

    for target in REQUIRED_CROSS_REFERENCE_LINKS:
        if not _has_markdown_link(text, target):
            errors.append(
                f"{CHECKLIST_REL_PATH}: missing required cross-reference link to '{target}'"
            )

    if errors:
        lines = [
            "Wallet lifecycle control gates check failed:",
            "",
            *[f"- {e}" for e in errors],
        ]
        raise RuntimeError("\n".join(lines))

    print("Wallet lifecycle control gates: OK")


if __name__ == "__main__":
    try:
        verify()
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
    except Exception:
        traceback.print_exc()
        sys.exit(1)
