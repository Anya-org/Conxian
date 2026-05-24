from __future__ import annotations

import argparse
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping

from erp_mvcr_foundation import (
    generate_mvcr_artifact,
    write_mvcr_artifact_files,
)


def calculate_hash(file_path: str) -> str | None:
    sha256_hash = hashlib.sha256()
    try:
        with open(file_path, "rb") as file_handle:
            for byte_block in iter(lambda: file_handle.read(4096), b""):
                sha256_hash.update(byte_block)
        return sha256_hash.hexdigest()
    except Exception as error:  # noqa: BLE001
        print(f"Error hashing {file_path}: {error}")
        return None


def _load_settlement_event(path: str | None) -> Mapping[str, Any] | None:
    if not path:
        return None

    event_path = Path(path)
    if not event_path.exists():
        raise FileNotFoundError(f"Settlement event file does not exist: {event_path}")

    with event_path.open("r", encoding="utf-8") as file_handle:
        payload = json.load(file_handle)

    if not isinstance(payload, Mapping):
        raise ValueError("Settlement event payload must be a JSON object")

    return payload


def _generate_mvcr_outputs(
    *,
    settlement_event: Mapping[str, Any],
    generated_dir: Path,
    manifest_anchor_payload: str,
) -> dict[str, str]:
    settlement_payload = settlement_event.get("settlement_payload")
    if not isinstance(settlement_payload, Mapping):
        raise ValueError("settlement_event requires settlement_payload as a JSON object")

    artifact = generate_mvcr_artifact(
        rail=str(settlement_event.get("rail", "ISO20022")),
        settlement_payload=settlement_payload,
        erp_system=str(settlement_event.get("erp_system", "conxian-gateway")),
        direction=str(settlement_event.get("direction", "egress")),
        compliance_checks=settlement_event.get("compliance_checks", []),
        iso20022_message_type=(
            str(settlement_event["iso20022_message_type"])
            if "iso20022_message_type" in settlement_event
            else None
        ),
        source_event_id=(
            str(settlement_event["source_event_id"])
            if "source_event_id" in settlement_event
            else None
        ),
        manifest_anchor_payload=manifest_anchor_payload,
    )

    json_path, markdown_path = write_mvcr_artifact_files(artifact, generated_dir)

    return {
        "artifact_id": artifact.artifact_id,
        "status": artifact.status,
        "trigger_id": artifact.lineage.trigger_id,
        "erp_sync_idempotency_key": artifact.lineage.erp_sync_idempotency_key,
        "json_path": str(json_path),
        "markdown_path": str(markdown_path),
    }


def generate_manifest(settlement_event: Mapping[str, Any] | None = None) -> None:
    manifest = {
        "org": "Conxian",
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "version": "v2.1-Audit",
        "files": [],
    }

    # Audit strategic and executive directories
    targets = [
        "docs",
        "Conxian",
        "conxian-business",
        "Nakamoto-Guardian",
        "Sovereign-Ops-Orchestrator",
        "Sovereign-Strategy-Nexus",
        "Fiscal-Vault-Oracle",
        "conxian-gateway",
        "conxian-nexus",
        "conxian-ui",
        "conxius-platform",
        "conxius-wallet",
        "lib-conxian-core",
        "conxius-orbit",
    ]

    for target in targets:
        if os.path.isdir(target):
            for root, _dirs, files in os.walk(target):
                for file_name in files:
                    if file_name.endswith((".md", ".json", ".py", ".clar", ".rs")):
                        file_path = os.path.join(root, file_name)
                        file_hash = calculate_hash(file_path)
                        if file_hash:
                            manifest["files"].append(
                                {
                                    "path": file_path,
                                    "sha256": file_hash,
                                }
                            )

    # ZSE Compliance Check
    sensitive_patterns = [".env", "id_rsa", "key.json", "secret"]
    for root, _dirs, files in os.walk("."):
        for file_name in files:
            for pattern in sensitive_patterns:
                if pattern in file_name.lower() and ".stub" not in file_name:
                    # Ignore .git and node_modules
                    if ".git" in root or "node_modules" in root:
                        continue
                    print(f"ZSE ALERT: Potential sensitive file found: {os.path.join(root, file_name)}")

    # Anchor to Stacks (simulated)
    anchor_payload = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
    manifest["stacks_anchor_payload"] = anchor_payload

    # Determine manifest path relative to script
    script_dir = Path(__file__).resolve().parent
    generated_dir = script_dir / ".generated"
    generated_dir.mkdir(parents=True, exist_ok=True)

    if settlement_event:
        manifest["mvcr_artifact"] = _generate_mvcr_outputs(
            settlement_event=settlement_event,
            generated_dir=generated_dir,
            manifest_anchor_payload=anchor_payload,
        )

    manifest_path = generated_dir / "AUDIT_MANIFEST.json"
    with manifest_path.open("w", encoding="utf-8") as file_handle:
        json.dump(manifest, file_handle, indent=2)

    print(f"Transparency Custodian: Manifest generated with {len(manifest['files'])} files.")
    print(f"Stacks Anchor Hash: {anchor_payload}")
    if settlement_event:
        mvcr_artifact = manifest.get("mvcr_artifact", {})
        print(f"MVCR Artifact: {mvcr_artifact.get('artifact_id', 'unknown')} ({mvcr_artifact.get('status', 'unknown')})")


def _build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Generate BOS transparency audit manifest and optional MVCR artifact "
            "for ERP/settlement compliance lineage."
        )
    )
    parser.add_argument(
        "--settlement-event-json",
        type=str,
        default=None,
        help=(
            "Path to a settlement event JSON object. "
            "When provided, the tool generates MVCR JSON + markdown artifacts in "
            "conxian-business/.generated/."
        ),
    )
    return parser


if __name__ == "__main__":
    arguments = _build_argument_parser().parse_args()
    settlement_event_payload = _load_settlement_event(arguments.settlement_event_json)
    generate_manifest(settlement_event=settlement_event_payload)
