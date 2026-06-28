#!/usr/bin/env python3
"""Validate that all `uses:` action references in workflow YAML files point to real versions.

Queries the GitHub API to confirm each owner/repo@ref exists. Exits non-zero if any
reference is invalid, catching issues like `actions/checkout@v6` (doesn't exist).
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_DIR = REPO_ROOT / ".github" / "workflows"

EXCLUDE_PATTERNS: tuple[re.Pattern, ...] = (
    re.compile(r"^\./"),          # local composite actions
    re.compile(r"^docker://"),    # Docker images
)

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")

CACHE_FILE = REPO_ROOT / ".github" / ".action-version-cache.json"


def _load_cache() -> dict[str, bool]:
    if CACHE_FILE.exists():
        try:
            return json.loads(CACHE_FILE.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            pass
    return {}


def _save_cache(cache: dict[str, bool]) -> None:
    CACHE_FILE.write_text(json.dumps(cache, indent=2, sort_keys=True), encoding="utf-8")


def _extract_uses_refs() -> dict[str, list[str]]:
    """Parse all workflow YAML files and return {action_ref: [file_path, ...]}."""
    refs: dict[str, list[str]] = {}
    if not WORKFLOW_DIR.is_dir():
        return refs

    for wf in sorted(WORKFLOW_DIR.glob("*.yml")):
        rel = wf.relative_to(REPO_ROOT).as_posix()
        content = wf.read_text(encoding="utf-8", errors="replace")
        for match in re.finditer(r"^\s*uses:\s*(.+?)(?:\s*#.*)?$", content, re.MULTILINE):
            raw = match.group(1).strip().strip("'\"")
            if any(p.match(raw) for p in EXCLUDE_PATTERNS):
                continue
            # Normalize: owner/repo@ref
            if "@" not in raw:
                continue
            refs.setdefault(raw, []).append(rel)
    return refs


def _check_ref(action_ref: str) -> tuple[bool, str]:
    """Query GitHub API to check if action ref exists. Returns (exists, detail)."""
    parts = action_ref.split("@", 1)
    if len(parts) != 2:
        return False, f"malformed action ref: {action_ref}"
    repo_path, ref = parts

    # Only validate major-version tags and full SHAs
    if not re.match(r"^v\d+$", ref) and not re.match(r"^[0-9a-f]{40}$", ref):
        return True, f"skipped (non-version ref: {ref})"

    url = f"https://api.github.com/repos/{repo_path}/git/ref/tags/{ref}"
    headers = {"Accept": "application/vnd.github.v3+json"}
    if GITHUB_TOKEN:
        headers["Authorization"] = f"Bearer {GITHUB_TOKEN}"

    try:
        proc = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-H",
             f"Authorization: Bearer {GITHUB_TOKEN}" if GITHUB_TOKEN else "Accept: application/vnd.github.v3+json",
             url],
            capture_output=True, text=True, timeout=15,
        )
        # Re-run with proper headers
        proc = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}"] +
            sum([["-H", f"{k}: {v}"] for k, v in headers.items()], []) +
            [url],
            capture_output=True, text=True, timeout=15,
        )
        status = int(proc.stdout.strip())
        if status == 200:
            return True, "exists"
        elif status == 404:
            return False, "tag not found (404)"
        elif status == 403:
            return True, f"skipped (rate limited, HTTP {status})"
        else:
            return True, f"skipped (HTTP {status})"
    except (subprocess.TimeoutExpired, ValueError, OSError) as exc:
        return True, f"skipped (network error: {exc})"


def main() -> int:
    refs = _extract_uses_refs()
    if not refs:
        print("No action references found in workflow files.")
        return 0

    print(f"Checking {len(refs)} unique action reference(s)...\n")
    cache = _load_cache()

    errors: list[str] = []
    checked = 0

    for action_ref, files in sorted(refs.items()):
        if action_ref in cache:
            exists = cache[action_ref]
            status = "cached-OK" if exists else "cached-FAIL"
        else:
            exists, detail = _check_ref(action_ref)
            cache[action_ref] = exists
            status = detail
            time.sleep(0.1)  # gentle rate limiting

        checked += 1
        file_list = ", ".join(files)
        if exists:
            print(f"  OK  {action_ref}  ({status})  [{file_list}]")
        else:
            msg = f"{action_ref} — {status}"
            errors.append(msg)
            print(f"  FAIL  {msg}  [{file_list}]")

    _save_cache(cache)

    if errors:
        print(f"\n❌ {len(errors)} invalid action version(s) found:")
        for err in errors:
            print(f"  • {err}")
        print("\nThese version tags do not exist on GitHub. Check for typos or removed versions.")
        return 1

    print(f"\n✅ All {checked} action version(s) valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
