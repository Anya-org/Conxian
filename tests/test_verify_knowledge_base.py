from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

import yaml


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "verify-knowledge-base.py"
SPEC = importlib.util.spec_from_file_location("verify_knowledge_base", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
verify_knowledge_base = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify_knowledge_base
SPEC.loader.exec_module(verify_knowledge_base)


class KnowledgeBaseVerificationTests(unittest.TestCase):
    def write_fixture(self, root: Path) -> None:
        contracts = {
            "concentrated-math": "contracts/math/concentrated-math.clar",
            "math-lib-concentrated": "contracts/math/concentrated-math.clar",
            "concentrated-math-v2": "contracts/math/concentrated-math-v2.clar",
            "concentrated-liquidity-pool-v2": "contracts/dex/concentrated-liquidity-pool-v2.clar",
        }
        manifest_lines = ["[project]", 'name = "fixture"', ""]
        for name, source_path in contracts.items():
            source = root / source_path
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text(f";; {name}\n")
            manifest_lines.extend(
                [
                    f"[contracts.{name}]",
                    f"path = {json.dumps(source_path)}",
                    "clarity-version = 4",
                    "",
                ]
            )
        (root / "Clarinet.toml").write_text("\n".join(manifest_lines))

        tests_directory = root / "tests"
        tests_directory.mkdir()
        (tests_directory / "fixture.test.ts").write_text("// fixture\n")

        for relative_path in verify_knowledge_base.PLAN_PATHS:
            plan_path = root / relative_path
            plan_path.parent.mkdir(parents=True, exist_ok=True)
            publishes = [
                {
                    "contract-publish": {
                        "contract-name": name,
                        "path": source_path,
                    }
                }
                for name, source_path in contracts.items()
                if name != "math-lib-concentrated"
            ]
            document = {
                "plan": {
                    "batches": [
                        {"id": 0, "transactions": publishes},
                        {
                            "id": 1,
                            "transactions": [
                                {
                                    "contract-call": {
                                        "contract-id": ".fixture",
                                        "method": "wire",
                                    }
                                }
                            ],
                        },
                    ]
                }
            }
            plan_path.write_text(yaml.safe_dump(document, sort_keys=False))

        (root / "AGENTS.md").write_text(
            "# Fixture\n\n"
            f"{verify_knowledge_base.BLOCK_START}\n"
            "stale\n"
            f"{verify_knowledge_base.BLOCK_END}\n"
        )

    def test_stale_fact_block_is_detected_without_mutating_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self.write_fixture(root)
            before = (root / "AGENTS.md").read_text()

            errors = verify_knowledge_base.check_repository(root)

            self.assertRegex("\n".join(errors), r"facts are stale")
            self.assertEqual((root / "AGENTS.md").read_text(), before)

    def test_write_then_check_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self.write_fixture(root)

            self.assertEqual(verify_knowledge_base.check_repository(root, write=True), [])
            generated = (root / "AGENTS.md").read_text()
            self.assertIn("3 physical `contracts/**/*.clar` files", generated)
            self.assertIn("4 active `Clarinet.toml` contract entries", generated)
            self.assertEqual(verify_knowledge_base.check_repository(root), [])

    def test_unexpected_manifest_alias_is_rejected_with_mapping_details(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self.write_fixture(root)
            manifest_path = root / "Clarinet.toml"
            manifest_path.write_text(
                manifest_path.read_text()
                + "\n[contracts.unexpected-v2-alias]\n"
                + 'path = "contracts/math/concentrated-math-v2.clar"\n'
                + "clarity-version = 4\n"
            )

            with self.assertRaises(verify_knowledge_base.KnowledgeBaseError) as context:
                verify_knowledge_base.collect_facts(root)
            diagnostic = str(context.exception)
            self.assertIn("unexpected manifest aliases", diagnostic)
            self.assertIn("contracts/math/concentrated-math-v2.clar", diagnostic)
            self.assertIn("unexpected-v2-alias", diagnostic)

    def test_plan_missing_required_clp_v2_contract_reports_plan_and_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self.write_fixture(root)
            relative_plan_path = verify_knowledge_base.PLAN_PATHS[0]
            plan_path = root / relative_plan_path
            document = yaml.safe_load(plan_path.read_text())
            transactions = document["plan"]["batches"][0]["transactions"]
            document["plan"]["batches"][0]["transactions"] = [
                transaction
                for transaction in transactions
                if transaction["contract-publish"]["contract-name"]
                != "concentrated-liquidity-pool-v2"
            ]
            plan_path.write_text(yaml.safe_dump(document, sort_keys=False))

            with self.assertRaisesRegex(
                verify_knowledge_base.KnowledgeBaseError,
                rf"{relative_plan_path} must publish concentrated-liquidity-pool-v2 .*found None",
            ):
                verify_knowledge_base.collect_facts(root)


if __name__ == "__main__":
    unittest.main()
