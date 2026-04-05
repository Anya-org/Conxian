from __future__ import annotations

import os
import re
import subprocess
import sys


def repo_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def git_ls_files(root: str) -> list[str]:
    try:
        out = subprocess.check_output(
            ["git", "-C", root, "ls-files", "-z"],
            stderr=subprocess.STDOUT,
        )
    except subprocess.CalledProcessError as exc:
        output = getattr(exc, "output", b"")
        output_text = output.decode("utf-8", "replace") if output else ""
        details = f"\n\nGit output:\n{output_text}" if output_text else ""
        raise SystemExit(
            f"Failed to list tracked files in {root!r}. Ensure this directory is a Git repo and submodules are initialized (e.g., `git submodule update --init --recursive`).{details}"
        ) from exc
    parts = [p for p in out.split(b"\x00") if p]
    return [os.fsdecode(p) for p in parts]


def is_excluded(rel_path: str, excluded: str) -> bool:
    excluded = excluded.strip("/")
    if not excluded:
        return False

    if "/" in excluded:
        return rel_path == excluded or rel_path.startswith(excluded + "/")

    parts = rel_path.split("/")
    return excluded in parts[:-1]


def read_text(root: str, rel_path: str) -> str:
    full_path = os.path.join(root, rel_path)
    with open(full_path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


NEXUS_EXCLUDED_PATHS: set[str] = {
    "lib-conxian-core",
    "src/api/dlc.rs",
    "src/api/identity.rs",
    "src/api/zkml.rs",
    "src/executor/mod.rs",
    "src/storage/kwil.rs",
    "src/storage/tableland.rs",
}


def scan_repo(
    root: str,
    label: str,
    excluded_dirs: set[str],
    patterns: list[tuple[str, re.Pattern[str]]],
) -> list[str]:
    code_exts = {
        ".rs",
        ".ts",
        ".tsx",
        ".js",
        ".mjs",
        ".cjs",
        ".py",
        ".sh",
        ".clar",
        ".yaml",
        ".yml",
        ".json",
        ".toml",
    }

    errors: list[str] = []
    for rel_path in git_ls_files(root):
        if any(is_excluded(rel_path, ex) for ex in excluded_dirs):
            continue

        if os.path.basename(rel_path) == "verify_contamination_guard.py":
            continue

        _, ext = os.path.splitext(rel_path)
        if ext not in code_exts:
            continue

        lines = read_text(root, rel_path).splitlines()
        for label_text, pattern in patterns:
            match_lineno: int | None = None
            for lineno, line in enumerate(lines, start=1):
                if pattern.search(line):
                    match_lineno = lineno
                    break

            if match_lineno is None:
                continue

            errors.append(
                f"{label}: prohibited marker '{label_text}' found in {rel_path}:{match_lineno}"
            )
            break

    return errors


def main() -> int:
    root = repo_root()

    common_excluded_dirs: set[str] = {
        "docs",
        "openspec",
        "audit",
        ".github",
        ".idx",
        "tests",
        "test",
    }

    errors: list[str] = []
    mock_pattern = re.compile(r"\bMOCK_[A-Z0-9_]+\b")
    stub_func_pattern = re.compile(r"\bstub-func\b")
    stub_comment_pattern = re.compile(r"\[STUB\]")

    patterns_default: list[tuple[str, re.Pattern[str]]] = [
        ("MOCK_", mock_pattern),
        ("stub-func", stub_func_pattern),
        ("[STUB]", stub_comment_pattern),
    ]

    errors.extend(scan_repo(root, "conxian-business", common_excluded_dirs, patterns_default))

    nexus_excluded_paths = common_excluded_dirs | NEXUS_EXCLUDED_PATHS

    submodules: dict[str, tuple[set[str], list[tuple[str, re.Pattern[str]]]]] = {
        "lib-conxian-core": (common_excluded_dirs, patterns_default),
        "lib-conclave-sdk": (common_excluded_dirs, patterns_default),
        "conxian-nexus": (nexus_excluded_paths, patterns_default),
    }

    for sub, (exclusions, patterns) in submodules.items():
        sub_path = os.path.join(root, sub)
        if not os.path.isdir(sub_path):
            continue
        errors.extend(scan_repo(sub_path, sub, exclusions, patterns))

    if errors:
        print("Production contamination guard violations found:\n")
        for err in sorted(errors):
            print(f"- {err}")
        return 1

    print("Production contamination guard: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
