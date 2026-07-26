from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import yaml


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "release_plan_validation.py"
SPEC = importlib.util.spec_from_file_location("release_plan_validation", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
release_plan_validation = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = release_plan_validation
SPEC.loader.exec_module(release_plan_validation)


FIXTURE_DEPLOYER = "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P"


class ReleasePlanValidationTests(unittest.TestCase):
    def write_manifest(
        self,
        root: Path,
        definitions: list[tuple[str, list[str]]],
        epochs: dict[str, float] | None = None,
    ) -> Path:
        lines = [
            "[project]",
            'name = "fixture"',
            "",
        ]
        for name, dependencies in definitions:
            source_path = f"contracts/{name}.clar"
            source_file = root / source_path
            source_file.parent.mkdir(parents=True, exist_ok=True)
            source_file.write_text(f";; fixture {name}\n")
            lines.extend(
                [
                    f"[contracts.{name}]",
                    f'path = "{source_path}"',
                    "clarity-version = 4",
                    f"epoch = {(epochs or {}).get(name, 3.0)}",
                ]
            )
            if dependencies:
                lines.append(f"depends_on = {json.dumps(dependencies)}")
            lines.append("")
        manifest_path = root / "Clarinet.toml"
        manifest_path.write_text("\n".join(lines))
        return manifest_path

    def write_plan(
        self,
        path: Path,
        network: str,
        publishes: list[tuple[str, str | None]],
        calls: list[tuple[str, str]] | None = None,
        epochs: dict[str, float] | None = None,
    ) -> None:
        transactions = []
        for name, source_path in publishes:
            transactions.append(
                {
                    "contract-publish": {
                        "contract-name": name,
                        "expected-sender": FIXTURE_DEPLOYER,
                        "cost": release_plan_validation.EXPECTED_PUBLISH_COSTS[network],
                        "path": source_path or f"contracts/{name}.clar",
                        "anchor-block-only": True,
                        "clarity-version": 4,
                        "epoch": (epochs or {}).get(name, 3.0),
                    }
                }
            )
        for contract_id, method in calls or []:
            transactions.append(
                {
                    "contract-call": {
                        "contract-id": contract_id,
                        "expected-sender": FIXTURE_DEPLOYER,
                        "method": method,
                        "parameters": [],
                        "cost": 10000,
                    }
                }
            )
        document = {
            "id": 1,
            "name": release_plan_validation.EXPECTED_PLAN_NAMES[network],
            "network": network,
            "stacks-node": release_plan_validation.EXPECTED_STACKS_NODES[network],
            "deployer": FIXTURE_DEPLOYER,
            "plan": {"batches": [{"id": 0, "transactions": transactions}]},
        }
        path.write_text(yaml.safe_dump(document, sort_keys=False))

    def validate_pair(
        self,
        root: Path,
        manifest_path: Path,
        testnet_publishes: list[tuple[str, str | None]],
        mainnet_publishes: list[tuple[str, str | None]] | None = None,
        testnet_calls: list[tuple[str, str]] | None = None,
        mainnet_calls: list[tuple[str, str]] | None = None,
    ):
        testnet_path = root / "testnet.yaml"
        mainnet_path = root / "mainnet.yaml"
        self.write_plan(testnet_path, "testnet", testnet_publishes, testnet_calls)
        self.write_plan(mainnet_path, "mainnet", mainnet_publishes or testnet_publishes, mainnet_calls)
        return release_plan_validation.validate_release_plan_files(
            testnet_path,
            mainnet_path,
            manifest_path,
            root,
            yaml,
        )

    def fixture_pair(
        self,
        root: Path,
        definitions: list[tuple[str, list[str]]] | None = None,
        publishes: list[tuple[str, str | None]] | None = None,
        calls: list[tuple[str, str]] | None = None,
    ) -> tuple[Path, Path, Path, dict, dict]:
        manifest_path = self.write_manifest(
            root,
            definitions or [("a", []), ("b", [])],
        )
        publish_entries = publishes or [("a", None), ("b", None)]
        testnet_path = root / "testnet.yaml"
        mainnet_path = root / "mainnet.yaml"
        self.write_plan(testnet_path, "testnet", publish_entries, calls)
        self.write_plan(mainnet_path, "mainnet", publish_entries, calls)
        return (
            manifest_path,
            testnet_path,
            mainnet_path,
            yaml.safe_load(testnet_path.read_text()),
            yaml.safe_load(mainnet_path.read_text()),
        )

    def write_document(self, path: Path, document: dict) -> None:
        path.write_text(yaml.safe_dump(document, sort_keys=False))

    @staticmethod
    def transaction_bodies(document: dict, transaction_type: str) -> list[dict]:
        return [
            transaction[transaction_type]
            for batch in document["plan"]["batches"]
            for transaction in batch["transactions"]
            if transaction_type in transaction
        ]

    def test_valid_pair_and_stable_dependency_order(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(root, [("a", ["b"]), ("b", [])])
            source_plan = {
                "plan": {
                    "batches": [
                        {
                            "id": 0,
                            "transactions": [
                                {
                                    "transaction-type": "emulated-contract-publish",
                                    "contract-name": "a",
                                    "path": "contracts/a.clar",
                                    "clarity-version": 4,
                                },
                            ],
                        },
                        {
                            "id": 1,
                            "transactions": [
                                {
                                    "transaction-type": "emulated-contract-publish",
                                    "contract-name": "b",
                                    "path": "contracts/b.clar",
                                    "clarity-version": 4,
                                },
                            ],
                        }
                    ]
                }
            }
            contracts = release_plan_validation.load_clarinet_manifest(manifest_path, root)
            source_batches = release_plan_validation.validate_simnet_source(
                source_plan, contracts, root, "fixture.simnet-plan.yaml"
            )
            ordered = release_plan_validation.dependency_ordered_batches(source_batches, contracts)
            self.assertEqual([len(batch) for batch in ordered], [1, 1])
            self.assertEqual([entry.contract_name for batch in ordered for entry in batch], ["b", "a"])

            self.validate_pair(root, manifest_path, [("b", None), ("a", None)])

    def test_manifest_epoch_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(root, [("a", [])], {"a": 3.3})
            testnet_path = root / "testnet.yaml"
            mainnet_path = root / "mainnet.yaml"
            self.write_plan(testnet_path, "testnet", [("a", None)])
            self.write_plan(mainnet_path, "mainnet", [("a", None)], epochs={"a": 3.3})
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"contract a epoch 3\.0 does not match active Clarinet\.toml value 3\.3",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

    def test_generator_emits_manifest_epoch(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        generator_path = repo_root / "scripts" / "gen-deployment-plans.py"
        spec = importlib.util.spec_from_file_location("gen_deployment_plans_epochs", generator_path)
        assert spec is not None and spec.loader is not None
        generator = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = generator
        spec.loader.exec_module(generator)
        contracts = [[
            {
                "contract-name": "sip-standards",
                "path": "contracts/traits/sip-standards.clar",
                "clarity-version": 4,
                "epoch": 3.3,
            },
            {
                "contract-name": "cxlp-token",
                "path": "contracts/tokens/cxlp-token.clar",
                "clarity-version": 4,
                "epoch": 3.0,
            },
            {
                "contract-name": "concentrated-liquidity-pool",
                "path": "contracts/dex/concentrated-liquidity-pool.clar",
                "clarity-version": 4,
                "epoch": 3.0,
            },
        ]]
        plan = generator.make_plan(
            contracts,
            "testnet",
            generator.EXPECTED_PLAN_NAMES["testnet"],
            generator.EXPECTED_STACKS_NODES["testnet"],
            generator.COST_TESTNET,
        )
        publishes = self.transaction_bodies(plan, "contract-publish")
        self.assertEqual(publishes[0]["epoch"], 3.3)

    def test_unsupported_manifest_epoch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(root, [("a", [])], {"a": 9.9})
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"contract a epoch must be one of",
            ):
                release_plan_validation.load_clarinet_manifest(manifest_path, root)

    def test_duplicate_publish_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(root, [("a", []), ("b", [])])
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"duplicate contract publish a",
            ):
                self.validate_pair(root, manifest_path, [("a", None), ("b", None), ("a", None)])

    def test_unknown_contract_and_path_mismatch_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(root, [("a", [])])
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"unknown contract publish unknown",
            ):
                self.validate_pair(root, manifest_path, [("a", None), ("unknown", None)])

            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"contract a path contracts/other\.clar does not match",
            ):
                self.validate_pair(root, manifest_path, [("a", "contracts/other.clar")])

    def test_dependency_inversion_fails_with_positions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(root, [("a", ["b"]), ("b", [])])
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"dependency inversion: b .* must be published before a",
            ):
                self.validate_pair(root, manifest_path, [("a", None), ("b", None)])

    def test_missing_active_dependency_is_distinguished_from_exclusion(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(root, [("a", ["b"]), ("b", [])])
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"release contract a is missing dependency b",
            ):
                self.validate_pair(root, manifest_path, [("a", None)])

    def test_dependency_cycle_is_rejected_from_active_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(root, [("a", ["b"]), ("b", ["a"])])
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"dependency cycle.*a -> b -> a",
            ):
                release_plan_validation.load_clarinet_manifest(manifest_path, root)

    def test_network_topology_drift_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(root, [("a", []), ("b", [])])
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"testnet/mainnet release topology drift",
            ):
                self.validate_pair(
                    root,
                    manifest_path,
                    [("a", None), ("b", None)],
                    [("b", None), ("a", None)],
                )

    def test_deployer_format_and_pair_consistency_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path, testnet_path, mainnet_path, testnet, mainnet = self.fixture_pair(root)
            testnet["deployer"] = "not-a-stacks-address"
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"deployer must be a 41-character Stacks address",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

            manifest_path, testnet_path, mainnet_path, testnet, mainnet = self.fixture_pair(root)
            alternate_deployer = "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM5Q"
            mainnet["deployer"] = alternate_deployer
            for body in self.transaction_bodies(mainnet, "contract-publish"):
                body["expected-sender"] = alternate_deployer
            self.write_document(mainnet_path, mainnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"testnet/mainnet release deployer drift",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

    def test_every_transaction_expected_sender_must_match_deployer(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path, testnet_path, mainnet_path, testnet, _ = self.fixture_pair(
                root,
                calls=[(f"{FIXTURE_DEPLOYER}.a", "initialize")],
            )
            testnet["plan"]["batches"][0]["transactions"][0]["contract-publish"]["expected-sender"] = (
                "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM5Q"
            )
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"publish a .* expected-sender .* does not equal plan deployer",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

            manifest_path, testnet_path, mainnet_path, testnet, _ = self.fixture_pair(
                root,
                calls=[(f"{FIXTURE_DEPLOYER}.a", "initialize")],
            )
            call_body = self.transaction_bodies(testnet, "contract-call")[0]
            call_body["expected-sender"] = "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM5Q"
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"call .*\.initialize .* expected-sender .* does not equal plan deployer",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

    def test_canonical_stacks_node_is_required_for_each_network(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path, testnet_path, mainnet_path, testnet, _ = self.fixture_pair(root)
            testnet["stacks-node"] = "https://api.testnet.example.invalid"
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"stacks-node .* expected 'https://api\.testnet\.hiro\.so'",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

    def test_plan_id_and_name_are_canonical_for_the_declared_network(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path, testnet_path, mainnet_path, testnet, _ = self.fixture_pair(root)
            testnet["id"] = 2
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"plan id is 2, expected 1 for testnet",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

            manifest_path, testnet_path, mainnet_path, testnet, _ = self.fixture_pair(root)
            testnet["name"] = "Unexpected release plan"
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"plan name is .* expected 'Full System Deployment \(July 2026\)'",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

    def test_publish_and_call_costs_are_positive_and_network_specific(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path, testnet_path, mainnet_path, testnet, _ = self.fixture_pair(
                root,
                calls=[(f"{FIXTURE_DEPLOYER}.a", "initialize")],
            )
            publish_body = self.transaction_bodies(testnet, "contract-publish")[0]
            publish_body["cost"] = 0
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"release publish a cost must be a positive integer",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

            manifest_path, testnet_path, mainnet_path, testnet, _ = self.fixture_pair(
                root,
                calls=[(f"{FIXTURE_DEPLOYER}.a", "initialize")],
            )
            publish_body = self.transaction_bodies(testnet, "contract-publish")[0]
            publish_body["cost"] = 30000
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"publish a .* does not match the testnet publish cost 20000",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

            manifest_path, testnet_path, mainnet_path, testnet, _ = self.fixture_pair(
                root,
                calls=[(f"{FIXTURE_DEPLOYER}.a", "initialize")],
            )
            call_body = self.transaction_bodies(testnet, "contract-call")[0]
            call_body["cost"] = 9999
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"call .*\.initialize .* does not match the release call cost 10000",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

    def test_batch_ids_must_be_present_unique_and_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path, testnet_path, mainnet_path, testnet, _ = self.fixture_pair(root)
            del testnet["plan"]["batches"][0]["id"]
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"batch 0 is missing required id",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

            manifest_path, testnet_path, mainnet_path, testnet, _ = self.fixture_pair(root)
            testnet["plan"]["batches"].append({"id": 0, "transactions": []})
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"batch ids must be unique",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

            manifest_path, testnet_path, mainnet_path, testnet, _ = self.fixture_pair(root)
            testnet["plan"]["batches"][0]["id"] = 1
            self.write_document(testnet_path, testnet)
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"batch ids must be the deterministic sequence 0\.\.0",
            ):
                release_plan_validation.validate_release_plan_files(
                    testnet_path, mainnet_path, manifest_path, root, yaml
                )

    def test_generator_imports_via_importlib_from_repo_root(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        import_script = """
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys

path = Path("scripts/gen-deployment-plans.py").resolve()
spec = spec_from_file_location("gen_deployment_plans_fixture", path)
assert spec is not None and spec.loader is not None
module = module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
assert module.DEPLOYER
"""
        result = subprocess.run(
            [sys.executable, "-c", import_script],
            cwd=repo_root,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_explicit_exclusion_is_allowed_when_absent_but_not_as_dependency(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(root, [("consumer", []), ("integration-fee-collector", [])])
            self.validate_pair(root, manifest_path, [("consumer", None)])

            manifest_path = self.write_manifest(
                root,
                [("consumer", ["integration-fee-collector"]), ("integration-fee-collector", [])],
            )
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"depends on explicitly excluded contract integration-fee-collector",
            ):
                self.validate_pair(root, manifest_path, [("consumer", None)])

    def test_zkml_verifier_is_quarantined_from_release_plans(self) -> None:
        self.assertIn("zkml-verifier", release_plan_validation.RELEASE_PLAN_EXCLUSIONS)

        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(
                root,
                [("consumer", []), ("zkml-verifier", [])],
            )
            self.validate_pair(root, manifest_path, [("consumer", None)])

            contracts = release_plan_validation.load_clarinet_manifest(manifest_path, root)
            self.assertEqual(
                release_plan_validation.release_contract_names(contracts),
                {"consumer"},
            )

    def test_missing_source_file_is_rejected_by_manifest_parser(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = root / "Clarinet.toml"
            manifest_path.write_text(
                "[project]\nname = \"fixture\"\n\n[contracts.missing]\n"
                'path = "contracts/missing.clar"\nclarity-version = 4\n'
            )
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"source file does not exist: contracts/missing\.clar",
            ):
                release_plan_validation.load_clarinet_manifest(manifest_path, root)

    def test_legacy_complete_manifest_is_never_used(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            legacy_manifest = root / "Clarinet.complete.toml"
            legacy_manifest.write_text("[contracts.legacy]\npath = \"contracts/legacy.clar\"\n")
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"must use the active Clarinet\.toml manifest",
            ):
                release_plan_validation.load_clarinet_manifest(legacy_manifest, root)


if __name__ == "__main__":
    unittest.main()
