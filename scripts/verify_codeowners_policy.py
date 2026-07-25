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


def parse_rule_lines(source: str) -> list[tuple[int, str, tuple[str, ...]]]:
    """Return every non-comment CODEOWNERS rule with its source line."""
    rule_lines: list[tuple[int, str, tuple[str, ...]]] = []
    for line_number, raw_line in enumerate(source.splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        rule_lines.append((line_number, fields[0], tuple(fields[1:])))
    return rule_lines


def parse_rules(source: str) -> dict[str, tuple[str, ...]]:
    """Return the final owner tuple for each literal CODEOWNERS pattern."""
    rules: dict[str, tuple[str, ...]] = {}
    for _, pattern, owners in parse_rule_lines(source):
        rules[pattern] = owners
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

    source = (repo_root / AUTHORITATIVE_LOCATION).read_text(encoding="utf-8")
    rule_lines = parse_rule_lines(source)
    rules = parse_rules(source)
    errors: list[str] = []

    for line_number, pattern, owners in rule_lines:
        for owner in REQUIRED_OWNERS:
            if owner not in owners:
                errors.append(
                    f"CODEOWNERS rule {pattern!r} on line {line_number} "
                    f"is missing required owner {owner}"
                )

    if "*" not in rules:
        errors.append("missing global CODEOWNERS rule '*'")

    for protected_path in REQUIRED_PROTECTED_PATHS:
        if protected_path not in rules:
            errors.append(f"missing explicit CODEOWNERS rule for {protected_path}")

    return errors


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    repo_root = Path(args[0]).resolve() if args else Path(__file__).resolve().parents[1]
    errors = verify_policy(repo_root)
    if errors:
        for error in errors:
            print(f"CODEOWNERS policy error: {error}", file=sys.stderr)
        return 1
    print(
        "CODEOWNERS policy verified: root CODEOWNERS is authoritative and "
        "every rule retains required owners"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
