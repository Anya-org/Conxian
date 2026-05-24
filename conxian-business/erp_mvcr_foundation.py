from __future__ import annotations

import hashlib
import json
import unicodedata
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

TRIGGER_ID_NAMESPACE = "external-settlement-trigger:v1"
ERP_SYNC_IDEMPOTENCY_NAMESPACE = "erp-sync-idempotency:v1"
MVCR_ARTIFACT_NAMESPACE = "mvcr-artifact:v1"

SUPPORTED_RAILS = frozenset({"ISO20022", "PAPSS", "BRICS"})
SUPPORTED_DIRECTIONS = frozenset({"ingress", "egress"})

ISO20022_ENTITY_FIELD_MAP = {
    "payment_identification.uetr": "transaction_reference",
    "payment_identification.end_to_end_id": "transaction_reference",
    "payment_identification.instruction_id": "transaction_reference",
    "interbank_settlement_amount.currency": "settlement_currency",
    "interbank_settlement_amount.value": "settlement_amount",
    "debtor.name": "originator_name",
    "creditor.name": "beneficiary_name",
}

ISO20022_REFERENCE_PRIORITY = (
    "uetr",
    "end_to_end_id",
    "instruction_id",
)


@dataclass(frozen=True)
class SettlementTriggerIdentity:
    rail: str
    normalized_settlement_hash: str
    trigger_id: str
    idempotency_key: str
    canonical_settlement_payload: str

    def to_dict(self) -> dict[str, str]:
        return {
            "rail": self.rail,
            "normalized_settlement_hash": self.normalized_settlement_hash,
            "trigger_id": self.trigger_id,
            "idempotency_key": self.idempotency_key,
            "canonical_settlement_payload": self.canonical_settlement_payload,
        }


@dataclass(frozen=True)
class ErpSyncIdentity:
    erp_system: str
    direction: str
    trigger_id: str
    idempotency_key: str

    def to_dict(self) -> dict[str, str]:
        return {
            "erp_system": self.erp_system,
            "direction": self.direction,
            "trigger_id": self.trigger_id,
            "idempotency_key": self.idempotency_key,
        }


@dataclass(frozen=True)
class ComplianceCheck:
    code: str
    passed: bool
    details: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "passed": self.passed,
            "details": self.details,
        }


@dataclass(frozen=True)
class MVCRLineage:
    trigger_id: str
    normalized_settlement_hash: str
    erp_sync_idempotency_key: str
    settlement_reference_source: str
    source_event_id: str | None
    manifest_anchor_payload: str | None

    def to_dict(self) -> dict[str, Any]:
        return {
            "trigger_id": self.trigger_id,
            "normalized_settlement_hash": self.normalized_settlement_hash,
            "erp_sync_idempotency_key": self.erp_sync_idempotency_key,
            "settlement_reference_source": self.settlement_reference_source,
            "source_event_id": self.source_event_id,
            "manifest_anchor_payload": self.manifest_anchor_payload,
        }


@dataclass(frozen=True)
class MVCRArtifact:
    artifact_id: str
    profile: str
    generated_at: str
    rail: str
    erp_system: str
    direction: str
    settlement_reference: str
    iso20022_message_type: str | None
    status: str
    compliance_checks: tuple[ComplianceCheck, ...]
    lineage: MVCRLineage

    def to_dict(self) -> dict[str, Any]:
        return {
            "artifact_id": self.artifact_id,
            "profile": self.profile,
            "generated_at": self.generated_at,
            "rail": self.rail,
            "erp_system": self.erp_system,
            "direction": self.direction,
            "settlement_reference": self.settlement_reference,
            "iso20022_message_type": self.iso20022_message_type,
            "status": self.status,
            "compliance_checks": [check.to_dict() for check in self.compliance_checks],
            "lineage": self.lineage.to_dict(),
        }


def normalize_rail(rail: str) -> str:
    if not isinstance(rail, str):
        raise ValueError("rail must be a string")

    normalized = rail.strip().upper().replace("-", "").replace("_", "")
    if normalized == "ISO20022":
        return "ISO20022"
    if normalized == "PAPSS":
        return "PAPSS"
    if normalized == "BRICS":
        return "BRICS"

    raise ValueError(f"Unsupported rail '{rail}'. Supported rails: {sorted(SUPPORTED_RAILS)}")


def normalize_direction(direction: str) -> str:
    if not isinstance(direction, str):
        raise ValueError("direction must be a string")

    normalized = direction.strip().lower()
    if normalized not in SUPPORTED_DIRECTIONS:
        raise ValueError(
            f"Unsupported direction '{direction}'. Supported directions: {sorted(SUPPORTED_DIRECTIONS)}"
        )

    return normalized


def canonical_json_dumps(value: Any) -> str:
    return json.dumps(
        _canonicalize_json_value(value),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def compute_normalized_settlement_hash(settlement_payload: Mapping[str, Any]) -> str:
    if not isinstance(settlement_payload, Mapping) or not settlement_payload:
        raise ValueError("settlement_payload must be a non-empty mapping")

    canonical_payload = canonical_json_dumps(settlement_payload)
    return _sha256_hex(canonical_payload)


def build_settlement_trigger_identity(
    rail: str, settlement_payload: Mapping[str, Any]
) -> SettlementTriggerIdentity:
    normalized_rail = normalize_rail(rail)
    if not isinstance(settlement_payload, Mapping) or not settlement_payload:
        raise ValueError("settlement_payload must be a non-empty mapping")

    canonical_settlement_payload = canonical_json_dumps(settlement_payload)
    normalized_settlement_hash = _sha256_hex(canonical_settlement_payload)

    trigger_basis = canonical_json_dumps(
        {
            "rail": normalized_rail,
            "normalized_settlement_hash": normalized_settlement_hash,
        }
    )

    trigger_id = _sha256_hex(f"{TRIGGER_ID_NAMESPACE}|{trigger_basis}")
    idempotency_key = f"{normalized_rail}:{normalized_settlement_hash}"

    return SettlementTriggerIdentity(
        rail=normalized_rail,
        normalized_settlement_hash=normalized_settlement_hash,
        trigger_id=trigger_id,
        idempotency_key=idempotency_key,
        canonical_settlement_payload=canonical_settlement_payload,
    )


def build_erp_sync_identity(erp_system: str, direction: str, trigger_id: str) -> ErpSyncIdentity:
    normalized_erp_system = _normalize_identifier(erp_system, field_name="erp_system", lowercase=True)
    normalized_direction = normalize_direction(direction)
    normalized_trigger_id = _normalize_identifier(trigger_id, field_name="trigger_id", lowercase=True)

    if not _is_sha256_hex(normalized_trigger_id):
        raise ValueError("trigger_id must be a 64-character lowercase hexadecimal digest")

    idempotency_basis = canonical_json_dumps(
        {
            "direction": normalized_direction,
            "erp_system": normalized_erp_system,
            "trigger_id": normalized_trigger_id,
        }
    )
    idempotency_key = _sha256_hex(f"{ERP_SYNC_IDEMPOTENCY_NAMESPACE}|{idempotency_basis}")

    return ErpSyncIdentity(
        erp_system=normalized_erp_system,
        direction=normalized_direction,
        trigger_id=normalized_trigger_id,
        idempotency_key=idempotency_key,
    )


def extract_settlement_reference(
    rail: str, settlement_payload: Mapping[str, Any]
) -> tuple[str, str]:
    normalized_rail = normalize_rail(rail)

    if not isinstance(settlement_payload, Mapping):
        raise ValueError("settlement_payload must be a mapping")

    if normalized_rail == "ISO20022":
        payment_identification = settlement_payload.get("payment_identification")
        if isinstance(payment_identification, Mapping):
            for key in ISO20022_REFERENCE_PRIORITY:
                candidate = payment_identification.get(key)
                if isinstance(candidate, str) and candidate.strip():
                    return _normalize_identifier(
                        candidate,
                        field_name=f"payment_identification.{key}",
                    ), f"payment_identification.{key}"

        raise ValueError(
            "ISO20022 settlement payload requires one of payment_identification.uetr, "
            "payment_identification.end_to_end_id, or payment_identification.instruction_id"
        )

    for candidate_key in ("transaction_reference", "settlement_reference"):
        candidate = settlement_payload.get(candidate_key)
        if isinstance(candidate, str) and candidate.strip():
            return _normalize_identifier(candidate, field_name=candidate_key), candidate_key

    raise ValueError(
        f"{normalized_rail} settlement payload requires transaction_reference or settlement_reference"
    )


def generate_mvcr_artifact(
    *,
    rail: str,
    settlement_payload: Mapping[str, Any],
    erp_system: str,
    direction: str,
    compliance_checks: Sequence[ComplianceCheck | Mapping[str, Any]],
    iso20022_message_type: str | None = None,
    source_event_id: str | None = None,
    manifest_anchor_payload: str | None = None,
    generated_at: datetime | None = None,
) -> MVCRArtifact:
    trigger_identity = build_settlement_trigger_identity(rail, settlement_payload)
    erp_identity = build_erp_sync_identity(
        erp_system=erp_system,
        direction=direction,
        trigger_id=trigger_identity.trigger_id,
    )
    settlement_reference, settlement_reference_source = extract_settlement_reference(
        trigger_identity.rail,
        settlement_payload,
    )
    checks = _normalize_compliance_checks(compliance_checks)

    generated_at_timestamp = (generated_at or datetime.now(timezone.utc)).astimezone(timezone.utc)
    generated_at_iso = generated_at_timestamp.isoformat().replace("+00:00", "Z")
    status = "passed" if all(check.passed for check in checks) else "failed"

    artifact_basis = canonical_json_dumps(
        {
            "direction": erp_identity.direction,
            "erp_system": erp_identity.erp_system,
            "generated_at": generated_at_iso,
            "rail": trigger_identity.rail,
            "settlement_reference": settlement_reference,
            "status": status,
            "trigger_id": trigger_identity.trigger_id,
            "compliance_checks": [check.to_dict() for check in checks],
        }
    )
    artifact_id = _sha256_hex(f"{MVCR_ARTIFACT_NAMESPACE}|{artifact_basis}")

    lineage = MVCRLineage(
        trigger_id=trigger_identity.trigger_id,
        normalized_settlement_hash=trigger_identity.normalized_settlement_hash,
        erp_sync_idempotency_key=erp_identity.idempotency_key,
        settlement_reference_source=settlement_reference_source,
        source_event_id=source_event_id,
        manifest_anchor_payload=manifest_anchor_payload,
    )

    normalized_message_type = (
        _normalize_identifier(iso20022_message_type, "iso20022_message_type")
        if iso20022_message_type
        else None
    )

    return MVCRArtifact(
        artifact_id=artifact_id,
        profile="mvcr.v1",
        generated_at=generated_at_iso,
        rail=trigger_identity.rail,
        erp_system=erp_identity.erp_system,
        direction=erp_identity.direction,
        settlement_reference=settlement_reference,
        iso20022_message_type=normalized_message_type,
        status=status,
        compliance_checks=checks,
        lineage=lineage,
    )


def render_mvcr_artifact_json(artifact: MVCRArtifact) -> str:
    return json.dumps(artifact.to_dict(), indent=2, sort_keys=True)


def render_mvcr_artifact_markdown(artifact: MVCRArtifact) -> str:
    check_rows = "\n".join(
        f"| `{check.code}` | {'pass' if check.passed else 'fail'} | {check.details or ''} |"
        for check in artifact.compliance_checks
    )
    if not check_rows:
        check_rows = "| _none_ | n/a | n/a |"

    return "\n".join(
        [
            f"# MVCR Artifact `{artifact.artifact_id}`",
            "",
            "## Summary",
            "",
            "| Field | Value |",
            "| --- | --- |",
            f"| Profile | `{artifact.profile}` |",
            f"| Generated at | `{artifact.generated_at}` |",
            f"| Rail | `{artifact.rail}` |",
            f"| ERP system | `{artifact.erp_system}` |",
            f"| Direction | `{artifact.direction}` |",
            f"| Settlement reference | `{artifact.settlement_reference}` |",
            f"| ISO 20022 message type | `{artifact.iso20022_message_type or 'n/a'}` |",
            f"| Status | `{artifact.status}` |",
            "",
            "## Compliance checks",
            "",
            "| Check | Result | Details |",
            "| --- | --- | --- |",
            check_rows,
            "",
            "## Lineage",
            "",
            f"- Trigger ID: `{artifact.lineage.trigger_id}`",
            f"- Normalized settlement hash: `{artifact.lineage.normalized_settlement_hash}`",
            f"- ERP sync idempotency key: `{artifact.lineage.erp_sync_idempotency_key}`",
            f"- Settlement reference source: `{artifact.lineage.settlement_reference_source}`",
            f"- Source event ID: `{artifact.lineage.source_event_id or 'n/a'}`",
            f"- Manifest anchor payload: `{artifact.lineage.manifest_anchor_payload or 'n/a'}`",
        ]
    )


def write_mvcr_artifact_files(
    artifact: MVCRArtifact,
    output_dir: Path,
) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)

    json_path = output_dir / f"MVCR_{artifact.artifact_id}.json"
    markdown_path = output_dir / f"MVCR_{artifact.artifact_id}.md"

    json_path.write_text(render_mvcr_artifact_json(artifact), encoding="utf-8")
    markdown_path.write_text(render_mvcr_artifact_markdown(artifact), encoding="utf-8")

    return json_path, markdown_path


def _sha256_hex(payload: str) -> str:
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _canonicalize_json_value(value: Any) -> Any:
    if isinstance(value, str):
        return unicodedata.normalize("NFC", value)

    if isinstance(value, Mapping):
        normalized: dict[str, Any] = {}
        for key in sorted(value):
            if not isinstance(key, str):
                raise ValueError("JSON object keys must be strings for canonicalization")
            normalized[key] = _canonicalize_json_value(value[key])
        return normalized

    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        return [_canonicalize_json_value(item) for item in value]

    if isinstance(value, (int, float, bool)) or value is None:
        return value

    raise ValueError(f"Unsupported value type for canonicalization: {type(value)!r}")


def _normalize_identifier(value: str, field_name: str, lowercase: bool = False) -> str:
    if not isinstance(value, str):
        raise ValueError(f"{field_name} must be a string")

    normalized = unicodedata.normalize("NFC", value).strip()
    if not normalized:
        raise ValueError(f"{field_name} must be non-empty")

    if lowercase:
        normalized = normalized.lower()

    return normalized


def _normalize_compliance_checks(
    compliance_checks: Sequence[ComplianceCheck | Mapping[str, Any]],
) -> tuple[ComplianceCheck, ...]:
    if not compliance_checks:
        raise ValueError("compliance_checks must include at least one check")

    normalized_checks: list[ComplianceCheck] = []
    for check in compliance_checks:
        if isinstance(check, ComplianceCheck):
            normalized_checks.append(check)
            continue

        if not isinstance(check, Mapping):
            raise ValueError("compliance_checks entries must be ComplianceCheck or mapping values")

        code = check.get("code")
        passed = check.get("passed")
        details = check.get("details")

        if not isinstance(code, str) or not code.strip():
            raise ValueError("compliance_checks.code must be a non-empty string")

        if not isinstance(passed, bool):
            raise ValueError("compliance_checks.passed must be a boolean")

        normalized_checks.append(
            ComplianceCheck(
                code=_normalize_identifier(code, field_name="compliance_checks.code"),
                passed=passed,
                details=(
                    _normalize_identifier(str(details), field_name="compliance_checks.details")
                    if details is not None and str(details).strip()
                    else None
                ),
            )
        )

    return tuple(normalized_checks)


def _is_sha256_hex(value: str) -> bool:
    return len(value) == 64 and all(character in "0123456789abcdef" for character in value)
