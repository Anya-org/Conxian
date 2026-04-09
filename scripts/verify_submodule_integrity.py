from __future__ import annotations

"""Verify that this repo's submodule pins stay aligned with upstream defaults.

This check queries the GitHub REST API. It is intended to be CI-gating, and
requires network access plus a token via GITHUB_TOKEN or GH_TOKEN.
"""

import configparser
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
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
) -> list[str]:
    failures: list[str] = []
    default_branch_cache: dict[str, str] = {}

    for path, url in sorted(gitmodules.items()):
        sha = gitlinks.get(path)
        if not sha:
            continue

        repo = _parse_github_repo(url)
        if not repo:
            failures.append(f"{path}: unsupported submodule url {url}")
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

        failures.append(
            f"{path}: pinned {sha[:12]} is not on {repo}@{default_branch} (status={status}, ahead_by={ahead_by}, behind_by={behind_by})"
        )

    return failures


def verify() -> None:
    repo_root = _git_root()
    gitlinks = _parse_gitlinks(repo_root)
    gitmodules, invalid_sections = _parse_gitmodules(repo_root / ".gitmodules")
    gitmodules_paths = set(gitmodules)
    gitlink_paths = set(gitlinks)

    if invalid_sections:
        lines = [
            "Submodule integrity check failed:",
            "\nInvalid .gitmodules entries (missing path and/or url):",
            *[f"  - {s}" for s in sorted(invalid_sections)],
        ]
        raise RuntimeError("\n".join(lines))

    missing_mappings = sorted(gitlink_paths - gitmodules_paths)
    extra_mappings = sorted(gitmodules_paths - gitlink_paths)

    pin_failures: list[str] = []
    if not missing_mappings and not extra_mappings:
        pin_failures = _verify_submodule_pins(gitmodules, gitlinks)

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
