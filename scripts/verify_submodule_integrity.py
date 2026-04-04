from __future__ import annotations

import configparser
import subprocess
import sys
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


def _parse_gitlinks(repo_root: Path) -> set[str]:
    output = _run_git(["-C", repo_root.as_posix(), "ls-files", "--stage"])
    gitlinks: set[str] = set()

    for raw_line in output.splitlines():
        parts = raw_line.split("\t", 1)
        if len(parts) != 2:
            continue

        meta, path = parts
        mode = meta.split(" ", 1)[0]
        if mode == "160000":
            gitlinks.add(path)

    return gitlinks


def _parse_gitmodules_paths(gitmodules_path: Path) -> tuple[set[str], list[str]]:
    if not gitmodules_path.exists():
        return set(), []

    config = configparser.ConfigParser(interpolation=None)
    config.read(gitmodules_path, encoding="utf-8")

    paths: set[str] = set()
    invalid_sections: list[str] = []
    for section in config.sections():
        if not section.startswith('submodule "'):
            continue

        path = config.get(section, "path", fallback="").strip()
        url = config.get(section, "url", fallback="").strip()

        if not path or not url:
            invalid_sections.append(section)
            continue
        paths.add(path)

    return paths, invalid_sections


def verify() -> None:
    repo_root = _git_root()
    gitlinks = _parse_gitlinks(repo_root)
    gitmodules_paths, invalid_sections = _parse_gitmodules_paths(repo_root / ".gitmodules")

    if invalid_sections:
        lines = [
            "Submodule integrity check failed:",
            "\nInvalid .gitmodules entries (missing path and/or url):",
            *[f"  - {s}" for s in sorted(invalid_sections)],
        ]
        raise RuntimeError("\n".join(lines))

    missing_mappings = sorted(gitlinks - gitmodules_paths)
    extra_mappings = sorted(gitmodules_paths - gitlinks)

    if not missing_mappings and not extra_mappings:
        print("Success: .gitmodules mappings match gitlink entries.")
        return

    lines: list[str] = ["Submodule integrity check failed:"]
    if missing_mappings:
        lines.append("\nGitlinks in index with no .gitmodules entry:")
        lines.extend([f"  - {p}" for p in missing_mappings])
    if extra_mappings:
        lines.append("\n.gitmodules entries with no gitlink in index:")
        lines.extend([f"  - {p}" for p in extra_mappings])

    raise RuntimeError("\n".join(lines))


if __name__ == "__main__":
    try:
        verify()
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
