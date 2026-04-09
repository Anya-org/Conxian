from __future__ import annotations

import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class RequiredFile:
    rel_path: str
    min_bytes: int


def _repo_root() -> Path:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except (FileNotFoundError, OSError, subprocess.CalledProcessError) as exc:
        raise RuntimeError(f"Failed to determine repo root via git: {exc}") from exc
    return Path(out.strip())


REQUIRED_FILES: tuple[RequiredFile, ...] = (
    RequiredFile("README.md", 256),
    RequiredFile("LICENSE", 256),
    RequiredFile("SECURITY.md", 256),
    RequiredFile("CONTRIBUTING.md", 256),
    RequiredFile("CODEOWNERS", 64),
    RequiredFile("GOVERNANCE.md", 128),
    RequiredFile("CHANGELOG.md", 256),
    RequiredFile("RELEASING.md", 128),
    RequiredFile(".github/RELEASE_HYGIENE.md", 256),
    RequiredFile("docs/REPO_PORTFOLIO.md", 256),
)


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def _require_heading(text: str, heading: str) -> bool:
    return bool(re.search(rf"^##\s+{re.escape(heading)}\s*$", text, re.MULTILINE))


def _verify_readme(repo_root: Path, errors: list[str]) -> None:
    readme = repo_root / "README.md"
    text = _read_text(readme)

    for required in ("Purpose", "Status", "Ownership"):
        if not _require_heading(text, required):
            errors.append(f"README.md: missing required section heading '## {required}'")


def _verify_security(repo_root: Path, errors: list[str]) -> None:
    security = repo_root / "SECURITY.md"
    text = _read_text(security)
    if "Reporting a Vulnerability" not in text:
        errors.append("SECURITY.md: missing 'Reporting a Vulnerability' section")


def _verify_contributing(repo_root: Path, errors: list[str]) -> None:
    contributing = repo_root / "CONTRIBUTING.md"
    text = _read_text(contributing)
    if "Pull Request" not in text:
        errors.append("CONTRIBUTING.md: missing Pull Request guidance")


def _verify_codeowners(repo_root: Path, errors: list[str]) -> None:
    codeowners = repo_root / "CODEOWNERS"
    lines = _read_text(codeowners).splitlines()

    owner_lines = [
        line.strip()
        for line in lines
        if line.strip() and not line.strip().startswith("#")
    ]

    if not owner_lines:
        errors.append("CODEOWNERS: no ownership rules found")
        return

    covers_all = any(line.split() and line.split()[0] == "*" for line in owner_lines)
    if not covers_all:
        errors.append("CODEOWNERS: must include a '*' rule to cover the entire repo")

    has_github_owner = any("@" in token for line in owner_lines for token in line.split()[1:])
    if not has_github_owner:
        errors.append("CODEOWNERS: no GitHub usernames found in ownership rules")


def _verify_changelog(repo_root: Path, errors: list[str]) -> None:
    changelog = repo_root / "CHANGELOG.md"
    text = _read_text(changelog)
    if not re.search(r"^##\s*\[Unreleased\]\s*$", text, re.MULTILINE):
        errors.append("CHANGELOG.md: missing '## [Unreleased]' section")


def verify() -> None:
    repo_root = _repo_root()
    errors: list[str] = []
    missing: set[str] = set()

    for required in REQUIRED_FILES:
        path = repo_root / required.rel_path
        if not path.exists():
            errors.append(f"Missing required file: {required.rel_path}")
            missing.add(required.rel_path)
            continue
        if not path.is_file():
            errors.append(f"Required path is not a file: {required.rel_path}")
            missing.add(required.rel_path)
            continue
        size = path.stat().st_size
        if size < required.min_bytes:
            errors.append(
                f"Required file too small ({size} bytes < {required.min_bytes}): {required.rel_path}"
            )

    if "README.md" not in missing:
        _verify_readme(repo_root, errors)
    if "SECURITY.md" not in missing:
        _verify_security(repo_root, errors)
    if "CONTRIBUTING.md" not in missing:
        _verify_contributing(repo_root, errors)
    if "CODEOWNERS" not in missing:
        _verify_codeowners(repo_root, errors)
    if "CHANGELOG.md" not in missing:
        _verify_changelog(repo_root, errors)

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
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
