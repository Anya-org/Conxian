from __future__ import annotations

import math
import os
import re
import subprocess
import sys
import traceback
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent


@dataclass(frozen=True)
class RequiredFile:
    rel_path: str
    min_bytes: int


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


PARENT_CONTROL_ALIGNMENT_PATH = "docs/CONXIAN_BUSINESS_PARENT_CONTROL_ALIGNMENT.md"


REQUIRED_FILES: tuple[RequiredFile, ...] = (
    RequiredFile("README.md", 256),
    RequiredFile("LICENSE", 256),
    RequiredFile("SECURITY.md", 256),
    RequiredFile("CONTRIBUTING.md", 256),
    RequiredFile("GOVERNANCE.md", 128),
    RequiredFile("CHANGELOG.md", 256),
    RequiredFile("RELEASING.md", 128),
    RequiredFile(".github/RELEASE_HYGIENE.md", 256),
    RequiredFile(PARENT_CONTROL_ALIGNMENT_PATH, 512),
)

PORTFOLIO_DOCS: tuple[RequiredFile, ...] = (RequiredFile("docs/REPO_PORTFOLIO.md", 256),)

CODEOWNERS_CANDIDATES: tuple[str, ...] = (
    ".github/CODEOWNERS",
    "CODEOWNERS",
    "docs/CODEOWNERS",
)

CODEOWNERS_MIN_BYTES = 64

def _is_truthy_env(var_name: str) -> bool:
    return os.environ.get(var_name, "").strip().lower() in {
        "1",
        "true",
        "yes",
        "y",
        "on",
    }


def _find_codeowners(repo_root: Path) -> list[Path]:
    found: list[Path] = []
    for rel_path in CODEOWNERS_CANDIDATES:
        path = repo_root / rel_path
        if path.is_file():
            found.append(path)
    return found


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def _require_heading(text: str, heading: str) -> bool:
    return bool(
        re.search(
            rf"(?im)^\s{{0,3}}#{{1,3}}\s+{re.escape(heading)}\b",
            text,
        )
    )


def _verify_readme(repo_root: Path, errors: list[str]) -> None:
    text = _read_text(repo_root / "README.md")

    for required in ("Purpose", "Status", "Ownership"):
        if not _require_heading(text, required):
            errors.append(f"README.md: missing required section heading '{required}'")


def _verify_security(repo_root: Path, errors: list[str]) -> None:
    text = _read_text(repo_root / "SECURITY.md")
    if not re.search(
        r"(?im)^\s{0,3}#{1,3}\s+reporting\s+a\s+vulnerabilit(y|ies)\b",
        text,
    ):
        errors.append("SECURITY.md: missing 'Reporting a Vulnerability' section")


def _verify_contributing(repo_root: Path, errors: list[str]) -> None:
    text = _read_text(repo_root / "CONTRIBUTING.md")
    if not re.search(r"(?i)pull\s+request", text):
        errors.append("CONTRIBUTING.md: missing Pull Request guidance")


def _verify_codeowners(codeowners: Path, *, repo_root: Path, errors: list[str]) -> None:
    rel_path = codeowners.relative_to(repo_root).as_posix()
    lines = _read_text(codeowners).splitlines()

    owner_lines = [
        line.strip()
        for line in lines
        if line.strip() and not line.strip().startswith("#")
    ]

    if not owner_lines:
        errors.append(f"{rel_path}: no ownership rules found")
        return

    covers_all = any(line.split() and line.split()[0] == "*" for line in owner_lines)
    if not covers_all:
        errors.append(f"{rel_path}: must include a '*' rule to cover the entire repo")
    has_github_owner = any(
        token.startswith("@") for line in owner_lines for token in line.split()[1:]
    )
    if not has_github_owner:
        errors.append(f"{rel_path}: no GitHub usernames found in ownership rules")


def _verify_changelog(repo_root: Path, errors: list[str]) -> None:
    text = _read_text(repo_root / "CHANGELOG.md")
    if not re.search(r"^##\s*\[Unreleased\]\s*$", text, re.MULTILINE):
        errors.append("CHANGELOG.md: missing '## [Unreleased]' section")


def _verify_parent_control_alignment(repo_root: Path, errors: list[str]) -> None:
    text = _read_text(repo_root / PARENT_CONTROL_ALIGNMENT_PATH)

    required_headings = (
        "Scope boundary",
        "Control-domain mapping",
        "Confidentiality",
        "Operating policy",
        "Service management",
        "Quality",
        "Risk",
        "Rollback",
        "Evidence expectations",
        "Rollback and accountability expectations",
        "Definition of done",
    )
    for heading in required_headings:
        if not _require_heading(text, heading):
            errors.append(
                PARENT_CONTROL_ALIGNMENT_PATH
                + f": missing required section heading '{heading}'"
            )


def verify() -> None:
    repo_root = _repo_root()
    errors: list[str] = []
    missing: set[str] = set()

    required_files = list(REQUIRED_FILES)
    if _is_truthy_env("BOS_REQUIRE_PORTFOLIO_DOCS"):
        required_files.extend(PORTFOLIO_DOCS)

    raw_multiplier = os.environ.get("GOVERNANCE_MIN_BYTES_MULTIPLIER", "1")
    try:
        min_bytes_multiplier = float(raw_multiplier)
        if not math.isfinite(min_bytes_multiplier) or min_bytes_multiplier <= 0:
            raise ValueError
    except ValueError:
        errors.append(
            "GOVERNANCE_MIN_BYTES_MULTIPLIER must be a positive, finite number, got "
            + repr(raw_multiplier)
        )
        min_bytes_multiplier = 1.0

    for required in required_files:
        path = repo_root / required.rel_path
        if not path.exists():
            errors.append(f"Missing required file: {required.rel_path}")
            missing.add(required.rel_path)
            continue
        if not path.is_file():
            errors.append(f"Required path is not a file: {required.rel_path}")
            missing.add(required.rel_path)
            continue

        required_min = math.ceil(required.min_bytes * min_bytes_multiplier)
        size = path.stat().st_size
        if required_min > 0 and size < required_min:
            errors.append(
                f"Required file too small ({size} bytes < {required_min}): {required.rel_path}"
            )

    if "README.md" not in missing:
        _verify_readme(repo_root, errors)
    if "SECURITY.md" not in missing:
        _verify_security(repo_root, errors)
    if "CONTRIBUTING.md" not in missing:
        _verify_contributing(repo_root, errors)

    found_codeowners = _find_codeowners(repo_root)
    if not found_codeowners:
        errors.append(
            "CODEOWNERS: missing (expected one of: "
            + ", ".join(CODEOWNERS_CANDIDATES)
            + ")"
        )
    elif len(found_codeowners) > 1:
        rels = ", ".join(str(path.relative_to(repo_root)) for path in found_codeowners)
        errors.append(f"Multiple CODEOWNERS files found: {rels}; keep exactly one")
    else:
        codeowners = found_codeowners[0]
        rel_path = codeowners.relative_to(repo_root).as_posix()
        required_min = math.ceil(CODEOWNERS_MIN_BYTES * min_bytes_multiplier)
        size = codeowners.stat().st_size
        if required_min > 0 and size < required_min:
            errors.append(
                f"Required file too small ({size} bytes < {required_min}): {rel_path}"
            )
        else:
            _verify_codeowners(codeowners, repo_root=repo_root, errors=errors)

    if "CHANGELOG.md" not in missing:
        _verify_changelog(repo_root, errors)
    if PARENT_CONTROL_ALIGNMENT_PATH not in missing:
        _verify_parent_control_alignment(repo_root, errors)

    if errors:
        lines = ["Repository governance baseline: FAILED", "", *[f"- {e}" for e in errors]]
        raise RuntimeError("\n".join(lines))

    if os.environ.get("GITHUB_ACTIONS") == "true":
        print("::notice::Repository governance baseline: OK")
    else:
        print("Repository governance baseline: OK")


if __name__ == "__main__":
    try:
        verify()
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
    except Exception:
        traceback.print_exc()
        sys.exit(1)
