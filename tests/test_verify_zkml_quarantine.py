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
;; A comment may contain fake balanced-looking forms without changing the AST.
;; (define-public (fake (buff 2048)) (ok true))
(define-constant ERR_INVALID_PROOF (err u7001))
(define-constant ERR_UNAUTHORIZED (err u7002))
(define-constant ERR_VERIFIER_UNAVAILABLE (err u7003))

(define-data-var admin principal tx-sender)

(define-public
  (verify-proof
    (model-id (string-ascii 64))
    (input-hash (buff 32))
    (proof (buff 1024)))
  ERR_VERIFIER_UNAVAILABLE)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-read-only (get-protocol-status)
  (ok {
    compliant: false,
    version: "v1.1.0-Apex",
    mode: "ZKML-PAUSED"
  }))
"""

ACTIVE_DOCS = {
    "contracts/compliance/README.md": (
        "ZKML is a quarantined scaffold and fails closed; the unavailable "
        "verifier has no production backend claimed."
    ),
    "PRD.md": (
        "ZKML remains scaffold only, quarantined and fail-closed; no production "
        "verifier qualification is claimed."
    ),
    "docs/SYSTEM_ALIGNMENT_AUDIT_MARCH_2026.md": (
        "This historical ZKML quarantine scaffold is unavailable and fail closed; "
        "no production implementation is claimed."
    ),
    "docs/CONXIAN_SYSTEM_RESEARCH_SYNOPSIS.md": (
        "ZKML is a quarantine scaffold; verification is unavailable and fail closed, "
        "with no production backend claimed."
    ),
}

HISTORICAL_DOC = "Historical and superseded ZKML scaffold evidence.\n"


class ZkmlQuarantineGuardTests(unittest.TestCase):
    def write_fixture(
        self,
        root: Path,
        *,
        contract: str = CANONICAL_CONTRACT,
        docs: dict[str, str] | None = None,
        include_in_release_plan: bool = False,
    ) -> None:
        files = {
            "contracts/compliance/zkml-verifier.clar": contract,
            **(docs or ACTIVE_DOCS),
            "docs/STANDARDS_VALIDATION_SESSION_25.md": HISTORICAL_DOC,
            "scripts/gen-deployment-plans.py": (
                'RELEASE_PLAN_EXCLUSIONS = {"zkml-verifier"}\n'
            ),
            "scripts/release_plan_validation.py": (
                'RELEASE_PLAN_EXCLUSIONS = frozenset({"zkml-verifier"})\n'
            ),
            "deployments/default.simnet-plan.yaml": (
                "      contract-name: zkml-verifier\n"
                "      path: contracts/compliance/zkml-verifier.clar\n"
            ),
            "deployments/full-system.testnet-plan.yaml": "plan:\n  batches: []\n",
            "deployments/full-system.mainnet-plan.yaml": "plan:\n  batches: []\n",
            "deployments/mainnet-release-plan.yaml": "plan:\n  batches: []\n",
        }
        if include_in_release_plan:
            files["deployments/full-system.testnet-plan.yaml"] += (
                "  path: contracts/compliance/zkml-verifier.clar\n"
            )

        for relative_path, content in files.items():
            path = root / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    def assert_rejected(
        self,
        *,
        contract: str = CANONICAL_CONTRACT,
        docs: dict[str, str] | None = None,
        include_in_release_plan: bool = False,
    ) -> list[str]:
        with tempfile.TemporaryDirectory(prefix="zkml-guard-test-") as temporary_directory:
            root = Path(temporary_directory)
            self.write_fixture(
                root,
                contract=contract,
                docs=docs,
                include_in_release_plan=include_in_release_plan,
            )
            errors = guard.collect_errors(root)
            self.assertTrue(errors, "the adversarial fixture unexpectedly passed")
            return errors

    def test_canonical_safe_fixture_passes_with_comments_and_whitespace(self) -> None:
        with tempfile.TemporaryDirectory(prefix="zkml-guard-test-") as temporary_directory:
            root = Path(temporary_directory)
            self.write_fixture(root)
            self.assertEqual(guard.collect_errors(root), [])

    def test_rejects_exact_abi_drift(self) -> None:
        errors = self.assert_rejected(
            contract=CANONICAL_CONTRACT.replace("(buff 1024)", "(buff 2048)", 1)
        )
        self.assertTrue(any("ABI" in error for error in errors))

    def test_rejects_direct_literal_success(self) -> None:
        self.assert_rejected(
            contract=CANONICAL_CONTRACT.replace(
                "  ERR_VERIFIER_UNAVAILABLE)\n\n(define-public",
                "  (ok true))\n\n(define-public",
                1,
            )
        )

    def test_rejects_dynamic_or_obfuscated_success(self) -> None:
        self.assert_rejected(
            contract=CANONICAL_CONTRACT.replace(
                "  ERR_VERIFIER_UNAVAILABLE)\n\n(define-public",
                "  (if true (ok (if true true false)) ERR_VERIFIER_UNAVAILABLE))\n\n(define-public",
                1,
            )
        )

    def test_rejects_helper_mediated_return_or_success(self) -> None:
        contract = CANONICAL_CONTRACT.replace(
            "  ERR_VERIFIER_UNAVAILABLE)\n\n(define-public",
            "  (unavailable-verifier))\n\n(define-private (unavailable-verifier) (ok true))\n\n(define-public",
            1,
        )
        self.assert_rejected(contract=contract)

    def test_rejects_helper_or_renamed_positive_event_emission(self) -> None:
        contract = CANONICAL_CONTRACT.replace(
            "\n(define-public (set-admin",
            '\n(define-private (emit-proof-accepted)\n  (print { event: "proof-accepted" }))\n\n(define-public (set-admin',
            1,
        )
        errors = self.assert_rejected(contract=contract)
        self.assertTrue(any("print/event" in error for error in errors))

    def test_rejects_length_only_conditional_path(self) -> None:
        self.assert_rejected(
            contract=CANONICAL_CONTRACT.replace(
                "  ERR_VERIFIER_UNAVAILABLE)\n\n(define-public",
                "  (if (> (len proof) u0) (ok true) ERR_VERIFIER_UNAVAILABLE))\n\n(define-public",
                1,
            )
        )

    def test_rejects_active_compliant_status(self) -> None:
        self.assert_rejected(
            contract=CANONICAL_CONTRACT.replace(
                'compliant: false,\n    version: "v1.1.0-Apex",\n    mode: "ZKML-PAUSED"',
                'compliant: true,\n    version: "v1.1.0-Apex",\n    mode: "ZKML-ACTIVE"',
                1,
            )
        )

    def test_rejects_release_plan_inclusion(self) -> None:
        errors = self.assert_rejected(include_in_release_plan=True)
        self.assertTrue(any("full-system.testnet-plan.yaml" in error for error in errors))

    def test_rejects_false_active_documentation_claim(self) -> None:
        docs = dict(ACTIVE_DOCS)
        docs["PRD.md"] += "\nThe ZKML verifier is\nproduction-ready and operational.\n"
        errors = self.assert_rejected(docs=docs)
        self.assertTrue(any("active positive ZKML" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
