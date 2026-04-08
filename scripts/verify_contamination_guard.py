from __future__ import annotations

import os
import re
import subprocess
import sys
from typing import Union

# Production Contamination Guard
# This script scans production-track repositories for non-production patterns.

def repo_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def format_git_ls_files_error(root: str, details: str = "") -> str:
    return (
        f"Failed to run `git ls-files` in {root!r}. Ensure `git` is installed and available on PATH, and that this directory is a Git repo and submodules are initialized (e.g., `git submodule update --init --recursive`)."
        + details
    )

def git_ls_files(root: str) -> list[str]:
    try:
        prefix = subprocess.check_output(
            ["git", "-C", root, "rev-parse", "--show-prefix"],
            stderr=subprocess.STDOUT,
        )
        out = subprocess.check_output(
            ["git", "-C", root, "ls-files", "-z", "--", "."],
            stderr=subprocess.STDOUT,
        )
    except (FileNotFoundError, OSError) as exc:
        raise SystemExit(format_git_ls_files_error(root, f"\n\nOS error:\n{exc}")) from exc
    except subprocess.CalledProcessError as exc:
        output = getattr(exc, "output", b"")
        output_text = output.decode("utf-8", "replace") if output else ""
        details = f"\n\nGit output:\n{output_text}" if output_text else ""
        raise SystemExit(format_git_ls_files_error(root, details)) from exc
    parts = [p for p in out.split(b"\x00") if p]
    prefix_text = prefix.decode("utf-8", "replace")
    prefix_text = prefix_text.strip()
    prefix_text = prefix_text.lstrip("/")
    if prefix_text and not prefix_text.endswith("/"):
        prefix_text += "/"

    paths = [os.fsdecode(p) for p in parts]
    if prefix_text:
        paths = [p[len(prefix_text) :] if p.startswith(prefix_text) else p for p in paths]
    return paths

def is_excluded(rel_path: str, excluded_set: set[str]) -> bool:
    """Return True when `rel_path` should be skipped during scanning.

    Exclusion semantics:
    - Entries containing `/` match an exact relative path or a directory prefix.
    - Bare entries match either a root-level file (exact match) or any directory
      name anywhere in the path.
    """
    rel_path = rel_path.replace(os.sep, "/").replace("\\", "/")
    while rel_path.startswith("./"):
        rel_path = rel_path[2:]
    rel_path = rel_path.strip("/")
    parts = rel_path.split("/") if rel_path else []
    for excluded in excluded_set:
        ex = excluded.replace(os.sep, "/").replace("\\", "/").strip("/")
        while ex.startswith("./"):
            ex = ex[2:]
        if not ex:
            continue

        if "/" in ex:
            if rel_path == ex or rel_path.startswith(ex + "/"):
                return True
            continue
        if rel_path == ex:
            return True
        if ex in parts[:-1]:
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
    (
        "Hardcoded Testnet Principal",
        re.compile(r"(?<![0-9A-Z_])ST[0-9A-Z]{38,}(?![0-9A-Z_])", re.IGNORECASE),
    ),
    ("Stub Function Marker", re.compile(r"\bstub-func\b")),
    ("Explicit [STUB] Marker", re.compile(r"\[STUB\]")),
    ("Mock Pattern", re.compile(r"\bMOCK_[A-Z0-9_]+\b")),
    ("Hardcoded Mock OTP", re.compile(r'"123456"')),
    ("Placeholder simulation", re.compile(r"Placeholder for simulation")),
]

GATEABLE_LABELS = {
    "Stub Function Marker",
    "Explicit [STUB] Marker",
    "Mock Pattern",
    "Hardcoded Mock OTP",
    "Placeholder simulation",
}

GateRule = Union[re.Pattern[str], dict[str, re.Pattern[str]]]

GATE_REQUIRED: dict[str, dict[str, GateRule]] = {
    "conxian-gateway": {
        "internal/api/src/a2p.rs": re.compile(r'feature\s*=\s*"mock-integrations"'),
    },
}

LABEL_ALLOWLIST: dict[str, dict[str, set[str]]] = {
    "conxius-wallet": {
        "Mock Pattern": {
            "components/AssetDetailModal.tsx",
            "components/CitadelManager.tsx",
            "components/GovernancePortal.tsx",
            "components/InvestorDashboard.tsx",
            "components/Marketplace.tsx",
            "components/RewardsHub.tsx",
            "components/StackingManager.tsx",
            "constants.tsx",
        },
    },
}

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
    "pnpm-lock.yaml",
    "package-lock.json",
    "showcase-dapp/package-lock.json",
}

# Repo-specific exclusions for intentional stubs (ZSE Compliance)
STUB_NAME = "BOS_STATE_MACHINE"
STUB_SUFFIX = "stub.json"
REPO_EXCLUSIONS = {
    "conxian-business": {
        f"{STUB_NAME}.{STUB_SUFFIX}",
        f"AUDIT_MANIFEST.{STUB_SUFFIX}",
        f"SARB_COMPLIANCE_REPORT.{STUB_SUFFIX}",
    },
    # All [STUB] markers in conxian-nexus/src/ have been remediated (CON-383):
    # - zkml.rs, dlc.rs: fail-closed 501 Not Implemented
    # - identity.rs: real BNS HTTP call; ENS/WorldID return 503
    # - erp.rs: real wallet signing via lib-conxian-core
    # - kwil.rs, tableland.rs: real HTTP calls, fail-closed on error
    # - executor/mod.rs: real Supabase upsert, non-fatal
    # conxian-nexus/lib-conxian-core/src/lib.rs retains one [STUB] for BitVM2 state root
    # verification (CON-75) — kept until that integration is wired.
    "conxian-nexus": {
        "conxian-nexus/lib-conxian-core/src/lib.rs",
    },
    "lib-conxian-core": {
        "src/lib.rs",
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
        "Clarinet.toml",
        "Clarinet.complete.toml",
        "deployment/history.json",
        "deployment/testnet_complete_manifest.json",
        "deployments/default.simnet-plan.yaml",
        "deployments/full-system.testnet-plan.yaml",
        # TEMPORARY: mainnet release plan still contains known testnet principals; tracked in CON-371.
        # Remove this exclusion once CON-371 is resolved.
        "deployments/mainnet-release-plan.yaml",
        "deployments/testnet-plan.yaml",
    },
    "conxius-wallet": {
        # UI mock data/constants (e.g. `MOCK_*`) are allowed in a small set of files that are
        # allowlisted in `LABEL_ALLOWLIST` above. We keep scanning the rest of the UI and
        # all production-facing service integrations (such as `services/`).
        "scripts/update_mocks.py",
    },
    "stacksorbit": {
        "Clarinet.toml",
        "chainhooks",
        "deployment",
        "deployments",
    },
    "conxian-ui": {
        "src/lib/contracts.ts",
        "src/app/contracts/page.tsx",
        "src/app/pools/page.tsx",
        "src/app/router/page.tsx",
        "src/app/tx/page.tsx",
        "src/lib/contract-interactions.ts",
        "src/lib/contracts/self-launch.ts",
    }
}

def scan_repo(root: str, repo_name: str) -> list[str]:
    errors = []
    exclusions = GLOBAL_EXCLUSIONS | REPO_EXCLUSIONS.get(repo_name, set())

    gate_requirements = GATE_REQUIRED.get(repo_name, {})
    allowlist = LABEL_ALLOWLIST.get(repo_name, {})

    files = git_ls_files(root)

    if allowlist:
        files_set = set(files)
        known_labels = {lbl for (lbl, _) in CONTAMINATION_PATTERNS}
        unknown_labels = set(allowlist) - known_labels
        for lbl in sorted(unknown_labels):
            errors.append(f"[{repo_name}] LABEL_ALLOWLIST references unknown label: {lbl!r}")

        for lbl, paths in allowlist.items():
            missing = sorted(p for p in paths if p not in files_set)
            for p in missing:
                errors.append(
                    f"[{repo_name}] LABEL_ALLOWLIST references missing path for {lbl!r}: {p}"
                )

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
            label_allowlist = allowlist.get(label)
            for i, line in enumerate(lines, start=1):
                if pattern.search(line):
                    if label_allowlist and rel_path in label_allowlist:
                        break

                    gate_rule = gate_requirements.get(rel_path)
                    gate_regex = None
                    if label in GATEABLE_LABELS:
                        if isinstance(gate_rule, dict):
                            gate_regex = gate_rule.get(label)
                        else:
                            gate_regex = gate_rule

                    if gate_regex:
                        if gate_regex.search(content):
                            break
                        errors.append(
                            f"[{repo_name}] {label} found in {rel_path}:{i} without required gate"
                        )
                        break

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
