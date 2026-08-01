from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
GUARD_PATH = REPO_ROOT / "scripts" / "verify_zkml_quarantine.py"
SPEC = importlib.util.spec_from_file_location("verify_zkml_quarantine", GUARD_PATH)
assert SPEC is not None and SPEC.loader is not None
guard = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = guard
SPEC.loader.exec_module(guard)


CANONICAL_CONTRACT = """\
;; zkml-verifier.clar
;; Conxian Protocol: ZKML verification quarantine scaffold.
;; This contract deliberately has no cryptographic verifier backend.

(define-constant ERR_INVALID_PROOF (err u7001))
(define-constant ERR_UNAUTHORIZED (err u7002))
;; The ABI is retained for callers, but no proof is accepted until a reviewed
;; verifier implementation is qualified and wired. Structural inputs alone
;; must never produce a successful attestation.
(define-constant ERR_VERIFIER_UNAVAILABLE (err u7003))

(define-data-var admin principal tx-sender)

;; @desc Quarantined ZKML proof entry point; always fails closed.
;; @param model-id: The identifier for the ML model.
;; @param input-hash: Hash of the input data.
;; @param proof: The ZK proof payload (e.g. Groth16/Plonk).
;; @return (response bool uint) - Always returns ERR_VERIFIER_UNAVAILABLE.
;; No length check, parser, key registry, or simulated success is permitted.
(define-public (verify-proof (model-id (string-ascii 64)) (input-hash (buff 32)) (proof (buff 1024)))
  ERR_VERIFIER_UNAVAILABLE
)

;; Admin functions

;; @desc Update the contract administrator. Admin only.
;; @param new-admin: The new administrator principal.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-read-only (get-protocol-status)
  (ok { compliant: false, version: "v1.1.0-Apex", mode: "ZKML-PAUSED" })
)
"""

ACTIVE_DOCS = {
    "PRD.md": (
        "ZKML verifier is a quarantined, unavailable scaffold and is not "
        "production-ready."
    ),
    "contracts/compliance/README.md": (
        "The ZKML verifier is a quarantined fail-closed scaffold; verification "
        "is unavailable and not production evidence."
    ),
    "docs/CONXIAN_SYSTEM_RESEARCH_SYNOPSIS.md": (
        "ZKML is a disabled scaffold, unavailable pending review, and not "
        "production evidence."
    ),
    "docs/DOCUMENTATION_STATE.md": (
        "The zkml-verifier remains quarantined from release artifacts and is "
        "unavailable as production evidence."
    ),
    "docs/ORACLE_PRODUCTION_CONFIGURATION.md": (
        "The zkml-verifier release entry is an unavailable quarantined scaffold "
        "and is not production-ready."
    ),
    "docs/SYSTEM_ALIGNMENT_AUDIT_MARCH_2026.md": (
        "This historical ZKML boundary is quarantined and fail-closed; no "
        "production verifier is claimed."
    ),
    "docs/ZKML_EVIDENCE_CONTRACT.md": (
        "ZKML is a future disabled contract; the current verifier is an "
        "unavailable scaffold and not production evidence."
    ),
}

HISTORICAL_DOC = (
    "Historical and superseded ZKML evidence. The verifier is scaffold-only, "
    "unavailable, and not production evidence.\n"
)


class ZkmlQuarantineGuardTests(unittest.TestCase):
    def write_fixture(
        self,
        root: Path,
        *,
        contract: str = CANONICAL_CONTRACT,
        docs: dict[str, str] | None = None,
    ) -> None:
        files = {
            "Clarinet.toml": (
                "[contracts.zkml-verifier]\n"
                'path = "contracts/compliance/zkml-verifier.clar"\n'
            ),
            "contracts/compliance/zkml-verifier.clar": contract,
            "deployments/default.simnet-plan.yaml": (
                "plan:\n"
                "  batches:\n"
                "    - transactions:\n"
                "        - contract-publish:\n"
                "            contract-name: zkml-verifier\n"
                "            path: contracts/compliance/zkml-verifier.clar\n"
            ),
            "deployments/full-system.testnet-plan.yaml": "plan:\n  batches: []\n",
            "deployments/full-system.mainnet-plan.yaml": "plan:\n  batches: []\n",
            "deployments/mainnet-release-plan.yaml": "plan:\n  batches: []\n",
            "scripts/gen-deployment-plans.py": (
                'RELEASE_PLAN_EXCLUSIONS = {"zkml-verifier"}\n'
            ),
            "scripts/release_plan_validation.py": (
                'RELEASE_PLAN_EXCLUSIONS = frozenset({"zkml-verifier"})\n'
            ),
            **(docs or ACTIVE_DOCS),
            "docs/STANDARDS_VALIDATION_SESSION_25.md": HISTORICAL_DOC,
        }
        for relative_path, content in files.items():
            path = root / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    def collect_fixture_errors(
        self,
        *,
        contract: str = CANONICAL_CONTRACT,
        docs: dict[str, str] | None = None,
        release_plan_mutation: tuple[str, str] | None = None,
        release_plan_text: str | None = None,
    ) -> list[str]:
        with tempfile.TemporaryDirectory(prefix="zkml-guard-test-") as temporary_directory:
            root = Path(temporary_directory)
            self.write_fixture(root, contract=contract, docs=docs)
            if release_plan_text is not None:
                plan_path = root / "deployments/full-system.testnet-plan.yaml"
                plan_path.write_text(release_plan_text, encoding="utf-8")
            elif release_plan_mutation is not None:
                key, value = release_plan_mutation
                plan_path = root / "deployments/full-system.testnet-plan.yaml"
                plan_path.write_text(
                    f"plan:\n  {key}: {value}\n", encoding="utf-8"
                )
            return guard.collect_errors(root)

    def assert_rejected(self, **kwargs: object) -> list[str]:
        errors = self.collect_fixture_errors(**kwargs)
        self.assertTrue(errors, "the adversarial fixture unexpectedly passed")
        return errors

    def assert_isolated_documentation_claim(self, statement: str) -> list[str]:
        docs = dict(ACTIVE_DOCS)
        docs["PRD.md"] += f"\n{statement}\n"
        errors = self.collect_fixture_errors(docs=docs)

        self.assertTrue(errors, "the documentation bypass unexpectedly passed")
        self.assertTrue(
            all(
                "PRD.md contains an unnegated positive ZKML claim" in error
                for error in errors
            ),
            errors,
        )
        return errors

    def verify_body(self, body: str) -> str:
        return CANONICAL_CONTRACT.replace(
            "  ERR_VERIFIER_UNAVAILABLE\n)\n\n;; Admin functions",
            f"  {body}\n)\n\n;; Admin functions",
            1,
        )

    def test_canonical_current_main_fixture_passes(self) -> None:
        self.assertEqual(self.collect_fixture_errors(), [])

    def test_one_expression_begin_wrapper_is_the_only_allowed_body_wrapper(self) -> None:
        contract = self.verify_body("(begin ERR_VERIFIER_UNAVAILABLE)")

        self.assertEqual(self.collect_fixture_errors(contract=contract), [])

    def test_rejects_exact_abi_drift(self) -> None:
        contract = CANONICAL_CONTRACT.replace("(proof (buff 1024))", "(proof (buff 2048))", 1)
        errors = self.assert_rejected(contract=contract)

        self.assertTrue(any("ABI" in error for error in errors))

    def test_rejects_direct_literal_success(self) -> None:
        errors = self.assert_rejected(contract=self.verify_body("(ok true)"))

        self.assertTrue(any("success paths" in error for error in errors))

    def test_rejects_dynamic_or_obfuscated_success(self) -> None:
        errors = self.assert_rejected(
            contract=self.verify_body("(if true (ok true) ERR_VERIFIER_UNAVAILABLE)")
        )

        self.assertTrue(any("branches" in error for error in errors))

    def test_rejects_helper_mediated_return_or_success(self) -> None:
        contract = self.verify_body("(unavailable-verifier)").replace(
            "\n;; Admin functions",
            "\n(define-private (unavailable-verifier) (ok true))\n\n;; Admin functions",
            1,
        )
        errors = self.assert_rejected(contract=contract)

        self.assertTrue(any("unexpected definition/callable" in error for error in errors))
        self.assertTrue(any("helper calls" in error for error in errors))

    def test_rejects_an_extra_private_helper_even_when_the_public_abi_is_canonical(self) -> None:
        contract = CANONICAL_CONTRACT.replace(
            "\n;; Admin functions",
            (
                "\n(define-private (read-only-helper) ERR_VERIFIER_UNAVAILABLE)"
                "\n\n;; Admin functions"
            ),
            1,
        )
        errors = self.assert_rejected(contract=contract)

        self.assertTrue(any("read-only-helper" in error for error in errors))

    def test_rejects_an_extra_renamed_read_only_function(self) -> None:
        contract = CANONICAL_CONTRACT.replace(
            "\n;; Admin functions",
            (
                "\n(define-read-only (get-protocol-status-v2) "
                "ERR_VERIFIER_UNAVAILABLE)\n\n;; Admin functions"
            ),
            1,
        )
        errors = self.assert_rejected(contract=contract)

        self.assertTrue(any("get-protocol-status-v2" in error for error in errors))

    def test_rejects_exact_unavailable_mapping_mutation_from_u7003(self) -> None:
        errors = self.assert_rejected(
            contract=CANONICAL_CONTRACT.replace("(err u7003)", "(err u7004)", 1)
        )

        self.assertTrue(any("map exactly to (err u7003)" in error for error in errors))

    def test_quoted_clarity_strings_do_not_create_fake_definition_or_event_findings(
        self,
    ) -> None:
        contract = CANONICAL_CONTRACT.replace(
            "    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)",
            (
                '    "(define-public (fake) (print \\"fake-event\\"))"\n'
                "    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)"
            ),
            1,
        )

        errors = self.collect_fixture_errors(contract=contract)

        self.assertFalse(any("unexpected definition/callable" in error for error in errors))
        self.assertFalse(any("print/event" in error for error in errors))

    def test_rejects_helper_or_renamed_positive_event(self) -> None:
        contract = CANONICAL_CONTRACT.replace(
            "\n;; Admin functions",
            (
                '\n(define-private (emit-proof-accepted) '
                '(print { event: "proof-accepted" }))\n\n;; Admin functions'
            ),
            1,
        )
        errors = self.assert_rejected(contract=contract)

        self.assertTrue(any("print/event" in error for error in errors))
        self.assertTrue(any("unexpected definition/callable" in error for error in errors))

    def test_rejects_length_only_conditional_success(self) -> None:
        errors = self.assert_rejected(
            contract=self.verify_body("(if (> (len proof) u0) (ok true) ERR_VERIFIER_UNAVAILABLE)")
        )

        self.assertTrue(any("length checks" in error for error in errors))

    def test_rejects_active_or_compliant_status_marker(self) -> None:
        contract = CANONICAL_CONTRACT.replace(
            '(define-read-only (get-protocol-status)\n  (ok { compliant: false, version: "v1.1.0-Apex", mode: "ZKML-PAUSED" })\n)',
            '(define-read-only (get-protocol-status)\n  "ZKML-ACTIVE"\n)',
            1,
        )
        errors = self.assert_rejected(contract=contract)

        self.assertTrue(any("active/compliant/verified" in error for error in errors))

    def test_rejects_extra_renamed_public_verifier_callable(self) -> None:
        contract = CANONICAL_CONTRACT.replace(
            "\n;; Admin functions",
            (
                "\n(define-public (verify-proof-v2 (proof (buff 1024))) "
                "(ok true))\n\n;; Admin functions"
            ),
            1,
        )
        errors = self.assert_rejected(contract=contract)

        self.assertTrue(any("verify-proof-v2" in error for error in errors))

    def test_rejects_release_plan_inclusion_under_all_relevant_keys(self) -> None:
        cases = (
            ("contract-name", "zkml-verifier"),
            ("source", "contracts/compliance/zkml-verifier.clar"),
            ("contract-id", "SP000000000000000000002Q6VF78.zkml-verifier"),
        )
        for key, value in cases:
            with self.subTest(key=key):
                errors = self.assert_rejected(
                    release_plan_mutation=(key, value)
                )
                self.assertTrue(
                    any("full-system.testnet-plan.yaml" in error for error in errors)
                )
                self.assertTrue(
                    any("every YAML key/form" in error for error in errors)
                )

    def test_rejects_yaml_contract_identifiers_with_all_double_quoted_escape_forms(
        self,
    ) -> None:
        for escape in (r"\x2d", r"\u002d", r"\U0000002d"):
            with self.subTest(escape=escape):
                plan = (
                    "plan:\n"
                    "  batches:\n"
                    "    - transactions:\n"
                    "        - contract-publish:\n"
                    f'            contract-name: "zkml{escape}verifier"\n'
                )
                errors = self.assert_rejected(release_plan_text=plan)

                self.assertTrue(
                    any(
                        "decoded YAML string" in error
                        and "full-system.testnet-plan.yaml" in error
                        for error in errors
                    )
                )

    def test_rejects_yaml_anchor_alias_block_and_list_source_forms(self) -> None:
        plan = (
            "plan:\n"
            "  quarantined-name: &quarantined zkml-verifier\n"
            "  batches:\n"
            "    - transactions:\n"
            "        - contract-publish:\n"
            "            contract-name: *quarantined\n"
            "            sources:\n"
            "              - |\n"
            "                contracts/compliance/zkml-verifier.clar\n"
        )
        errors = self.assert_rejected(release_plan_text=plan)

        self.assertGreaterEqual(
            sum("decoded YAML string" in error for error in errors), 2
        )

    def test_rejects_release_plan_yaml_parse_errors(self) -> None:
        errors = self.assert_rejected(
            release_plan_text='plan:\n  invalid-escape: "\\q"\n'
        )

        self.assertTrue(any("not valid YAML" in error for error in errors))

    def test_rejects_binary_contract_identifier_as_noncanonical_scalar(self) -> None:
        errors = self.assert_rejected(
            release_plan_text=(
                "plan:\n"
                "  contract-name: !!binary |\n"
                "    emttbC12ZXJpZmllcg==\n"
            )
        )

        self.assertTrue(
            any("unsupported YAML scalar" in error and "!!binary" in error for error in errors)
        )

    def test_rejects_binary_source_path_as_noncanonical_scalar(self) -> None:
        errors = self.assert_rejected(
            release_plan_text=(
                "plan:\n"
                "  source: !!binary |\n"
                "    Y29udHJhY3RzL2NvbXBsaWFuY2UvemttbC12ZXJpZmllci5jbGFy\n"
            )
        )

        self.assertTrue(
            any("unsupported YAML scalar" in error and "!!binary" in error for error in errors)
        )

    def test_rejects_invalid_utf8_binary_scalar(self) -> None:
        errors = self.assert_rejected(
            release_plan_text=(
                "plan:\n"
                "  contract-name: !!binary |\n"
                "    //4=\n"
            )
        )

        self.assertTrue(any("not valid UTF-8" in error for error in errors))

    def test_rejects_timestamps_under_identifier_and_path_fields(self) -> None:
        cases = (
            ("contract-name", "2026-07-23"),
            ("path", "2026-07-23T12:34:56Z"),
        )
        for key, value in cases:
            with self.subTest(key=key):
                errors = self.assert_rejected(
                    release_plan_text=f"plan:\n  {key}: {value}\n"
                )

                self.assertTrue(
                    any(
                        "non-string YAML identifier/path/name field" in error
                        and key in error
                        for error in errors
                    )
                )
                self.assertTrue(any("timestamp" in error for error in errors))

    def test_rejects_numeric_identifier_value_with_typed_scalar_error(self) -> None:
        errors = self.assert_rejected(
            release_plan_text="plan:\n  contract-name: 123\n"
        )

        self.assertTrue(
            any(
                "non-string YAML identifier/path/name field" in error
                and "contract-name" in error
                and "int" in error
                for error in errors
            )
        )

    def test_allows_ordinary_numeric_plan_fields(self) -> None:
        self.assertEqual(
            self.collect_fixture_errors(
                release_plan_text=(
                    "plan:\n"
                    "  id: 123\n"
                    "  cost: 1\n"
                    "  anchor-block-only: false\n"
                )
            ),
            [],
        )

    def test_rejects_not_production_ready_but_active_em_dash_bypass(self) -> None:
        errors = self.assert_isolated_documentation_claim(
            "ZKML verifier is not production-ready — active."
        )

        self.assertTrue(any("active:" in error for error in errors))

    def test_rejects_not_production_ready_colon_active_bypass(self) -> None:
        errors = self.assert_isolated_documentation_claim(
            "ZKML verifier is not production-ready: active."
        )

        self.assertTrue(any("active:" in error for error in errors))

    def test_rejects_not_production_ready_semicolon_active_bypass(self) -> None:
        errors = self.assert_isolated_documentation_claim(
            "ZKML verifier is not production-ready; active."
        )

        self.assertTrue(any("active:" in error for error in errors))

    def test_rejects_not_production_ready_despite_active_bypass(self) -> None:
        errors = self.assert_isolated_documentation_claim(
            "ZKML verifier is not production-ready, despite being active."
        )

        self.assertTrue(any("active:" in error for error in errors))

    def test_rejects_positive_before_anchor_deployed_bypass(self) -> None:
        errors = self.assert_isolated_documentation_claim(
            "Active ZKML verifier is deployed."
        )

        self.assertTrue(any("active:" in error for error in errors))
        self.assertTrue(any("deployed:" in error for error in errors))

    def test_rejects_positive_before_anchor_production_ready_bypass(self) -> None:
        errors = self.assert_isolated_documentation_claim(
            "Production-ready ZKML verifier."
        )

        self.assertTrue(any("production-ready:" in error for error in errors))

    def test_rejects_parenthesized_positive_after_negated_term(self) -> None:
        errors = self.assert_isolated_documentation_claim(
            "ZKML verifier is not compliant (active)."
        )

        self.assertTrue(any("active:" in error for error in errors))

    def test_rejects_newline_contrastive_and_positive_before_anchor_variants(self) -> None:
        cases = (
            "ZKML verifier is not production-ready,\n but active.",
            "Production-ready\nZKML verifier.",
            "ZKML verifier is not compliant\n(active).",
        )
        for statement in cases:
            with self.subTest(statement=statement):
                self.assert_isolated_documentation_claim(statement)

    def test_rejects_positive_document_claim_split_across_lines(self) -> None:
        docs = dict(ACTIVE_DOCS)
        docs["PRD.md"] += "\nZKML\nThe verifier is\nproduction-ready.\n"
        errors = self.assert_rejected(docs=docs)

        self.assertTrue(any("unnegated positive ZKML claim" in error for error in errors))

    def test_rejects_positive_document_claim_across_sentence_boundary(self) -> None:
        docs = dict(ACTIVE_DOCS)
        docs["PRD.md"] += "\nZKML. The verifier is production-ready.\n"
        errors = self.assert_rejected(docs=docs)

        self.assertTrue(any("unnegated positive ZKML claim" in error for error in errors))

    def test_accepts_honest_negated_document_claim(self) -> None:
        docs = dict(ACTIVE_DOCS)
        docs["PRD.md"] += "\nZKML. The verifier is not production-ready.\n"

        self.assertEqual(self.collect_fixture_errors(docs=docs), [])

    def test_accepts_only_local_negations_of_each_readiness_term(self) -> None:
        statements = (
            "ZKML verifier is not production-ready.",
            "ZKML verifier is never verified.",
            "ZKML verifier cannot be treated as active.",
        )
        for statement in statements:
            with self.subTest(statement=statement):
                docs = dict(ACTIVE_DOCS)
                docs["PRD.md"] += f"\n{statement}\n"

                self.assertEqual(self.collect_fixture_errors(docs=docs), [])

    def test_rejects_positive_claims_after_local_negations_and_contrastive_boundaries(
        self,
    ) -> None:
        cases = (
            "ZKML verifier is not production-ready, but active.",
            "The ZKML verifier is not compliant, but verified by the backend.",
            "ZKML verifier is not production-ready,\n  but active.",
            "The ZKML verifier is not compliant,\n  yet verified by the backend.",
            "ZKML verifier is not production-ready; however, it is active.",
            "ZKML verifier is not compliant, while verified by the backend.",
        )
        for statement in cases:
            with self.subTest(statement=statement):
                docs = dict(ACTIVE_DOCS)
                docs["PRD.md"] += f"\n{statement}\n"
                errors = self.assert_rejected(docs=docs)

                self.assertTrue(
                    any("unnegated positive ZKML claim" in error for error in errors)
                )

    def test_malformed_or_ambiguous_clarity_delimiters_fail_closed(self) -> None:
        cases = (
            CANONICAL_CONTRACT.replace(
                "(define-public (verify-proof",
                "(define-public {verify-proof",
                1,
            ),
            CANONICAL_CONTRACT + '\n(define-constant "unterminated',
        )
        for contract in cases:
            with self.subTest(contract=contract[-40:]):
                errors = self.assert_rejected(contract=contract)
                self.assertTrue(any("balanced Clarity" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
