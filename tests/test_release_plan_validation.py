from __future__ import annotations

import importlib.util
import json
from pathlib import Path
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


class ReleasePlanValidationTests(unittest.TestCase):
    def write_manifest(self, root: Path, definitions: list[tuple[str, list[str]]]) -> Path:
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
    ) -> None:
        transactions = []
        for name, source_path in publishes:
            transactions.append(
                {
                    "contract-publish": {
                        "contract-name": name,
                        "expected-sender": "ST1FIXTUREDEPLOYER000000000000000000000",
                        "cost": 20000,
                        "path": source_path or f"contracts/{name}.clar",
                        "anchor-block-only": True,
                        "clarity-version": 4,
                        "epoch": 3.0,
                    }
                }
            )
        for contract_id, method in calls or []:
            transactions.append(
                {
                    "contract-call": {
                        "contract-id": contract_id,
                        "expected-sender": "ST1FIXTUREDEPLOYER000000000000000000000",
                        "method": method,
                        "parameters": [],
                        "cost": 10000,
                    }
                }
            )
        document = {
            "id": 1,
            "name": f"fixture {network}",
            "network": network,
            "stacks-node": f"https://{network}.example.invalid",
            "deployer": "ST1FIXTUREDEPLOYER000000000000000000000",
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

    def test_explicit_exclusion_is_allowed_when_absent_but_not_as_dependency(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            manifest_path = self.write_manifest(root, [("consumer", []), ("alex-adapter", [])])
            self.validate_pair(root, manifest_path, [("consumer", None)])

            manifest_path = self.write_manifest(root, [("consumer", ["alex-adapter"]), ("alex-adapter", [])])
            with self.assertRaisesRegex(
                release_plan_validation.ReleasePlanValidationError,
                r"depends on explicitly excluded contract alex-adapter",
            ):
                self.validate_pair(root, manifest_path, [("consumer", None)])

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
