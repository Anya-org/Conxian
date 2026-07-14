#!/usr/bin/env python3
"""
Generate Portfolio Manifest from .gitmodules

This script generates a machine-readable PORTFOLIO_MANIFEST.json from the
actual .gitmodules file, ensuring alignment between documentation and reality.

Usage:
    python scripts/generate_portfolio_manifest.py

Output:
    docs/PORTFOLIO_MANIFEST_generated.json

Reference:
    docs/PORTFOLIO_MANIFEST.json (schema definition)
"""

import json
import subprocess
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional

# Category mapping (path -> canonical category)
CATEGORY_MAP = {
    "Conxian": "primary strategic",
    "conxian-gateway": "primary strategic",
    "conxian-nexus": "primary strategic",
    "conxian-market": "primary strategic",
    "conxius-wallet": "primary strategic",
    "conxius-platform": "supporting",
    "conxius-enclave-sdk": "supporting",
    "conxius-orbit": "supporting",
    "lib-conxian-core": "supporting",
    "conxian-ui": "supporting",
    "conxian-labs-site": "reference",
}

# Business unit mapping
BU_MAP = {
    "Conxian": "CSF",
    "conxian-gateway": "Fusion",
    "conxian-nexus": "Nexus",
    "conxian-market": "Nexus",
    "conxius-wallet": "Conxius",
    "conxius-platform": "Conxius",
    "conxius-enclave-sdk": "Conxius",
    "conxius-orbit": "Conxius",
    "lib-conxian-core": "Operating",
    "conxian-ui": "Operating",
    "conxian-labs-site": "Operating",
}

# Dependencies mapping (what each submodule depends on)
DEPENDENCIES_MAP = {
    "Conxian": [],
    "conxian-gateway": ["Conxian", "lib-conxian-core", "conxian-nexus"],
    "conxian-nexus": ["Conxian", "lib-conxian-core"],
    "conxian-market": ["conxian-gateway", "conxian-nexus", "lib-conxian-core"],
    "conxius-wallet": ["conxius-enclave-sdk", "conxian-gateway"],
    "conxius-platform": ["Conxian", "conxian-gateway", "conxian-nexus", "conxius-wallet"],
    "conxius-enclave-sdk": ["lib-conxian-core"],
    "conxius-orbit": ["Conxian"],
    "lib-conxian-core": [],
    "conxian-ui": ["conxian-gateway", "conxian-nexus"],
    "conxian-labs-site": [],
}


def parse_gitmodules() -> List[Dict]:
    """Parse .gitmodules and return list of submodule configs."""
    gitmodules_path = Path(__file__).parent.parent / ".gitmodules"
    
    if not gitmodules_path.exists():
        raise FileNotFoundError(".gitmodules not found")
    
    content = gitmodules_path.read_text()
    
    submodules = []
    current = {}
    
    for line in content.split("\n"):
        line = line.strip()
        
        if line.startswith("[submodule "):
            if current:
                submodules.append(current)
            match = re.search(r'"([^"]+)"', line)
            current = {"path": match.group(1)} if match else {}
        elif "=" in line and current:
            key, value = line.split("=", 1)
            current[key.strip()] = value.strip()
    
    if current:
        submodules.append(current)
    
    return submodules


def get_gitlink_sha(path: str) -> Optional[str]:
    """Get the pinned SHA for a submodule from gitlinks."""
    try:
        result = subprocess.run(
            ["git", "ls-tree", "HEAD", path],
            capture_output=True,
            text=True,
            check=True
        )
        # Format: 160000 commit <sha> <path>
        parts = result.stdout.strip().split()
        if len(parts) >= 3:
            return parts[2]
    except subprocess.CalledProcessError:
        pass
    return None


def build_manifest() -> Dict:
    """Build the portfolio manifest from parsed data."""
    submodules = parse_gitmodules()
    
    manifest = {
        "$schema": "https://json-schema.org/draft-07/schema#",
        "title": "Conxian Portfolio Manifest",
        "description": "Machine-readable portfolio manifest for BOS submodules",
        "version": "1.0.0",
        "lastUpdated": datetime.now(timezone.utc).isoformat(),
        "metadata": {
            "generated": datetime.now(timezone.utc).isoformat(),
            "generator": "scripts/generate_portfolio_manifest.py",
            "source-of-truth": ".gitmodules"
        },
        "submodules": [],
        "businessUnits": []
    }
    
    # Build submodule list
    for sm in submodules:
        path = sm.get("path", "")
        category = CATEGORY_MAP.get(path, "supporting")
        business_unit = BU_MAP.get(path, "Operating")
        update_policy = sm.get("update", "checkout")
        
        # Get pinned SHA
        sha = get_gitlink_sha(path)
        pinned = {}
        if sha:
            pinned = {
                "sha": sha,
                "pinnedAt": datetime.now(timezone.utc).isoformat(),
                "pinnedBy": "conxian-business CI"
            }
        
        # Get dependencies
        dependencies = DEPENDENCIES_MAP.get(path, [])
        
        submodule_entry = {
            "path": path,
            "url": sm.get("url", ""),
            "branch": sm.get("branch", "main"),
            "category": category,
            "businessUnit": business_unit,
            "updatePolicy": update_policy,
            "dependencies": dependencies
        }
        
        if pinned:
            submodule_entry["pinned"] = pinned
        
        manifest["submodules"].append(submodule_entry)
    
    # Build consumers (reverse of dependencies)
    consumers_map: Dict[str, List[str]] = {sm["path"]: [] for sm in manifest["submodules"]}
    for sm in manifest["submodules"]:
        for dep in sm.get("dependencies", []):
            if dep in consumers_map:
                consumers_map[dep].append(sm["path"])
    
    # Add consumers to each submodule
    for sm in manifest["submodules"]:
        sm["consumers"] = consumers_map.get(sm["path"], [])
    
    # Build business units
    bu_names = set(BU_MAP.values())
    for bu_name in sorted(bu_names):
        bu_submodules = [sm["path"] for sm in manifest["submodules"] if sm.get("businessUnit") == bu_name]
        manifest["businessUnits"].append({
            "name": bu_name,
            "submodules": bu_submodules
        })
    
    return manifest


def main():
    """Main entry point."""
    print("Generating portfolio manifest from .gitmodules...")
    
    try:
        manifest = build_manifest()
        
        # Write to docs directory
        output_path = Path(__file__).parent.parent / "docs" / "PORTFOLIO_MANIFEST_generated.json"
        output_path.write_text(json.dumps(manifest, indent=2))
        
        print(f"✅ Manifest generated: {output_path}")
        print(f"   Submodules: {len(manifest['submodules'])}")
        print(f"   Business Units: {len(manifest['businessUnits'])}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        raise


if __name__ == "__main__":
    main()
