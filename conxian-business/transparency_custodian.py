import hashlib
import os
import json
from datetime import datetime, timezone

def calculate_hash(file_path):
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def generate_manifest():
    manifest = {
        "org": "Conxian",
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "version": "v2.0-Audit",
        "files": []
    }

    # Audit strategic and executive directories
    targets = ["conxian-business", "cxn-arch-guardian", "cxn-ops-engine", "cxn-strategy-nexus", "cxn-treasury-oracle"]

    for target in targets:
        if os.path.isdir(target):
            for root, dirs, files in os.walk(target):
                for file in files:
                    if file.endswith((".md", ".json", ".py", ".clar")):
                        file_path = os.path.join(root, file)
                        file_hash = calculate_hash(file_path)
                        manifest["files"].append({
                            "path": file_path,
                            "sha256": file_hash
                        })

    # Anchor to Stacks (Simulated in this step)
    anchor_payload = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
    manifest["stacks_anchor_payload"] = anchor_payload

    with open("conxian-business/AUDIT_MANIFEST.json", "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"Transparency Custodian: Manifest generated with {len(manifest['files'])} files.")
    print(f"Stacks Anchor Hash: {anchor_payload}")

if __name__ == "__main__":
    generate_manifest()
