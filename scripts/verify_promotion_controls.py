from __future__ import annotations

import fnmatch
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class GitHubApiError(RuntimeError):
    def __init__(self, *, path: str, status: int, message: str) -> None:
        super().__init__(f"GitHub API request failed: {path} -> HTTP {status}: {message}")
        self.path = path
        self.status = status
        self.message = message


@dataclass(frozen=True)
class BranchMeta:
    name: str
    protected: bool


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


def _origin_repo_slug(repo_root: Path) -> str:
    origin_url = _run_git(["-C", repo_root.as_posix(), "remote", "get-url", "origin"]).strip()
    repo_slug = _parse_github_repo(origin_url)
    if not repo_slug:
        raise RuntimeError(f"Unable to parse GitHub repo slug from origin url: {origin_url}")
    return repo_slug


def _github_json(path: str) -> Any:
    url = f"https://api.github.com{path}"
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "conxian-business-promotion-controls",
    }

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(url, headers=headers)

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        message = body
        try:
            payload = json.loads(body)
            if isinstance(payload, dict) and payload.get("message"):
                message = str(payload.get("message"))
        except json.JSONDecodeError:
            pass

        raise GitHubApiError(path=path, status=e.code, message=message) from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"GitHub API request failed: {path} -> {e.reason}") from e


def _verify_promotion_workflow(repo_root: Path) -> list[str]:
    workflow_path = repo_root / ".github" / "workflows" / "branch-promotion-policy.yml"
    if not workflow_path.exists():
        return [f"Missing workflow: {workflow_path.relative_to(repo_root).as_posix()}"]

    content = workflow_path.read_text(encoding="utf-8", errors="replace")
    failures: list[str] = []

    required_snippets = {
        "main promotion guard": "if (baseRef === 'main' && headRef !== 'staged')",
        "staged promotion guard": "if (baseRef === 'staged')",
        "in-repo promotion guard": "Promotions into '${baseRef}' must come from an in-repo branch",
    }

    for label, snippet in required_snippets.items():
        if snippet not in content:
            failures.append(
                f"branch-promotion-policy.yml missing required {label} snippet: {snippet}"
            )

    return failures


def _load_branch_meta(repo_slug: str, branch: str) -> BranchMeta:
    path = f"/repos/{repo_slug}/branches/{urllib.parse.quote(branch, safe='')}"
    payload = _github_json(path)
    if not isinstance(payload, dict):
        raise RuntimeError(f"Unexpected branch metadata payload for {branch}: {type(payload)}")

    return BranchMeta(
        name=branch,
        protected=bool(payload.get("protected", False)),
    )


def _load_repo_default_branch(repo_slug: str) -> str:
    path = f"/repos/{repo_slug}"
    payload = _github_json(path)
    if not isinstance(payload, dict):
        raise RuntimeError(f"Unexpected repository metadata payload: {type(payload)}")

    default_branch = payload.get("default_branch")
    if not isinstance(default_branch, str) or not default_branch:
        raise RuntimeError("Repository metadata did not include a default branch")

    return default_branch


def _include_pattern_matches_ref(*, ref: str, pattern: str, default_branch: str | None) -> bool:
    if pattern == "~ALL":
        return True

    if pattern == "~DEFAULT_BRANCH":
        if not default_branch:
            return False
        return ref == f"refs/heads/{default_branch}"

    return fnmatch.fnmatch(ref, pattern)


def _ref_matches_rule_patterns(
    *,
    ref: str,
    includes: list[str],
    excludes: list[str],
    default_branch: str | None,
) -> bool:
    if not includes:
        return False

    included = any(
        _include_pattern_matches_ref(
            ref=ref,
            pattern=pattern,
            default_branch=default_branch,
        )
        for pattern in includes
    )
    excluded = any(fnmatch.fnmatch(ref, pattern) for pattern in excludes)
    return included and not excluded


def _branch_covered_by_active_ruleset(
    rulesets: list[dict[str, Any]],
    branch: str,
    default_branch: str | None,
) -> bool:
    ref = f"refs/heads/{branch}"

    for ruleset in rulesets:
        if not isinstance(ruleset, dict):
            continue
        if ruleset.get("target") != "branch":
            continue
        if ruleset.get("enforcement") != "active":
            continue

        conditions = ruleset.get("conditions")
        if not isinstance(conditions, dict):
            continue

        ref_name = conditions.get("ref_name")
        if not isinstance(ref_name, dict):
            continue

        includes = ref_name.get("include")
        excludes = ref_name.get("exclude")
        if not isinstance(includes, list):
            continue
        if not isinstance(excludes, list):
            excludes = []

        include_patterns = [str(p) for p in includes]
        exclude_patterns = [str(p) for p in excludes]

        if _ref_matches_rule_patterns(
            ref=ref,
            includes=include_patterns,
            excludes=exclude_patterns,
            default_branch=default_branch,
        ):
            return True

    return False


def verify() -> None:
    repo_root = _git_root()
    repo_slug = _origin_repo_slug(repo_root)

    failures: list[str] = []

    failures.extend(_verify_promotion_workflow(repo_root))

    branch_meta: dict[str, BranchMeta] = {}
    for branch in ("dev", "staged", "main"):
        try:
            branch_meta[branch] = _load_branch_meta(repo_slug, branch)
        except GitHubApiError as e:
            if e.status == 404:
                failures.append(f"Missing required branch: {branch}")
                continue
            failures.append(f"Unable to read branch metadata for {branch}: {e}")
        except Exception as e:
            failures.append(f"Unable to read branch metadata for {branch}: {e}")

    rulesets: list[dict[str, Any]] = []
    rulesets_error: str | None = None
    default_branch: str | None = None
    default_branch_error: str | None = None

    try:
        default_branch = _load_repo_default_branch(repo_slug)
    except Exception as e:
        default_branch_error = str(e)

    try:
        payload = _github_json(f"/repos/{repo_slug}/rulesets?includes_parents=true")
        if isinstance(payload, list):
            rulesets = [r for r in payload if isinstance(r, dict)]
        else:
            rulesets_error = (
                f"Unexpected rulesets payload type: {type(payload).__name__}"
            )
    except GitHubApiError as e:
        # Rulesets may be unavailable on private repos without the feature plan.
        rulesets_error = str(e)
    except Exception as e:
        rulesets_error = str(e)

    if default_branch_error:
        if rulesets_error:
            rulesets_error = (
                f"{rulesets_error}; unable to resolve repository default branch: {default_branch_error}"
            )
        else:
            rulesets_error = (
                f"unable to resolve repository default branch: {default_branch_error}"
            )

    for branch in ("staged", "main"):
        meta = branch_meta.get(branch)
        if not meta:
            continue

        if meta.protected:
            continue

        if _branch_covered_by_active_ruleset(rulesets, branch, default_branch):
            continue

        if rulesets_error:
            failures.append(
                f"{branch}: branch is not protected and no active ruleset could be verified ({rulesets_error})"
            )
        else:
            failures.append(
                f"{branch}: branch is not protected and no active branch ruleset applies"
            )

    if failures:
        lines = ["Promotion controls check failed:", "", *[f"- {f}" for f in failures]]
        raise RuntimeError("\n".join(lines))

    print("Promotion controls: OK")


if __name__ == "__main__":
    try:
        verify()
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
