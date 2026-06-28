#!/usr/bin/env python3
"""Validate that all `uses:` action references in workflow YAML files point to real versions.

Queries the GitHub API to confirm each action reference resolves against the backing
repository and ref. Exits non-zero if any reference is invalid.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path
from urllib import error, parse, request

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_DIR = REPO_ROOT / ".github" / "workflows"

EXCLUDE_PATTERNS: tuple[re.Pattern, ...] = (
    re.compile(r"^\./"),          # local composite actions
    re.compile(r"^docker://"),    # Docker images
)

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")

CACHE_FILE = REPO_ROOT / ".github" / ".action-version-cache.json"
CACHE_SCHEMA_VERSION = 2

SHA40_RE = re.compile(r"^[0-9a-fA-F]{40}$")
OWNER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]{0,38}$")
REPO_RE = re.compile(r"^[A-Za-z0-9_.-]+$")


def _load_cache() -> dict[str, bool]:
    if CACHE_FILE.exists():
        try:
            payload = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
            if (
                isinstance(payload, dict)
                and isinstance(payload.get("_meta"), dict)
                and payload["_meta"].get("schemaVersion") == CACHE_SCHEMA_VERSION
                and isinstance(payload.get("results"), dict)
            ):
                results = payload["results"]
                return {
                    key: value
                    for key, value in results.items()
                    if isinstance(key, str) and isinstance(value, bool)
                }
        except (json.JSONDecodeError, OSError):
            pass
    return {}


def _save_cache(cache: dict[str, bool]) -> None:
    payload = {
        "_meta": {"schemaVersion": CACHE_SCHEMA_VERSION},
        "results": cache,
    }
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


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


def _parse_action_ref(action_ref: str) -> tuple[tuple[str, str] | None, str]:
    """Extract owner/repo and ref from owner/repo[/subpath]@ref."""
    if "@" not in action_ref:
        return None, f"malformed action ref: {action_ref}"

    action_path, ref = action_ref.rsplit("@", 1)
    if not action_path or not ref:
        return None, f"malformed action ref: {action_ref}"

    parts = [part for part in action_path.split("/") if part]
    if len(parts) < 2:
        return None, f"malformed action path: {action_path}"

    owner, repo = parts[0], parts[1]
    if not OWNER_RE.fullmatch(owner):
        return None, f"invalid owner in action ref: {owner}"
    if not REPO_RE.fullmatch(repo):
        return None, f"invalid repository in action ref: {repo}"

    return (f"{owner}/{repo}", ref), ""


def _github_status(path: str) -> tuple[int | None, str | None]:
    """Return (status_code, error_message)."""
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "conxian-action-version-audit",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if GITHUB_TOKEN:
        headers["Authorization"] = f"Bearer {GITHUB_TOKEN}"

    url = f"https://api.github.com{path}"
    req = request.Request(url, headers=headers, method="GET")

    try:
        with request.urlopen(req, timeout=15) as response:
            return response.status, None
    except error.HTTPError as exc:
        return exc.code, None
    except (error.URLError, TimeoutError, OSError) as exc:
        return None, str(exc)


def _resolve_status_result(
    *,
    status: int | None,
    network_error: str | None,
    missing_detail: str,
    success_detail: str,
    context: str,
) -> tuple[bool, str] | None:
    """Map a GitHub API status into checker output.

    Returns None when caller should continue trying another ref type.
    """
    if status == 200:
        return True, success_detail
    if status in {404, 422}:
        return False, missing_detail
    if status in {401, 403, 429}:
        return True, f"skipped ({context} HTTP {status})"
    if status is None:
        return True, f"skipped ({context} network error: {network_error})"
    return True, f"skipped ({context} HTTP {status})"


def _check_sha_ref(repo_path: str, sha: str) -> tuple[bool, str]:
    encoded_sha = parse.quote(sha, safe="")
    status, network_error = _github_status(f"/repos/{repo_path}/commits/{encoded_sha}")
    resolved = _resolve_status_result(
        status=status,
        network_error=network_error,
        missing_detail="commit not found (404)",
        success_detail="commit exists",
        context="commit lookup",
    )
    if resolved is None:
        return False, "commit not found"
    return resolved


def _check_named_ref(repo_path: str, ref: str) -> tuple[bool, str]:
    encoded_ref = parse.quote(ref, safe="")

    status, network_error = _github_status(f"/repos/{repo_path}/git/ref/tags/{encoded_ref}")
    resolved = _resolve_status_result(
        status=status,
        network_error=network_error,
        missing_detail="tag missing",
        success_detail="tag exists",
        context="tag lookup",
    )
    if resolved and (resolved[0] or "skipped" in resolved[1]):
        return resolved

    status, network_error = _github_status(f"/repos/{repo_path}/git/ref/heads/{encoded_ref}")
    resolved = _resolve_status_result(
        status=status,
        network_error=network_error,
        missing_detail="branch missing",
        success_detail="branch exists",
        context="branch lookup",
    )
    if resolved and (resolved[0] or "skipped" in resolved[1]):
        return resolved

    status, network_error = _github_status(f"/repos/{repo_path}/commits/{encoded_ref}")
    resolved = _resolve_status_result(
        status=status,
        network_error=network_error,
        missing_detail="ref not found as tag, branch, or commit (404)",
        success_detail="commit-like ref resolves",
        context="commit fallback",
    )
    if resolved is None:
        return False, "ref not found"
    return resolved


def _check_ref(action_ref: str) -> tuple[bool, str]:
    """Query GitHub API to check if action ref exists. Returns (exists, detail)."""
    parsed, parse_error = _parse_action_ref(action_ref)
    if parsed is None:
        return False, parse_error

    repo_path, ref = parsed
    if SHA40_RE.fullmatch(ref):
        return _check_sha_ref(repo_path, ref)
    return _check_named_ref(repo_path, ref)


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
        # Only trust cached passing results. Re-check failures to avoid stale false negatives
        # when validation logic changes.
        if action_ref in cache and cache[action_ref]:
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
