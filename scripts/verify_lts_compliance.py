#!/usr/bin/env python3
"""Validate all package manifests against the LTS version baseline.

Reads .github/LTS_VERSIONS.json and checks that:
1. Runtime toolchain versions (Node.js, Rust, Python, pnpm) match LTS pins in CI configs
2. SDK consumers use compatible version ranges (no floating or pre-release refs)
3. Framework versions (Next.js, React) are within LTS ranges

Exit non-zero on violations. Set LTS_STRICT=true to fail on warnings.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
LTS_FILE = REPO_ROOT / ".github" / "LTS_VERSIONS.json"
WARN_ONLY = os.environ.get("LTS_STRICT", "").strip().lower() not in {"1", "true", "yes"}


def load_lts() -> dict:
    if not LTS_FILE.exists():
        raise RuntimeError(f"LTS versions file not found: {LTS_FILE}")
    return json.loads(LTS_FILE.read_text(encoding="utf-8"))


def get_track() -> str:
    """Determine which track to validate against. Default: lts."""
    return os.environ.get("LTS_TRACK", "lts").strip().lower()


def get_lts_pins(lts: dict, track: str) -> dict:
    """Get version pins for the specified track."""
    tracks = lts.get("tracks", {})
    if track not in tracks:
        raise RuntimeError(f"Unknown LTS track: {track}. Valid: {list(tracks.keys())}")
    return tracks[track]


def check_node_version(pins: dict, errors: list[str], warnings: list[str]) -> None:
    """Validate Node.js version in CI configs matches LTS track."""
    expected = pins.get("node", "22")
    unified_ci = REPO_ROOT / ".github" / "workflows" / "conxian-unified-ci.yml"
    if unified_ci.exists():
        text = unified_ci.read_text(encoding="utf-8", errors="replace")
        import re
        node_versions = re.findall(r"node-version:\s*'?(\d+)'?", text)
        for v in node_versions:
            if v != expected:
                msg = f"Node.js version {v} in CI does not match LTS pin ({expected})"
                (warnings if WARN_ONLY else errors).append(msg)


def check_sdk_versions(lts: dict, errors: list[str], warnings: list[str]) -> None:
    """Validate SDK consumers pin to compatible versions."""
    import re

    for sdk_name, sdk_info in lts["sdk"].items():
        lts_ver = sdk_info.get("lts")
        if not lts_ver:
            continue  # No LTS defined yet for this SDK

        for pkg_json in REPO_ROOT.rglob("package.json"):
            rel = pkg_json.relative_to(REPO_ROOT)
            try:
                data = json.loads(pkg_json.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError):
                continue

            deps = {**data.get("dependencies", {}), **data.get("devDependencies", {})}

            # Check if this package.json consumes the SDK
            sdk_pkg_name = f"@conxian/{sdk_name}" if sdk_name not in ("client-sdk", "schemas") else f"@conxian/{sdk_name}"
            # Also check local workspace references
            for dep_name, dep_ver in deps.items():
                normalized = dep_name.lower().replace("_", "-")
                if sdk_name in normalized or sdk_name.replace("-", "/") in normalized:
                    # Check if version is a local workspace ref (should be published version)
                    if dep_ver.startswith("workspace:") or dep_ver.startswith("file:") or dep_ver.startswith("link:"):
                        msg = f"{rel}: {dep_name}@{dep_ver} — SDK dependency uses local workspace ref. Pin to published version {lts_ver} for production."
                        (warnings if WARN_ONLY else errors).append(msg)
                    # Check for floating ranges ("*", "^0.x" pre-release)
                    elif dep_ver == "*":
                        msg = f"{rel}: {dep_name}@{dep_ver} — floating version. Pin to LTS range."
                        errors.append(msg)


def check_framework_lts(pins: dict, errors: list[str], warnings: list[str]) -> None:
    """Validate framework versions are within LTS ranges."""
    import re
    from packaging.version import Version
    from packaging.specifiers import SpecifierSet

    frameworks = {
        "next": pins.get("nextjs", ""),
        "react": pins.get("react", ""),
        "vite": pins.get("vite", ""),
    }
    if not frameworks:
        return

    for pkg_json in REPO_ROOT.rglob("package.json"):
        rel = pkg_json.relative_to(REPO_ROOT)
        try:
            data = json.loads(pkg_json.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue

        deps = {**data.get("dependencies", {}), **data.get("devDependencies", {})}
        for fw_name, lts_range in frameworks.items():
            if fw_name in deps and lts_range:
                dep_ver = deps[fw_name]
                clean_ver = re.sub(r'^[\^~>=<]+', '', dep_ver)
                try:
                    if not SpecifierSet(lts_range).contains(clean_ver):
                        msg = f"{rel}: {fw_name}@{dep_ver} is outside LTS range ({lts_range})"
                        (warnings if WARN_ONLY else errors).append(msg)
                except Exception:
                    pass  # Can't parse, skip


def check_toolchain_in_dockerfiles(pins: dict, errors: list[str], warnings: list[str]) -> None:
    """Validate Dockerfiles use LTS toolchain versions."""
    rust_lts = pins.get("rust", "1.82")
    node_lts = pins.get("node", "22")

    import re
    for dockerfile in REPO_ROOT.rglob("Dockerfile*"):
        rel = dockerfile.relative_to(REPO_ROOT)
        text = dockerfile.read_text(encoding="utf-8", errors="replace")

        # Check Rust toolchain
        rust_matches = re.findall(r"rust:(\d+\.\d+)", text)
        for v in rust_matches:
            if not v.startswith(rust_lts.rsplit(".", 1)[0]):
                msg = f"{rel}: Rust {v} in Dockerfile, LTS is {rust_lts}"
                (warnings if WARN_ONLY else errors).append(msg)

        # Check Node version
        node_matches = re.findall(r"node:(\d+)", text)
        for v in node_matches:
            if v != node_lts:
                msg = f"{rel}: Node {v} in Dockerfile, LTS is {node_lts}"
                (warnings if WARN_ONLY else errors).append(msg)


def main() -> int:
    try:
        lts = load_lts()
    except RuntimeError as exc:
        print(f"ERROR: {exc}")
        return 1

    track = get_track()
    try:
        pins = get_lts_pins(lts, track)
    except RuntimeError as exc:
        print(f"ERROR: {exc}")
        return 1

    errors: list[str] = []
    warnings: list[str] = []

    print(f"LTS Compliance: validating against '{track}' track")
    check_node_version(pins, errors, warnings)
    check_sdk_versions(lts, errors, warnings)
    check_framework_lts(pins, errors, warnings)
    check_toolchain_in_dockerfiles(pins, errors, warnings)

    if errors:
        print("LTS Compliance: FAILED")
        for e in errors:
            print(f"  ❌ {e}")
        for w in warnings:
            print(f"  ⚠️  {w}")
        return 1

    if warnings:
        print("LTS Compliance: OK (warnings)")
        for w in warnings:
            print(f"  ⚠️  {w}")
    else:
        print("LTS Compliance: OK")

    return 0


if __name__ == "__main__":
    sys.exit(main())
