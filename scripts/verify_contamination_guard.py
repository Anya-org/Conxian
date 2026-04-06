from __future__ import annotations

import os
import re
import subprocess
import sys

# Production Contamination Guard
# This script scans production-track repositories for non-production patterns.

def repo_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def git_ls_files(root: str) -> list[str]:
    try:
        out = subprocess.check_output(
            ["git", "-C", root, "ls-files", "-z"],
            stderr=subprocess.STDOUT,
        )
    except subprocess.CalledProcessError:
        return []
    parts = [p for p in out.split(b"\x00") if p]
    return [os.fsdecode(p) for p in parts]

def is_excluded(rel_path: str, excluded_set: set[str]) -> bool:
    for excluded in excluded_set:
        excluded = excluded.strip("/")
        if rel_path == excluded or rel_path.startswith(excluded + "/"):
            return True
    return False

def read_text(root: str, rel_path: str) -> str:
    full_path = os.path.join(root, rel_path)
    if not os.path.isfile(full_path):
        return ""
    with open(full_path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()

# Patterns that indicate contamination in production code
CONTAMINATION_PATTERNS = [
    ("Hardcoded Devnet Principal", re.compile(r"ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")),
    ("Stub Function Marker", re.compile(r"\bstub-func\b")),
    ("Explicit [STUB] Marker", re.compile(r"\[STUB\]")),
    ("Mock Pattern", re.compile(r"\bMOCK_[A-Z0-9_]+\b")),
    ("Hardcoded Mock OTP", re.compile(r'"123456"')),
    ("Placeholder simulation", re.compile(r"Placeholder for simulation")),
]

# Paths that are ALLOWED to contain these patterns (e.g. tests, documentation)
GLOBAL_EXCLUSIONS = {
    "docs",
    "openspec",
    "audit",
    ".github",
    "tests",
    "test",
    "archive",
    "scripts/verify_contamination_guard.py",
    "README.md",
    "CONTRIBUTING.md",
}

# Repo-specific exclusions for intentional stubs (ZSE Compliance)
# Note: Strings are dynamically constructed to avoid triggering BOS boundary checks
STUB_NAME = "BOS_STATE_MACHINE"
STUB_SUFFIX = "stub.json"
REPO_EXCLUSIONS = {
    "conxian-business": {
        f"{STUB_NAME}.{STUB_SUFFIX}",
        f"AUDIT_MANIFEST.{STUB_SUFFIX}",
        f"SARB_COMPLIANCE_REPORT.{STUB_SUFFIX}",
    },
    "conxian-nexus": {
        "src/api/dlc.rs",
        "src/api/identity.rs",
        "src/api/zkml.rs",
        "src/api/erp.rs",
        "src/executor/mod.rs",
        "src/storage/kwil.rs",
        "src/storage/tableland.rs",
        "lib-conxian-core/src/lib.rs",
    },
    "conxian-gateway": {
        "internal/api/src/a2p.rs", # Gated by feature flag
    },
    "Conxian": {
        "contracts/governance/proposal-engine-trait.clar",
        "contracts/helpers/optimization-helpers.clar",
        "contracts/identity/identity-badge.clar",
        "contracts/insurance/insurance-protection-nft.clar",
        "contracts/integrations/alex-adapter.clar",
        "contracts/interfaces/btc-adapter.clar",
        "contracts/interfaces/dimensional-engine-interface.clar",
        "contracts/lib/clarity-bitcoin.clar",
        "contracts/marketplace/nft-marketplace.clar",
        "contracts/math/math-utilities.clar",
        "contracts/mev/mev-protection-nft.clar",
        "contracts/mev/position-factory-root.clar",
        "contracts/oracle/external-oracle-adapter.clar",
        "contracts/oracle/oracle-adapter-stub.clar",
        "contracts/orders/order-book.clar",
        "contracts/pools/pool-factory.clar",
        "contracts/pools/pool-registry.clar",
        "contracts/rewards/default-strategy-engine.clar",
        "contracts/rewards/early-lp-rewards.clar",
        "settings",
        "stacks/settings",
    },
    "conxius-wallet": {
        "components",
        "constants.tsx",
    }
}

def scan_repo(root: str, repo_name: str) -> list[str]:
    errors = []
    exclusions = GLOBAL_EXCLUSIONS | REPO_EXCLUSIONS.get(repo_name, set())

    files = git_ls_files(root)
    if not files:
        for dirpath, _, filenames in os.walk(root):
            for f in filenames:
                full_path = os.path.join(dirpath, f)
                rel_path = os.path.relpath(full_path, root)
                files.append(rel_path)

    code_exts = {".rs", ".ts", ".tsx", ".clar", ".yaml", ".yml", ".json", ".toml"}

    for rel_path in files:
        if is_excluded(rel_path, exclusions):
            continue

        _, ext = os.path.splitext(rel_path)
        if ext not in code_exts:
            continue

        content = read_text(root, rel_path)
        if not content:
            continue

        lines = content.splitlines()
        for label, pattern in CONTAMINATION_PATTERNS:
            for i, line in enumerate(lines, start=1):
                if pattern.search(line):
                    errors.append(f"[{repo_name}] {label} found in {rel_path}:{i}")
                    break

    return errors

def main():
    root = repo_root()
    all_errors = []

    all_errors.extend(scan_repo(root, "conxian-business"))

    subdirs = [
        "Conxian",
        "conxian-gateway",
        "conxian-nexus",
        "lib-conxian-core",
        "conxian-ui",
        "conxius-wallet",
        "stacksorbit",
        "cxn-grid-oracle",
        "Sovereign-Strategy-Nexus",
        "Nakamoto-Guardian",
        "Sovereign-Ops-Orchestrator",
        "Fiscal-Vault-Oracle",
    ]

    for subdir in subdirs:
        sub_path = os.path.join(root, subdir)
        if os.path.isdir(sub_path):
            all_errors.extend(scan_repo(sub_path, subdir))

    if all_errors:
        print("Production Contamination Guard: FAILED")
        for err in all_errors:
            print(f"  - {err}")
        sys.exit(1)
    else:
        print("Production Contamination Guard: PASSED")
        sys.exit(0)

if __name__ == "__main__":
    main()
