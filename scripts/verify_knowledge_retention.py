from __future__ import annotations

import fnmatch
import json
import subprocess
import sys
from functools import lru_cache
from pathlib import Path
from typing import Any

SENSITIVE_ROOTS = ("internal/strategy", "archive")
MANIFEST_PATH = Path("audit/migration_manifest.json")


def _run_git(args: list[str]) -> str:
    proc = subprocess.run(
        ["git", *args],
        check=False,
        capture_output=True,
        text=True,
    )

    if proc.returncode != 0:
        details = (proc.stderr or proc.stdout).strip() or f"exit code {proc.returncode}"
        raise RuntimeError(f"git {' '.join(args)} failed: {details}")

    return proc.stdout


def _git_root() -> Path:
    return Path(_run_git(["rev-parse", "--show-toplevel"]).strip())


def _git_paths(args: list[str]) -> list[str]:
    output = _run_git(["ls-files", "-z", *args])
    return [p for p in output.split("\0") if p]


def _is_sensitive_path(path: str) -> bool:
    return any(path == root or path.startswith(f"{root}/") for root in SENSITIVE_ROOTS)


def _load_manifest(path: Path) -> dict[str, dict[str, Any]]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as e:
        raise RuntimeError(f"Migration manifest not found at {path.as_posix()}") from e
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Migration manifest is not valid JSON: {path.as_posix()}") from e

    if not isinstance(data, dict):
        raise RuntimeError("Migration manifest must be a JSON object")

    parsed: dict[str, dict[str, Any]] = {}
    for key, val in data.items():
        if not isinstance(key, str):
            raise RuntimeError("Migration manifest keys must be strings")
        if not isinstance(val, dict):
            raise RuntimeError(
                f"Migration manifest entry {key} must be an object (expected {{paths: string[]}})"
            )

        paths = val.get("paths")
        if not isinstance(paths, list) or not all(isinstance(p, str) for p in paths):
            raise RuntimeError(f"Migration manifest entry {key}.paths must be a string array")

        parsed[key] = {"description": val.get("description"), "paths": paths}

    return parsed


def _split_posix(path: str) -> list[str]:
    return [p for p in path.split("/") if p]


def _matches(path: str, pattern: str) -> bool:
    if not pattern:
        return not path

    p_parts = tuple(_split_posix(path))
    pat_parts = tuple(_split_posix(pattern.lstrip("/")))

    @lru_cache(maxsize=None)
    def match_at(i: int, j: int) -> bool:
        if j == len(pat_parts):
            return i == len(p_parts)

        part = pat_parts[j]
        if part == "**":
            if match_at(i, j + 1):
                return True
            return i < len(p_parts) and match_at(i + 1, j)

        if i >= len(p_parts):
            return False

        return fnmatch.fnmatchcase(p_parts[i], part) and match_at(i + 1, j + 1)

    return match_at(0, 0)


def _matches_any(path: str, patterns: list[str]) -> bool:
    return any(_matches(path, pattern) for pattern in patterns)


def verify() -> None:
    repo_root = _git_root()
    manifest_path = repo_root / MANIFEST_PATH

    manifest = _load_manifest(manifest_path)
    con306 = manifest.get("CON-306")
    if con306 is None:
        raise RuntimeError("Master Strategy Migration issue (CON-306) not found in manifest")

    required_con306_patterns = ["internal/strategy/**", "archive/**"]
    missing_con306 = [p for p in required_con306_patterns if p not in con306["paths"]]
    if missing_con306:
        raise RuntimeError(
            "CON-306 must include coverage patterns for sensitive roots: " + ", ".join(missing_con306)
        )

    tracked = _git_paths([])
    tracked_sensitive = [p for p in tracked if _is_sensitive_path(p)]
    if tracked_sensitive:
        lines = [
            "Zero Secret Egress violation: tracked sensitive paths found:",
            *[f"  - {p}" for p in tracked_sensitive],
        ]
        raise RuntimeError("\n".join(lines))

    untracked_not_ignored = _git_paths(["--others", "--exclude-standard"])
    untracked_sensitive = [p for p in untracked_not_ignored if _is_sensitive_path(p)]
    if untracked_sensitive:
        lines = [
            "Sensitive paths found that are not ignored by git:",
            *[f"  - {p}" for p in untracked_sensitive],
            "",
            "Add these paths to .gitignore (or remove them) before proceeding.",
        ]
        raise RuntimeError("\n".join(lines))

    ignored_untracked = _git_paths(["--others", "-i", "--exclude-standard"])
    ignored_sensitive = [p for p in ignored_untracked if _is_sensitive_path(p)]

    all_patterns: list[str] = []
    for entry in manifest.values():
        all_patterns.extend(entry["paths"])

    missing_from_manifest = [p for p in ignored_sensitive if not _matches_any(p, all_patterns)]
    if missing_from_manifest:
        lines = [
            "Error: The following sensitive paths exist in the repo but are not covered by audit/migration_manifest.json patterns:",
            *[f"  - {p}" for p in missing_from_manifest],
            "",
            "Please migrate the knowledge to Linear and add the corresponding coverage patterns before ignoring these paths.",
        ]
        raise RuntimeError("\n".join(lines))

    print("Success: Knowledge retention manifest coverage verified.")


if __name__ == "__main__":
    try:
        verify()
    except Exception as e:
        print(str(e))
        sys.exit(1)
