import hashlib
import os
import json
from datetime import datetime, timezone

def calculate_hash(file_path):
    sha256_hash = hashlib.sha256()
    try:
        with open(file_path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256_hash.update(byte_block)
        return sha256_hash.hexdigest()
    except Exception as e:
        print(f"Error hashing {file_path}: {e}")
        return None

def generate_manifest():
    manifest = {
        "org": "Conxian",
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "version": "v2.0-Audit",
        "files": []
    }

    # Audit strategic and executive directories
    targets = ["docs", "Conxian", "conxian-business", "Nakamoto-Guardian", "Sovereign-Ops-Orchestrator", "Sovereign-Strategy-Nexus", "Fiscal-Vault-Oracle"]

    for target in targets:
        if os.path.isdir(target):
            for root, dirs, files in os.walk(target):
                for file in files:
                    if file.endswith((".md", ".json", ".py", ".clar")):
                        file_path = os.path.join(root, file)
                        file_hash = calculate_hash(file_path)
                        if file_hash:
                            manifest["files"].append({
                                "path": file_path,
                                "sha256": file_hash
                            })

    # Anchor to Stacks (Simulated in this step)
    anchor_payload = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
    manifest["stacks_anchor_payload"] = anchor_payload

    # Determine manifest path relative to script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    generated_dir = os.path.join(script_dir, ".generated")
    os.makedirs(generated_dir, exist_ok=True)
    manifest_path = os.path.join(generated_dir, "AUDIT_MANIFEST.json")

    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"Transparency Custodian: Manifest generated with {len(manifest['files'])} files.")
    print(f"Stacks Anchor Hash: {anchor_payload}")

if __name__ == "__main__":
    generate_manifest()
