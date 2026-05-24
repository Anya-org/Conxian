from __future__ import annotations

import sys
import unicodedata
import unittest
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from erp_mvcr_foundation import (  # noqa: E402
    build_settlement_trigger_identity,
    generate_mvcr_artifact,
    render_mvcr_artifact_markdown,
)


class SettlementTriggerIdentityTests(unittest.TestCase):
    def test_trigger_identity_is_deterministic_for_equivalent_payloads(self) -> None:
        composed_reference = "réf-0001"
        decomposed_reference = unicodedata.normalize("NFD", composed_reference)

        payload_a = {
            "payment_identification": {
                "uetr": composed_reference,
                "instruction_id": "instr-01",
            },
            "interbank_settlement_amount": {
                "currency": "ZAR",
                "value": "1000.50",
            },
        }
        payload_b = {
            "interbank_settlement_amount": {
                "value": "1000.50",
                "currency": "ZAR",
            },
            "payment_identification": {
                "instruction_id": "instr-01",
                "uetr": decomposed_reference,
            },
        }

        identity_a = build_settlement_trigger_identity("ISO20022", payload_a)
        identity_b = build_settlement_trigger_identity("iso-20022", payload_b)

        self.assertEqual(identity_a.normalized_settlement_hash, identity_b.normalized_settlement_hash)
        self.assertEqual(identity_a.trigger_id, identity_b.trigger_id)
        self.assertEqual(identity_a.idempotency_key, identity_b.idempotency_key)


class MVCRArtifactGenerationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settlement_payload = {
            "payment_identification": {
                "uetr": "UETR-ABC-001",
            },
            "interbank_settlement_amount": {
                "currency": "ZAR",
                "value": "912.15",
            },
            "debtor": {"name": "Conxian Treasury"},
            "creditor": {"name": "Institutional Partner"},
        }

    def test_generate_mvcr_artifact_success(self) -> None:
        artifact = generate_mvcr_artifact(
            rail="ISO20022",
            settlement_payload=self.settlement_payload,
            erp_system="SAP-S4",
            direction="egress",
            compliance_checks=[
                {"code": "ISO20022_SCHEMA_VALID", "passed": True},
                {"code": "ERP_DELIVERY_ACKNOWLEDGED", "passed": True},
            ],
            iso20022_message_type="pacs.008.001.10",
            source_event_id="evt-100",
            manifest_anchor_payload="abc123",
            generated_at=datetime(2026, 5, 24, 8, 0, tzinfo=timezone.utc),
        )

        self.assertEqual(artifact.status, "passed")
        self.assertEqual(artifact.rail, "ISO20022")
        self.assertEqual(artifact.erp_system, "sap-s4")
        self.assertEqual(artifact.direction, "egress")
        self.assertEqual(artifact.settlement_reference, "UETR-ABC-001")

        markdown_output = render_mvcr_artifact_markdown(artifact)
        self.assertIn("MVCR Artifact", markdown_output)
        self.assertIn("ISO20022_SCHEMA_VALID", markdown_output)
        self.assertIn(artifact.artifact_id, markdown_output)

    def test_generate_mvcr_artifact_marks_failed_when_check_fails(self) -> None:
        artifact = generate_mvcr_artifact(
            rail="ISO20022",
            settlement_payload=self.settlement_payload,
            erp_system="SAP-S4",
            direction="egress",
            compliance_checks=[
                {
                    "code": "ISO20022_SCHEMA_VALID",
                    "passed": False,
                    "details": "Missing mandatory instructed amount",
                }
            ],
            generated_at=datetime(2026, 5, 24, 8, 5, tzinfo=timezone.utc),
        )

        self.assertEqual(artifact.status, "failed")

    def test_generate_mvcr_artifact_raises_when_reference_missing(self) -> None:
        with self.assertRaises(ValueError):
            generate_mvcr_artifact(
                rail="ISO20022",
                settlement_payload={"interbank_settlement_amount": {"currency": "ZAR", "value": "100.00"}},
                erp_system="Oracle",
                direction="ingress",
                compliance_checks=[{"code": "PARSED", "passed": True}],
            )


if __name__ == "__main__":
    unittest.main()
