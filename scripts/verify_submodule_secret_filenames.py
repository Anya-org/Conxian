from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


def _repo_root() -> Path:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except (FileNotFoundError, subprocess.CalledProcessError) as exc:
        raise RuntimeError(f"Failed to determine repo root via git: {exc}") from exc
    return Path(out.strip())


def _read_submodule_paths(repo_root: Path) -> list[str]:
    gitmodules = repo_root / ".gitmodules"
    if not gitmodules.exists():
        return []

    try:
        out = subprocess.check_output(
            [
                "git",
                "config",
                "-f",
                gitmodules.as_posix(),
                "--null",
                "--get-regexp",
                r"^submodule\..*\.path$",
            ],
            stderr=subprocess.STDOUT,
        )
    except subprocess.CalledProcessError as exc:
        # `git config --get-regexp` returns exit code 1 when no keys match.
        if exc.returncode == 1 and not exc.output:
            return []

        msg = os.fsdecode(exc.output) if exc.output else str(exc)
        raise RuntimeError(f"Failed to read submodule paths via git config: {msg}") from exc
    except FileNotFoundError as exc:
        raise RuntimeError(f"Failed to read submodule paths via git config: {exc}") from exc

    paths: list[str] = []
    records = [p for p in out.split(b"\x00") if p]
    for record in records:
        if b"\n" not in record:
            continue
        _, value_raw = record.split(b"\n", 1)
        value = os.fsdecode(value_raw).strip().strip("/")
        if value:
            paths.append(value)

    return sorted(set(paths))


def _assert_initialized_submodule(submodule_dir: Path, submodule_path: str) -> None:
    if not submodule_dir.exists():
        raise RuntimeError(
            f"Submodule not initialized: {submodule_path}\n"
            "Run: git submodule update --init --recursive"
        )

    try:
        inside_work_tree = subprocess.check_output(
            [
                "git",
                "-C",
                submodule_dir.as_posix(),
                "rev-parse",
                "--is-inside-work-tree",
            ],
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        resolved_toplevel = subprocess.check_output(
            ["git", "-C", submodule_dir.as_posix(), "rev-parse", "--show-toplevel"],
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        raise RuntimeError(
            f"Submodule not initialized: {submodule_path}\n"
            "Run: git submodule update --init --recursive"
        ) from exc

    if inside_work_tree.strip().lower() != "true":
        raise RuntimeError(
            f"Submodule not initialized: {submodule_path}\n"
            "Run: git submodule update --init --recursive"
        )

    toplevel = resolved_toplevel.strip()
    if not toplevel:
        raise RuntimeError(
            f"Submodule not initialized: {submodule_path}\n"
            "Run: git submodule update --init --recursive"
        )

    expected_toplevel = submodule_dir.resolve()
    actual_toplevel = Path(toplevel).resolve()
    if actual_toplevel != expected_toplevel:
        raise RuntimeError(
            f"Submodule not initialized or misresolved: {submodule_path}\n"
            "Git resolved this path to a different repository context.\n"
            f"Expected top-level: {expected_toplevel.as_posix()}\n"
            f"Resolved top-level: {actual_toplevel.as_posix()}\n"
            "Run: git submodule update --init --recursive"
        )


def _git_ls_files(repo_dir: Path) -> list[str]:
    try:
        out = subprocess.check_output(
            ["git", "-C", repo_dir.as_posix(), "ls-files", "-z"],
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


def _secret_filename_violation(rel_path: str) -> str | None:
    rel_path = _normalize_path(rel_path)
    base = rel_path.rsplit("/", 1)[-1]

    lower = base.lower()
    is_example = any(token in lower for token in ("example", "sample", "template"))
    label = "Secrets and env files"

    if lower == ".env":
        return label
    if lower.startswith(".env.") and not is_example:
        return label
    if lower in {"secrets.json", "id_rsa", "id_ed25519", "id_ecdsa"}:
        return label
    if lower.endswith((".pem", ".key", ".p12", ".pfx")):
        return label

    return None


def verify(repo_root: Path, targets: list[str]) -> None:
    known_submodules = set(_read_submodule_paths(repo_root))

    unknown = sorted([p for p in targets if p not in known_submodules])
    if unknown:
        if known_submodules:
            known_block = "Known submodules:\n  - " + "\n  - ".join(sorted(known_submodules))
        else:
            known_block = (
                "No submodules found in .gitmodules."
                if (repo_root / ".gitmodules").exists()
                else ".gitmodules not found."
            )

        raise RuntimeError("Unknown submodule path(s): " + ", ".join(unknown) + "\n\n" + known_block)

    violations: dict[str, dict[str, list[str]]] = {}

    for submodule_path in targets:
        submodule_dir = repo_root / submodule_path
        _assert_initialized_submodule(submodule_dir, submodule_path)

        for rel_path in _git_ls_files(submodule_dir):
            rel_path = _normalize_path(rel_path)
            label = _secret_filename_violation(rel_path)
            if not label:
                continue

            bucket = violations.setdefault(submodule_path, {})
            bucket.setdefault(label, []).append(rel_path)

    if not violations:
        print("Submodule secret filename hygiene: OK")
        return

    lines: list[str] = ["Submodule secret filename hygiene: FAILED", ""]
    for submodule_path in sorted(violations.keys()):
        lines.append(f"{submodule_path}:")
        for label, paths in sorted(violations[submodule_path].items()):
            lines.append(f"  {label}:")
            for p in sorted(set(paths)):
                lines.append(f"    - {p}")
        lines.append("")

    lines.extend(
        [
            "Remediation:",
            "  - Remove the file(s) from the submodule Git index.",
            "  - Prefer committed templates (`.env.example`) and local-only `.env` files.",
        ]
    )

    raise RuntimeError("\n".join(lines).rstrip())


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Verify that selected submodules do not track secret-bearing filenames "
            "(e.g., .env, private keys)."
        )
    )

    parser.add_argument(
        "--all",
        action="store_true",
        help="Scan all submodules listed in .gitmodules.",
    )
    parser.add_argument(
        "--submodule",
        action="append",
        default=[],
        help="Submodule path to scan (repeatable). Default: conxian-nexus.",
    )

    return parser.parse_args(argv)


if __name__ == "__main__":
    args = _parse_args(sys.argv[1:])
    try:
        repo_root = _repo_root()
        known = _read_submodule_paths(repo_root)

        if args.all:
            targets = known
        else:
            targets = args.submodule or (["conxian-nexus"] if "conxian-nexus" in known else [])

        if not targets:
            raise RuntimeError(
                "No submodules selected for scanning (and conxian-nexus is not present in .gitmodules)."
            )

        verify(repo_root, targets)
    except RuntimeError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
