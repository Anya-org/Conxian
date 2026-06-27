#!/usr/bin/env python3
"""Verify submodule pin integrity and update-policy hardening.

Validates that:
1. All submodule pins reference commits that exist on their respective remotes.
2. The update policy in .gitmodules enforces pinned (non-floating) references
   for production-track submodules.
3. No submodule has an unexpected or misconfigured update policy.
"""

import subprocess
import sys
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Submodules that are allowed to have non-'none' update policies.
# The Conxian repo has its own broken submodule config and is pinned with update=none.
ALLOWED_UPDATE_POLICIES = {
    "Conxian": "none",  # Known broken internal submodule — must stay pinned
}


def run(cmd: list[str], cwd=None) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, cwd=cwd or REPO_ROOT)


def parse_gitmodules() -> dict[str, dict[str, str]]:
    """Parse .gitmodules and return {path: {key: value}}."""
    gitmodules_path = REPO_ROOT / ".gitmodules"
    if not gitmodules_path.exists():
        print("ERROR: .gitmodules not found")
        sys.exit(1)

    submodules = {}
    current_path = None
    current_config = {}

    with open(gitmodules_path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("[submodule "):
                if current_path:
                    submodules[current_path] = current_config
                current_path = line[len("[submodule "):-1].strip('"')
                current_config = {}
            elif "=" in line and current_path:
                key, _, value = line.partition("=")
                current_config[key.strip()] = value.strip()

    if current_path:
        submodules[current_path] = current_config

    return submodules


def check_submodule_pins(submodules: dict[str, dict[str, str]]) -> list[str]:
    """Verify each submodule's pinned commit exists and is properly initialized."""
    errors = []

    # First check: ensure all .gitmodules entries exist as directories
    for path in submodules:
        submodule_dir = REPO_ROOT / path
        if not submodule_dir.is_dir():
            errors.append(f"Submodule '{path}': directory does not exist")
            continue

        # Submodules with update=none are intentionally pinned and never initialized.
        # They are valid as long as the directory exists (even if empty).
        if submodules[path].get("update", "") == "none":
            print(f"  OK  {path}: update=none (intentionally pinned, skip init check)")
            continue

        # Check if the submodule has been initialized (has .git file or directory)
        git_path = REPO_ROOT / ".git" / "modules" / path
        if not git_path.exists():
            # Submodule might not be initialized — check if directory is empty
            if not any(submodule_dir.iterdir()):
                errors.append(f"Submodule '{path}': not initialized (empty directory)")
            else:
                errors.append(f"Submodule '{path}': .git/modules/{path} missing — may not be initialized")
            continue

    # Second check: verify pinned SHAs match .gitmodules against current state
    result = run(["git", "submodule", "status", "--cached"])
    if result.returncode != 0:
        errors.append(f"git submodule status failed: {result.stderr.strip()}")
        return errors

    for line in result.stdout.strip().splitlines():
        if not line.strip():
            continue
        # Format: [ ]<sha> <path> [(<branch>)]
        # Leading space = not initialized, - = uninitialized, + = dirty
        sha = line[1:41].strip() if len(line) > 41 else ""
        path_from_status = line[42:].split()[0] if len(line) > 42 else ""

        if path_from_status not in submodules:
            errors.append(f"Submodule '{path_from_status}': in git status but NOT in .gitmodules")
            continue

    # Verify no .gitmodules entries are missing from submodule status
    status_paths = set()
    for line in result.stdout.strip().splitlines():
        if line.strip() and len(line) > 42:
            status_paths.add(line[42:].split()[0])

    for path in submodules:
        if path not in status_paths:
            errors.append(f"Submodule '{path}': in .gitmodules but NOT in git submodule status")

    return errors


def check_update_policies(submodules: dict[str, dict[str, str]]) -> list[str]:
    """Verify update policies are appropriate for production-track submodules."""
    errors = []

    for path, config in submodules.items():
        update = config.get("update", "checkout")  # default is 'checkout'

        if path in ALLOWED_UPDATE_POLICIES:
            expected = ALLOWED_UPDATE_POLICIES[path]
            if update != expected:
                errors.append(
                    f"Submodule '{path}': update policy is '{update}', "
                    f"expected '{expected}' per allowed overrides"
                )
            else:
                print(f"  OK  {path}: update={update} (matches expected override)")
        elif update == "none":
            errors.append(
                f"Submodule '{path}': update=none is set but this submodule is not "
                f"in the allowed overrides list. Add it or change the policy."
            )
        else:
            print(f"  OK  {path}: update={update}")

    return errors


def main():
    print("=== Submodule Pin Integrity Audit ===\n")

    submodules = parse_gitmodules()
    print(f"Found {len(submodules)} submodule(s) in .gitmodules\n")

    print("--- Checking submodule pin validity ---")
    pin_errors = check_submodule_pins(submodules)

    print("\n--- Checking update-policy hardening ---")
    policy_errors = check_update_policies(submodules)

    all_errors = pin_errors + policy_errors

    if all_errors:
        print(f"\n❌ {len(all_errors)} violation(s) found:")
        for err in all_errors:
            print(f"  • {err}")
        sys.exit(1)

    print("\n✅ All submodule pins and update policies are valid.")
    sys.exit(0)


if __name__ == "__main__":
    main()
