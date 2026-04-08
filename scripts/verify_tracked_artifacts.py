from __future__ import annotations

import fnmatch
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Rule:
    label: str
    patterns: tuple[str, ...]


def _repo_root() -> Path:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError as exc:
        raise RuntimeError(
            "git is not installed or not on PATH; cannot determine repository root"
        ) from exc
    except OSError as exc:
        raise RuntimeError(
            f"Failed to execute git to determine repository root: {exc}"
        ) from exc
    except subprocess.CalledProcessError as exc:
        raw_output = exc.output or ""
        output = raw_output.strip().replace("\n", " ")
        details = f": {output}" if output else ""
        raise RuntimeError(
            f"Failed to determine repo root via git (exit {exc.returncode}){details}"
        ) from exc
    return Path(out.strip())


def _read_submodule_paths(repo_root: Path) -> set[str]:
    gitmodules = repo_root / ".gitmodules"
    if not gitmodules.exists():
        return set()

    paths: set[str] = set()
    for raw_line in gitmodules.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line.startswith("path ="):
            continue
        _, value = line.split("=", 1)
        candidate = value.strip().strip("/")
        if candidate:
            paths.add(candidate)
    return paths


def _git_ls_files(repo_root: Path) -> list[str]:
    try:
        out = subprocess.check_output(
            ["git", "-C", repo_root.as_posix(), "ls-files", "-z"],
            stderr=subprocess.STDOUT,
        )
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        raise RuntimeError(f"Failed to enumerate tracked files via git: {exc}") from exc

    parts = [p for p in out.split(b"\x00") if p]
    return [os.fsdecode(p) for p in parts]


def _normalize_path(path: str) -> str:
    path = path.replace("\\", "/")
    while path.startswith("./"):
        path = path[2:]
    return path.strip("/")


def _is_in_dir(rel_path: str, rel_dir: str) -> bool:
    rel_path = _normalize_path(rel_path)
    rel_dir = _normalize_path(rel_dir)
    if not rel_dir:
        return False
    return rel_path == rel_dir or rel_path.startswith(rel_dir + "/")


def _load_allowlist(repo_root: Path) -> list[str]:
    allowlist_path = repo_root / ".github" / "artifact-scan-allowlist.txt"
    if not allowlist_path.exists():
        return []

    patterns: list[str] = []
    for raw_line in allowlist_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        patterns.append(_normalize_path(line))
    return patterns


def _is_allowlisted(rel_path: str, allowlist: list[str]) -> bool:
    """Return True if `rel_path` is allowlisted.

    Semantics (kept in sync with `.github/RELEASE_HYGIENE.md`):
    - Paths and patterns are normalized to forward slashes with no leading "./".
    - Matching is case-sensitive.
    - Patterns containing "/" are matched against the full normalized path
      (non-glob patterns also match directory prefixes).
    - Patterns without "/":
      - Plain strings (no glob wildcards: "*", "?", "[]") match basenames,
        exact normalized paths, and directory prefixes.
      - Glob patterns match basenames only (they do not match full normalized paths).
    """
    rel_path = _normalize_path(rel_path)
    base = rel_path.rsplit("/", 1)[-1]
    for raw_pattern in allowlist:
        pattern = _normalize_path(raw_pattern)
        has_glob = any(ch in pattern for ch in "*?[]")
        is_basename_pattern = "/" not in pattern

        if is_basename_pattern:
            if fnmatch.fnmatchcase(base, pattern):
                return True
        else:
            if fnmatch.fnmatchcase(rel_path, pattern):
                return True

        if not has_glob and (rel_path == pattern or rel_path.startswith(pattern + "/")):
            return True
    return False


def _match_any(rel_path: str, patterns: tuple[str, ...]) -> bool:
    rel_path = _normalize_path(rel_path)
    base = rel_path.rsplit("/", 1)[-1]
    for pattern in patterns:
        normalized = _normalize_path(pattern)

        if normalized.endswith("/**"):
            dir_name = normalized[:-3]
            if f"/{dir_name}/" in f"/{rel_path}/":
                return True
            continue

        if "/" in normalized:
            if fnmatch.fnmatchcase(rel_path, normalized):
                return True
            continue

        if fnmatch.fnmatchcase(base, normalized):
            return True
    return False


RULES: tuple[Rule, ...] = (
    Rule(
        "Vendored dependencies",
        (
            "node_modules/**",
            "vendor/**",
            "third_party/**",
            "3rdparty/**",
            "jspm_packages/**",
        ),
    ),
    Rule(
        "Build outputs",
        (
            "dist/**",
            "build/**",
            "out/**",
            ".next/**",
            "target/**",
            "debug/**",
            "release/**",
        ),
    ),
    Rule(
        "Test and coverage outputs",
        (
            "coverage/**",
            "test-results/**",
            "playwright-report/**",
            ".nyc_output/**",
            "junit.xml",
        ),
    ),
    Rule(
        "Runtime and tool state",
        (
            ".firebase/**",
            ".terraform/**",
            "*.tfstate",
            "*.tfstate.*",
            "__pycache__/**",
            ".pytest_cache/**",
            ".venv/**",
            "venv/**",
            "ENV/**",
        ),
    ),
    Rule(
        "Editor and OS metadata",
        (
            ".vscode/**",
            ".idea/**",
            ".DS_Store",
            "Thumbs.db",
            "*.swp",
            "*.swo",
        ),
    ),
    Rule(
        "Temp and scratch artifacts",
        (
            "*.tmp",
            "*.bak",
            "*.orig",
            "*.rej",
            "*.patch",
            "*.log",
            "code_review_input.txt",
            "debug_regex.js",
            "test_match.js",
        ),
    ),
)


def _secret_filename_violation(rel_path: str) -> str | None:
    rel_path = _normalize_path(rel_path)
    base = rel_path.rsplit("/", 1)[-1]

    lower = base.lower()
    is_example = any(token in lower for token in ("example", "sample", "template"))

    if base == ".env":
        return "Secrets and env files"
    if base.startswith(".env.") and not is_example:
        return "Secrets and env files"
    if base in {"secrets.json", "id_rsa", "id_ed25519"}:
        return "Secrets and env files"
    if base.endswith((".pem", ".key")):
        return "Secrets and env files"

    return None


def verify() -> None:
    repo_root = _repo_root()
    submodules = _read_submodule_paths(repo_root)
    excluded_dirs = set(submodules)
    allowlist = _load_allowlist(repo_root)

    excluded_paths = {p.rstrip("/") for p in excluded_dirs if p.rstrip("/")}
    repo_files = [
        p
        for p in _git_ls_files(repo_root)
        if not any(_is_in_dir(p, ex) for ex in excluded_paths)
    ]

    violations: dict[str, list[str]] = {}

    for rel_path in repo_files:
        rel_path = _normalize_path(rel_path)

        if _is_allowlisted(rel_path, allowlist):
            continue

        secret_label = _secret_filename_violation(rel_path)
        if secret_label:
            violations.setdefault(secret_label, []).append(rel_path)
            continue

        for rule in RULES:
            if _match_any(rel_path, rule.patterns):
                violations.setdefault(rule.label, []).append(rel_path)
                break

    if not violations:
        print("Tracked artifact hygiene: OK")
        return

    lines: list[str] = ["Tracked artifact hygiene: FAILED", ""]
    for label, paths in sorted(violations.items()):
        lines.append(f"{label}:")
        for p in sorted(set(paths)):
            lines.append(f"  - {p}")
        lines.append("")

    lines.extend(
        [
            "Remediation:",
            "  - Remove the file(s) from the Git index: git rm --cached <path>",
            "  - Add appropriate entries to .gitignore when needed.",
            "  - If a tracked path is intentional, allowlist it via .github/artifact-scan-allowlist.txt.",
        ]
    )

    raise RuntimeError("\n".join(lines).rstrip())


if __name__ == "__main__":
    try:
        verify()
    except RuntimeError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
