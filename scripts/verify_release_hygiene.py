from __future__ import annotations

import configparser
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


UNRELEASED_RE = re.compile(r"^##\s*\[Unreleased\]\s*$", re.MULTILINE)


TAG_EXPECTATION_SUBMODULE_PATHS = {
    "conxius-wallet",
    "conxian-gateway",
    "conxian-nexus",
    "conxius-platform",
}


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


def _notice(kind: str, message: str) -> None:
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print(f"::{kind}::{message}")
    else:
        print(f"{kind.upper()}: {message}")


def _warning(message: str) -> None:
    _notice("warning", message)


def _error(message: str) -> None:
    _notice("error", message)


def _parse_gitmodules(repo_root: Path) -> dict[str, str]:
    gitmodules_path = repo_root / ".gitmodules"
    if not gitmodules_path.exists():
        return {}

    config = configparser.ConfigParser(interpolation=None)
    config.read(gitmodules_path, encoding="utf-8")

    mappings: dict[str, str] = {}
    for section in config.sections():
        if not section.startswith('submodule "'):
            continue

        path = config.get(section, "path", fallback="").strip()
        url = config.get(section, "url", fallback="").strip()
        if not path or not url:
            continue

        mappings[path] = url

    return mappings


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


def _github_json(path: str) -> list | dict:
    url = f"https://api.github.com{path}"
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "conxian-business-release-hygiene",
    }

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def _repo_tag_status(repo: str) -> tuple[int, str | None]:
    data = _github_json(f"/repos/{repo}/tags?per_page=1")
    if not isinstance(data, list):
        raise RuntimeError(f"Unexpected tags response for {repo}: {type(data)}")
    if not data:
        return 0, None
    name = (data[0] or {}).get("name")
    return 1, str(name) if name else None


def _verify_root_changelog(repo_root: Path) -> list[str]:
    changelog_path = repo_root / "CHANGELOG.md"
    if not changelog_path.exists():
        return ["Missing root CHANGELOG.md"]

    text = changelog_path.read_text(encoding="utf-8", errors="replace")
    if not UNRELEASED_RE.search(text):
        return [
            "Root CHANGELOG.md must include an '## [Unreleased]' section (Keep a Changelog)."
        ]

    return []


def _is_checked_out_submodule(submodule_path: Path) -> bool:
    return (submodule_path / ".git").exists()


def _verify_submodule_changelog(rel_path: str, submodule_path: Path) -> None:
    changelog_path = submodule_path / "CHANGELOG.md"
    if not changelog_path.exists():
        _warning(f"{rel_path}: Missing CHANGELOG.md")
        return

    text = changelog_path.read_text(encoding="utf-8", errors="replace")
    if not UNRELEASED_RE.search(text):
        _warning(
            f"{rel_path}: CHANGELOG.md is missing an '## [Unreleased]' section"
        )


def verify() -> None:
    repo_root = _git_root()

    errors = _verify_root_changelog(repo_root)
    for err in errors:
        _error(err)
    if errors:
        raise RuntimeError("Release hygiene check failed")

    gitmodules = _parse_gitmodules(repo_root)
    for rel_path in sorted(gitmodules):
        if rel_path not in TAG_EXPECTATION_SUBMODULE_PATHS:
            continue

        submodule_path = repo_root / rel_path
        if not _is_checked_out_submodule(submodule_path):
            _warning(f"{rel_path}: submodule is not checked out; cannot validate CHANGELOG.md")
            continue
        _verify_submodule_changelog(rel_path, submodule_path)

    # Tag expectations (advisory for now): user-facing repos should have release tags.
    repos_to_check: dict[str, str] = {}

    origin_url = _run_git(["remote", "get-url", "origin"]).strip()
    origin_repo = _parse_github_repo(origin_url)

    check_origin_tags = (
        os.environ.get("VERIFY_RELEASE_HYGIENE_CHECK_ORIGIN_TAGS", "").lower() == "true"
    )
    if check_origin_tags and origin_repo:
        repos_to_check["."] = origin_repo

    for rel_path, url in sorted(gitmodules.items()):
        if rel_path not in TAG_EXPECTATION_SUBMODULE_PATHS:
            continue
        gh_repo = _parse_github_repo(url)
        if gh_repo:
            repos_to_check[rel_path] = gh_repo

    for rel_path, gh_repo in sorted(repos_to_check.items()):
        try:
            count, latest = _repo_tag_status(gh_repo)
        except (urllib.error.HTTPError, urllib.error.URLError, RuntimeError) as exc:
            _warning(f"{rel_path}: unable to fetch tags for {gh_repo} ({exc})")
            continue

        if count == 0:
            _warning(
                f"{rel_path}: {gh_repo} has no git tags yet. User-facing repos should cut tagged releases (vX.Y.Z)."
            )
        else:
            note = f" (latest: {latest})" if latest else ""
            print(f"Release tags: OK for {rel_path} -> {gh_repo}{note}")


if __name__ == "__main__":
    try:
        verify()
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
