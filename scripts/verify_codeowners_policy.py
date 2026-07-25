#!/usr/bin/env python3
"""Validate the repository's deterministic CODEOWNERS policy."""

from __future__ import annotations

from pathlib import Path
import sys


SUPPORTED_LOCATIONS = (
    Path(".github/CODEOWNERS"),
    Path("CODEOWNERS"),
    Path("docs/CODEOWNERS"),
)
AUTHORITATIVE_LOCATION = Path("CODEOWNERS")
REQUIRED_OWNERS = ("@botshelomokoka", "@admin-conxian-labs")
REQUIRED_PROTECTED_PATHS = (
    "/.github/",
    "/CODEOWNERS",
    "/contracts/",
    "/scripts/",
    "/deployments/",
    "/docs/",
)


def parse_rules(source: str) -> dict[str, tuple[str, ...]]:
    """Return the final owner tuple for each literal CODEOWNERS pattern."""
    rules: dict[str, tuple[str, ...]] = {}
    for raw_line in source.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        rules[fields[0]] = tuple(fields[1:])
    return rules


def verify_policy(repo_root: Path) -> list[str]:
    """Return deterministic policy errors for ``repo_root``."""
    existing = [
        relative_path
        for relative_path in SUPPORTED_LOCATIONS
        if (repo_root / relative_path).is_file()
    ]
    if existing != [AUTHORITATIVE_LOCATION]:
        rendered = ", ".join(path.as_posix() for path in existing) or "none"
        return [
            "exactly root CODEOWNERS must exist in GitHub-supported locations; "
            f"found: {rendered}"
        ]

    rules = parse_rules((repo_root / AUTHORITATIVE_LOCATION).read_text(encoding="utf-8"))
    errors: list[str] = []

    global_owners = rules.get("*", ())
    for owner in REQUIRED_OWNERS:
        if owner not in global_owners:
            errors.append(f"global rule '*' is missing required owner {owner}")

    for protected_path in REQUIRED_PROTECTED_PATHS:
        owners = rules.get(protected_path)
        if owners is None:
            errors.append(f"missing explicit CODEOWNERS rule for {protected_path}")
            continue
        for owner in REQUIRED_OWNERS:
            if owner not in owners:
                errors.append(
                    f"CODEOWNERS rule for {protected_path} is missing required owner {owner}"
                )

    return errors


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    repo_root = Path(args[0]).resolve() if args else Path(__file__).resolve().parents[1]
    errors = verify_policy(repo_root)
    if errors:
        for error in errors:
            print(f"CODEOWNERS policy error: {error}", file=sys.stderr)
        return 1
    print("CODEOWNERS policy verified: root CODEOWNERS is authoritative")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
