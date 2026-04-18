from __future__ import annotations

"""Verify that this repo's submodule pins stay aligned with upstream defaults.

This check queries the GitHub REST API. It is intended to be CI-gating, and
requires network access plus a token via GITHUB_TOKEN or GH_TOKEN.
"""

import configparser
import dataclasses
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path


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


def _parse_gitlinks(repo_root: Path) -> dict[str, str]:
    output = _run_git(["-C", repo_root.as_posix(), "ls-files", "--stage"])
    gitlinks: dict[str, str] = {}

    for raw_line in output.splitlines():
        parts = raw_line.split("\t", 1)
        if len(parts) != 2:
            continue

        meta, path = parts
        mode = meta.split(" ", 1)[0]
        if mode == "160000":
            sha = meta.split(" ", 2)[1]
            gitlinks[path] = sha

    return gitlinks


def _parse_gitmodules(gitmodules_path: Path) -> tuple[dict[str, str], list[str]]:
    if not gitmodules_path.exists():
        return {}, []

    config = configparser.ConfigParser(interpolation=None)
    config.read(gitmodules_path, encoding="utf-8")

    mappings: dict[str, str] = {}
    invalid_sections: list[str] = []
    for section in config.sections():
        if not section.startswith('submodule "'):
            continue

        path = config.get(section, "path", fallback="").strip()
        url = config.get(section, "url", fallback="").strip()

        if not path or not url:
            invalid_sections.append(section)
            continue

        mappings[path] = url

    return mappings, invalid_sections


def _parse_github_repo(url: str) -> str | None:
    if url.startswith("git@github.com:"):
        url = "ssh://" + url.replace("git@github.com:", "git@github.com/", 1)

    parsed = urllib.parse.urlparse(url)
    if parsed.hostname != "github.com":
        return None

    parts = [p for p in parsed.path.strip("/").split("/") if p]
    if len(parts) < 2:
        return None

    owner, repo = parts[0], parts[1]
    if repo.endswith(".git"):
        repo = repo[:-4]
    return f"{owner}/{repo}"


@dataclasses.dataclass(frozen=True)
class SubmodulePinAllowlistEntry:
    path: str
    sha: str
    expires_on: date
    reason: str


def _load_submodule_pin_allowlist(
    repo_root: Path,
) -> tuple[dict[str, dict[str, SubmodulePinAllowlistEntry]], list[str]]:
    allowlist_path = repo_root / ".github" / "submodule-integrity-allowlist.json"
    if not allowlist_path.exists():
        return {}, []

    failures: list[str] = []
    try:
        payload = json.loads(
            allowlist_path.read_text(encoding="utf-8", errors="replace")
        )
    except json.JSONDecodeError as e:
        return {}, [f"Invalid JSON in {allowlist_path}: {e}"]

    raw_entries = payload.get("entries") if isinstance(payload, dict) else None
    if not isinstance(raw_entries, list):
        return {}, [
            f"Invalid {allowlist_path}: expected top-level object with an 'entries' array."
        ]

    allowlist: dict[str, dict[str, SubmodulePinAllowlistEntry]] = {}
    today = date.today()
    for idx, raw_entry in enumerate(raw_entries):
        if not isinstance(raw_entry, dict):
            failures.append(
                f"Invalid allowlist entry at entries[{idx}]: expected object."
            )
            continue

        path = str(raw_entry.get("path") or "").strip()
        sha = str(raw_entry.get("sha") or "").strip().lower()
        expires_on = str(raw_entry.get("expiresOn") or "").strip()
        reason = str(raw_entry.get("reason") or "").strip()

        if not path:
            failures.append(f"Invalid allowlist entry at entries[{idx}]: missing path")
            continue

        if len(sha) != 40 or any(ch not in "0123456789abcdef" for ch in sha):
            failures.append(
                f"Invalid allowlist entry at entries[{idx}]: sha must be a 40-character hex string"
            )
            continue

        if not expires_on:
            failures.append(
                f"Invalid allowlist entry at entries[{idx}]: missing expiresOn (YYYY-MM-DD)"
            )
            continue

        try:
            expires_date = date.fromisoformat(expires_on)
        except ValueError:
            failures.append(
                f"Invalid allowlist entry at entries[{idx}]: expiresOn must be ISO date YYYY-MM-DD"
            )
            continue

        if expires_date < today:
            failures.append(
                f"Allowlist entry expired: {path}@{sha[:12]} expired on {expires_date.isoformat()}"
            )
            continue

        if not reason:
            failures.append(f"Invalid allowlist entry at entries[{idx}]: missing reason")
            continue

        bucket = allowlist.setdefault(path, {})
        if sha in bucket:
            failures.append(
                f"Duplicate allowlist entry for {path}@{sha[:12]} at entries[{idx}]"
            )
            continue

        bucket[sha] = SubmodulePinAllowlistEntry(
            path=path,
            sha=sha,
            expires_on=expires_date,
            reason=reason,
        )

    return allowlist, failures

class GitHubApiError(RuntimeError):
    pass


def _github_json(path: str) -> dict:
    url = f"https://api.github.com{path}"
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "conxian-business-submodule-integrity",
    }

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    def _truncate(value: str, limit: int = 200) -> str:
        if len(value) <= limit:
            return value
        return value[:limit] + "…"

    def _retry_delay(attempt: int, retry_after: str | None) -> float:
        delay = min(2**attempt, 8)
        if retry_after:
            try:
                delay = min(max(int(retry_after), 0), 8)
            except ValueError:
                pass
        return delay

    request = urllib.request.Request(url, headers=headers)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")
            message = body
            try:
                parsed = json.loads(body)
                if isinstance(parsed, dict) and parsed.get("message"):
                    message = str(parsed.get("message"))
            except json.JSONDecodeError:
                pass

            message = _truncate(message)

            lower_message = message.lower()
            is_rate_limited = e.code == 429 or (
                e.code == 403
                and ("rate limit" in lower_message or "abuse detection" in lower_message)
            )

            if (is_rate_limited or e.code in {500, 502, 503, 504}) and attempt < 2:
                error_headers = getattr(e, "headers", None)
                retry_after = error_headers.get("Retry-After") if error_headers else None
                time.sleep(_retry_delay(attempt, retry_after))
                continue

            raise GitHubApiError(
                f"GitHub API request failed: {url} -> {e.code}: {message}"
            ) from e
        except urllib.error.URLError as e:
            reason = str(e.reason)

            if attempt < 2:
                time.sleep(_retry_delay(attempt, None))
                continue

            raise GitHubApiError(f"GitHub API request failed: {url} -> {reason}") from e


def _verify_submodule_pins(
    gitmodules: dict[str, str],
    gitlinks: dict[str, str],
    allowlist: dict[str, dict[str, SubmodulePinAllowlistEntry]],
) -> list[str]:
    failures: list[str] = []
    default_branch_cache: dict[str, str] = {}

    allowlisted_hits: list[SubmodulePinAllowlistEntry] = []

    for path, url in sorted(gitmodules.items()):
        sha = gitlinks.get(path)
        if not sha:
            continue

        repo = _parse_github_repo(url)
        if not repo:
            failures.append(f"{path}: unsupported submodule url {url}")
            continue

        allowlisted_entry = allowlist.get(path, {}).get(sha.lower())
        if allowlisted_entry is not None:
            allowlisted_hits.append(allowlisted_entry)
            continue

        default_branch = default_branch_cache.get(repo)
        if not default_branch:
            try:
                repo_meta = _github_json(f"/repos/{repo}")
            except GitHubApiError as e:
                failures.append(f"{path}: GitHub API error for {repo}: {e}")
                continue
            default_branch = repo_meta.get("default_branch")
            if not default_branch:
                failures.append(f"{path}: unable to resolve default branch for {repo}")
                continue

            default_branch_cache[repo] = default_branch

        branch_ref = urllib.parse.quote(default_branch, safe="")
        try:
            compare = _github_json(f"/repos/{repo}/compare/{sha}...{branch_ref}")
        except GitHubApiError as e:
            failures.append(f"{path}: GitHub API error for {repo}@{default_branch}: {e}")
            continue
        status = compare.get("status")
        ahead_by = compare.get("ahead_by")
        behind_by = compare.get("behind_by")

        if status in {"identical", "ahead"}:
            continue

        allowlisted_entry = allowlist.get(path, {}).get(sha.lower())
        if allowlisted_entry is not None:
            allowlisted_hits.append(allowlisted_entry)
            continue

        failures.append(
            f"{path}: pinned {sha[:12]} is not on {repo}@{default_branch} (status={status}, ahead_by={ahead_by}, behind_by={behind_by})"
        )

    if allowlisted_hits:
        hits = ", ".join(
            (
                f"{e.path}@{e.sha[:12]} "
                f"(expiresOn={e.expires_on.isoformat()}, reason={e.reason})"
            )
            for e in sorted(allowlisted_hits, key=lambda e: (e.path, e.sha))
        )
        print(f"Note: allowlisted submodule pins in effect: {hits}")

    return failures


def verify() -> None:
    repo_root = _git_root()
    gitlinks = _parse_gitlinks(repo_root)
    gitmodules, invalid_sections = _parse_gitmodules(repo_root / ".gitmodules")
    allowlist, allowlist_failures = _load_submodule_pin_allowlist(repo_root)
    gitmodules_paths = set(gitmodules)
    gitlink_paths = set(gitlinks)

    allowlist_paths = set(allowlist)

    if invalid_sections:
        lines = [
            "Submodule integrity check failed:",
            "\nInvalid .gitmodules entries (missing path and/or url):",
            *[f"  - {s}" for s in sorted(invalid_sections)],
        ]
        raise RuntimeError("\n".join(lines))

    if allowlist_failures:
        lines = [
            "Submodule integrity check failed:",
            "\nInvalid submodule integrity allowlist:",
            *[f"  - {f}" for f in allowlist_failures],
        ]
        raise RuntimeError("\n".join(lines))

    unknown_allowlist_paths = sorted(allowlist_paths - gitmodules_paths)
    if unknown_allowlist_paths:
        lines = [
            "Submodule integrity check failed:",
            "\nSubmodule integrity allowlist contains unknown paths:",
            *[f"  - {p}" for p in unknown_allowlist_paths],
        ]
        raise RuntimeError("\n".join(lines))

    missing_mappings = sorted(gitlink_paths - gitmodules_paths)
    extra_mappings = sorted(gitmodules_paths - gitlink_paths)

    pin_failures: list[str] = []
    if not missing_mappings and not extra_mappings:
        pin_failures = _verify_submodule_pins(gitmodules, gitlinks, allowlist)

    if not missing_mappings and not extra_mappings and not pin_failures:
        print("Success: .gitmodules mappings match gitlink entries and submodule pins are on upstream default branches.")
        return

    lines: list[str] = ["Submodule integrity check failed:"]
    if missing_mappings:
        lines.append("\nGitlinks in index with no .gitmodules entry:")
        lines.extend([f"  - {p}" for p in missing_mappings])
    if extra_mappings:
        lines.append("\n.gitmodules entries with no gitlink in index:")
        lines.extend([f"  - {p}" for p in extra_mappings])

    if pin_failures:
        lines.append("\nSubmodule pins that are not on upstream default branches:")
        lines.extend([f"  - {p}" for p in pin_failures])

    raise RuntimeError("\n".join(lines))


if __name__ == "__main__":
    try:
        verify()
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
