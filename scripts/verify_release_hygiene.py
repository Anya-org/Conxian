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
CHANGELOG_RELEASE_RE = re.compile(
    r"^##\s*\[(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)\]\s*-\s*.+$",
    re.MULTILINE,
)
README_BOS_VERSION_RE = re.compile(r"\(BOS v(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)\)")


GOVERNED_PUBLIC_REPO_SUBMODULE_PATHS = {
    "Conxian",
    "conxius-wallet",
    "conxian-gateway",
    "conxian-nexus",
}

TAG_EXPECTATION_MODE_ENV = "VERIFY_RELEASE_HYGIENE_TAG_EXPECTATION_MODE"
VALID_TAG_EXPECTATION_MODES = {"warn", "require", "off"}


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


def _escape_gha_message(message: str) -> str:
    return message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def _notice(kind: str, message: str) -> None:
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print(f"::{kind}::{_escape_gha_message(message)}")
    else:
        print(f"{kind.upper()}: {message}")


def _warning(message: str) -> None:
    _notice("warning", message)


def _error(message: str) -> None:
    _notice("error", message)


def _tag_expectation_mode() -> str:
    raw = os.environ.get(TAG_EXPECTATION_MODE_ENV, "warn")
    mode = raw.strip().lower() or "warn"
    if mode not in VALID_TAG_EXPECTATION_MODES:
        allowed = ", ".join(sorted(VALID_TAG_EXPECTATION_MODES))
        raise RuntimeError(
            f"{TAG_EXPECTATION_MODE_ENV} must be one of: {allowed} (got {raw!r})"
        )
    return mode


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


def _latest_changelog_release_version(changelog_text: str) -> str | None:
    match = CHANGELOG_RELEASE_RE.search(changelog_text)
    return match.group(1) if match else None


def _verify_root_changelog(repo_root: Path) -> tuple[list[str], str | None]:
    changelog_path = repo_root / "CHANGELOG.md"
    if not changelog_path.exists():
        return ["Missing root CHANGELOG.md"], None

    text = changelog_path.read_text(encoding="utf-8", errors="replace")
    errors: list[str] = []

    if not UNRELEASED_RE.search(text):
        errors.append(
            "Root CHANGELOG.md must include an '## [Unreleased]' section (Keep a Changelog)."
        )

    latest_release = _latest_changelog_release_version(text)
    if latest_release is None:
        errors.append(
            "Root CHANGELOG.md must include at least one released section in the format '## [X.Y.Z] - YYYY-MM-DD'."
        )

    return errors, latest_release


def _verify_root_readme_version_marker(
    repo_root: Path, *, expected_version: str
) -> list[str]:
    readme_path = repo_root / "README.md"
    if not readme_path.exists():
        return ["Missing root README.md"]

    text = readme_path.read_text(encoding="utf-8", errors="replace")
    match = README_BOS_VERSION_RE.search(text)
    if not match:
        return [
            (
                "README.md must include a BOS version marker in the format "
                f"'(BOS vX.Y.Z)' and match the latest CHANGELOG.md release (expected v{expected_version})."
            )
        ]

    observed_version = match.group(1)
    if observed_version != expected_version:
        return [
            (
                f"README.md BOS version marker v{observed_version} must match the latest "
                f"CHANGELOG.md release v{expected_version}."
            )
        ]

    return []


def _is_checked_out_submodule(submodule_path: Path) -> bool:
    return (submodule_path / ".git").exists()


def _verify_submodule_changelog(rel_path: str, submodule_path: Path) -> None:
    changelog_path = submodule_path / "CHANGELOG.md"
    if not changelog_path.exists():
        _warning(f"[advisory][changelog] {rel_path}: Missing CHANGELOG.md")
        return

    text = changelog_path.read_text(encoding="utf-8", errors="replace")
    if not UNRELEASED_RE.search(text):
        _warning(
            f"[advisory][changelog] {rel_path}: CHANGELOG.md is missing an '## [Unreleased]' section"
        )


def verify() -> None:
    repo_root = _git_root()
    tag_mode = _tag_expectation_mode()

    print("Release hygiene policy:")
    print("- Blocking: root CHANGELOG.md includes '## [Unreleased]'.")
    if tag_mode == "off":
        print(
            f"- Advisory: strategic/public tag expectations disabled ({TAG_EXPECTATION_MODE_ENV}=off)."
        )
    elif tag_mode == "warn":
        print(
            f"- Advisory: strategic/public tag expectations run in warn mode ({TAG_EXPECTATION_MODE_ENV}=warn)."
        )
    else:
        print(
            f"- Blocking: strategic/public tag expectations run in require mode ({TAG_EXPECTATION_MODE_ENV}=require)."
        )

    errors, latest_release = _verify_root_changelog(repo_root)
    if latest_release is not None:
        errors.extend(
            _verify_root_readme_version_marker(
                repo_root, expected_version=latest_release
            )
        )

    for err in errors:
        _error(f"[blocking][changelog] {err}")
    if errors:
        raise RuntimeError("Release hygiene check failed")

    gitmodules = _parse_gitmodules(repo_root)
    for rel_path in sorted(gitmodules):
        if rel_path not in GOVERNED_PUBLIC_REPO_SUBMODULE_PATHS:
            continue

        submodule_path = repo_root / rel_path
        if not _is_checked_out_submodule(submodule_path):
            _warning(
                f"[advisory][changelog] {rel_path}: submodule is not checked out; cannot validate CHANGELOG.md"
            )
            continue
        _verify_submodule_changelog(rel_path, submodule_path)

    if tag_mode == "off":
        return

    # Tag expectations for strategic/public repos.
    repos_to_check: dict[str, str] = {}
    tag_failures: list[str] = []

    for rel_path in sorted(GOVERNED_PUBLIC_REPO_SUBMODULE_PATHS):
        url = gitmodules.get(rel_path)
        if not url:
            message = (
                f"{rel_path}: missing from .gitmodules; cannot validate tag expectations"
            )
            if tag_mode == "require":
                _error(f"[blocking][tags] {message}")
                tag_failures.append(message)
            else:
                _warning(f"[advisory][tags] {message}")
            continue
        gh_repo = _parse_github_repo(url)
        if not gh_repo:
            message = f"{rel_path}: unsupported repo URL in .gitmodules ({url})"
            if tag_mode == "require":
                _error(f"[blocking][tags] {message}")
                tag_failures.append(message)
            else:
                _warning(f"[advisory][tags] {message}")
            continue
        repos_to_check[rel_path] = gh_repo

    check_origin_tags = (
        os.environ.get("VERIFY_RELEASE_HYGIENE_CHECK_ORIGIN_TAGS", "").lower() == "true"
    )
    if check_origin_tags:
        try:
            origin_url = _run_git(["remote", "get-url", "origin"]).strip()
        except RuntimeError as exc:
            _warning(f".: unable to resolve origin remote; skipping origin tag check ({exc})")
        else:
            origin_repo = _parse_github_repo(origin_url)
            if origin_repo:
                repos_to_check["."] = origin_repo

    tag_failure_prefix = "[blocking][tags]" if tag_mode == "require" else "[advisory][tags]"

    for rel_path, gh_repo in sorted(repos_to_check.items()):
        try:
            count, latest = _repo_tag_status(gh_repo)
        except (urllib.error.HTTPError, urllib.error.URLError, RuntimeError) as exc:
            message = f"{rel_path}: unable to fetch tags for {gh_repo} ({exc})"
            if tag_mode == "require":
                _error(f"{tag_failure_prefix} {message}")
                tag_failures.append(message)
            else:
                _warning(f"{tag_failure_prefix} {message}")
            continue

        if count == 0:
            message = (
                f"{rel_path}: {gh_repo} has no git tags yet. Strategic/public repos should cut tagged releases (vX.Y.Z)."
            )
            if tag_mode == "require":
                _error(f"{tag_failure_prefix} {message}")
                tag_failures.append(message)
            else:
                _warning(f"{tag_failure_prefix} {message}")
        else:
            note = f" (latest: {latest})" if latest else ""
            check_level = "blocking" if tag_mode == "require" else "advisory"
            print(f"Release tags ({check_level}): OK for {rel_path} -> {gh_repo}{note}")

    if tag_failures:
        raise RuntimeError("Release hygiene check failed")


if __name__ == "__main__":
    try:
        verify()
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
