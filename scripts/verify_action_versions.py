#!/usr/bin/env python3
"""Validate that all `uses:` action references in workflow YAML files point to real versions.

Queries the GitHub API to confirm each owner/repo[/path]@ref exists. Exits non-zero if any
reference is invalid, catching issues like `actions/checkout@v6` (doesn't exist).
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import TypedDict

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_DIR = REPO_ROOT / ".github" / "workflows"

EXCLUDE_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"^\./"),  # local composite actions
    re.compile(r"^docker://"),  # Docker images
)

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN", "")

CACHE_FILE = REPO_ROOT / ".github" / ".action-version-cache.json"
CACHE_SCHEMA_VERSION = 2
CACHE_TTL_OK_SECONDS = 7 * 24 * 60 * 60

REQUEST_TIMEOUT_SECONDS = 15


class CacheEntry(TypedDict):
    exists: bool
    detail: str
    checkedAt: int


def _load_cache() -> dict[str, CacheEntry]:
    if not CACHE_FILE.exists():
        return {}

    try:
        payload = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}

    # Deterministic invalidation: only accept known schema; discard legacy bool maps.
    if not isinstance(payload, dict):
        return {}
    if payload.get("schemaVersion") != CACHE_SCHEMA_VERSION:
        return {}

    entries = payload.get("entries")
    if not isinstance(entries, dict):
        return {}

    cache: dict[str, CacheEntry] = {}
    for action_ref, raw in entries.items():
        if not isinstance(action_ref, str) or not isinstance(raw, dict):
            continue

        exists = raw.get("exists")
        detail = raw.get("detail")
        checked_at = raw.get("checkedAt")
        if not isinstance(exists, bool):
            continue
        if not isinstance(detail, str):
            continue
        if not isinstance(checked_at, (int, float)):
            continue

        cache[action_ref] = {
            "exists": exists,
            "detail": detail,
            "checkedAt": int(checked_at),
        }

    return cache


def _save_cache(cache: dict[str, CacheEntry]) -> None:
    payload = {
        "schemaVersion": CACHE_SCHEMA_VERSION,
        "entries": dict(sorted(cache.items())),
    }
    CACHE_FILE.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _cache_lookup(cache: dict[str, CacheEntry], action_ref: str) -> tuple[bool, str] | None:
    entry = cache.get(action_ref)
    if not entry:
        return None

    # Deterministic refresh strategy: only cache definitive successes for a bounded TTL.
    if not entry["exists"] or entry["detail"] != "exists":
        return None

    age = int(time.time()) - entry["checkedAt"]
    if age < 0 or age > CACHE_TTL_OK_SECONDS:
        return None

    return True, "cached-OK"


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
            if "@" not in raw:
                continue
            refs.setdefault(raw, []).append(rel)
    return refs


def _parse_action_ref(action_ref: str) -> tuple[str, str, str | None] | None:
    if "@" not in action_ref:
        return None

    repo_and_path, ref = action_ref.split("@", 1)
    pieces = [piece for piece in repo_and_path.split("/") if piece]
    if len(pieces) < 2:
        return None

    repo_slug = f"{pieces[0]}/{pieces[1]}"
    action_path = "/".join(pieces[2:]) or None
    return repo_slug, ref, action_path


def _github_api_status(url: str) -> tuple[int | None, str | None]:
    headers = {"Accept": "application/vnd.github.v3+json"}
    if GITHUB_TOKEN:
        headers["Authorization"] = f"Bearer {GITHUB_TOKEN}"

    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            return getattr(response, "status", 200), None
    except urllib.error.HTTPError as exc:
        return exc.code, None
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return None, str(exc)


def _evaluate_status(
    status: int | None,
    *,
    not_found_detail: str,
    network_error: str | None,
) -> tuple[bool, str | None]:
    if status == 200:
        return True, None
    if status == 404:
        return False, not_found_detail
    if status == 403:
        return True, "skipped (rate limited, HTTP 403)"
    if status is None:
        return True, f"skipped (network error: {network_error or 'unknown'})"
    return True, f"skipped (HTTP {status})"


def _check_ref(action_ref: str) -> tuple[bool, str]:
    """Query GitHub API to check if action ref exists. Returns (exists, detail)."""
    parsed = _parse_action_ref(action_ref)
    if parsed is None:
        return False, f"malformed action ref: {action_ref}"

    repo_slug, ref, action_path = parsed

    is_major_tag = bool(re.fullmatch(r"v\d+", ref))
    is_full_sha = bool(re.fullmatch(r"[0-9a-fA-F]{40}", ref))
    if not is_major_tag and not is_full_sha:
        return True, f"skipped (non-version ref: {ref})"

    if is_major_tag:
        url = f"https://api.github.com/repos/{repo_slug}/git/ref/tags/{urllib.parse.quote(ref, safe='')}"
        status, network_error = _github_api_status(url)
        exists, detail = _evaluate_status(
            status,
            not_found_detail="tag not found (404)",
            network_error=network_error,
        )
        if not exists or detail is not None:
            return exists, detail or "tag check failed"
    else:
        # Pinned action SHAs are commit refs, not tags.
        url = f"https://api.github.com/repos/{repo_slug}/commits/{urllib.parse.quote(ref, safe='')}"
        status, network_error = _github_api_status(url)
        exists, detail = _evaluate_status(
            status,
            not_found_detail="commit not found (404)",
            network_error=network_error,
        )
        if not exists or detail is not None:
            return exists, detail or "commit check failed"

    if action_path:
        encoded_path = urllib.parse.quote(action_path, safe="/")
        encoded_ref = urllib.parse.quote(ref, safe="")
        path_url = (
            f"https://api.github.com/repos/{repo_slug}/contents/{encoded_path}?ref={encoded_ref}"
        )
        status, network_error = _github_api_status(path_url)
        exists, detail = _evaluate_status(
            status,
            not_found_detail=f"action path not found at ref (404): {action_path}",
            network_error=network_error,
        )
        if not exists or detail is not None:
            return exists, detail or "action path check failed"

    return True, "exists"


def main() -> int:
    refs = _extract_uses_refs()
    if not refs:
        print("No action references found in workflow files.")
        return 0

    print(f"Checking {len(refs)} unique action reference(s)...\n")
    cache = _load_cache()

    # Keep cache aligned with current workflow refs.
    active_refs = set(refs)
    for stale_ref in list(cache):
        if stale_ref not in active_refs:
            del cache[stale_ref]

    errors: list[str] = []
    checked = 0

    for action_ref, files in sorted(refs.items()):
        cached = _cache_lookup(cache, action_ref)
        if cached is not None:
            exists, status = cached
        else:
            exists, detail = _check_ref(action_ref)
            status = detail

            if exists and detail == "exists":
                cache[action_ref] = {
                    "exists": True,
                    "detail": detail,
                    "checkedAt": int(time.time()),
                }
            else:
                cache.pop(action_ref, None)

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
        print("\nThese version refs do not exist on GitHub. Check for typos or removed versions.")
        return 1

    print(f"\n✅ All {checked} action version(s) valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
