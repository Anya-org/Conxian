import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("verify_por_boundary", ROOT / "scripts/verify_proof_of_reserves_boundary.py")
assert SPEC and SPEC.loader
guard = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = guard
SPEC.loader.exec_module(guard)

SAFE_POR = """
(define-public (submit-attestation (signature (buff 65)))
  (begin (asserts! (secp256k1-verify 0x00 signature 0x02) (err u1)) (ok true)))
(define-read-only (digest) (to-consensus-buff? {nonce: u1}))
"""


class ProofOfReservesBoundaryGuardTests(unittest.TestCase):
    def errors(self, consumer: str = "", por: str = SAFE_POR) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            por_path = root / "contracts/security/proof-of-reserves.clar"
            por_path.parent.mkdir(parents=True)
            por_path.write_text(por, encoding="utf-8")
            consumer_path = root / "contracts/core/consumer.clar"
            consumer_path.parent.mkdir(parents=True)
            consumer_path.write_text(consumer, encoding="utf-8")
            return guard.collect_errors(root)

    def test_current_repository_passes(self):
        self.assertEqual(guard.collect_errors(ROOT), [])

    def test_allows_only_status_calls(self):
        self.assertEqual(self.errors("(contract-call? .proof-of-reserves is-fully-backed token)\n(contract-call?\n .proof-of-reserves\n get-proof-status token)"), [])

    def test_allows_status_calls_through_aliases(self):
        self.assertEqual(self.errors("""
(define-constant por .proof-of-reserves)
(contract-call? por is-fully-backed token)
(let ((nested por))
  (contract-call? nested get-proof-status token))
"""), [])

    def test_rejects_raw_state_and_submission_consumers(self):
        for function in ("get-snapshot", "get-validated-attestation", "submit-attestation"):
            self.assertTrue(any(function in error for error in self.errors(f"(contract-call?\n .proof-of-reserves\n {function} value)")))

    def test_rejects_constant_and_let_aliases(self):
        consumers = {
            "get-snapshot": "(define-constant por .proof-of-reserves)\n(contract-call? por get-snapshot x)",
            "submit-attestation": "(let ((por\n .proof-of-reserves))\n (contract-call? por\n submit-attestation x))",
            "get-quorum": "(define-constant por (if true .proof-of-reserves .other-contract))\n(contract-call? por get-quorum)",
        }
        for function, consumer in consumers.items():
            self.assertTrue(any(function in error for error in self.errors(consumer)))

    def test_rejects_fully_qualified_target(self):
        consumer = "(contract-call? 'SP000000000000000000002Q6VF78.proof-of-reserves get-snapshot x)"
        self.assertTrue(any("get-snapshot" in error for error in self.errors(consumer)))

    def test_non_por_and_shadowed_aliases_do_not_trigger(self):
        self.assertEqual(self.errors("""
(define-constant por .proof-of-reserves)
(let ((por .some-other-contract))
  (contract-call? por get-snapshot x))
(contract-call? .some-other-contract submit-attestation x)
"""), [])

    def test_ignores_comments_and_strings(self):
        self.assertEqual(self.errors(';; (contract-call? .proof-of-reserves get-snapshot x)\n"(contract-call? .proof-of-reserves submit-attestation x)"'), [])

    def test_rejects_legacy_callable_and_oracle_conflation(self):
        errors = self.errors(por=SAFE_POR + "\n(define-read-only (get-reserve-data) none)\n(define-data-var oracle-aggregator principal tx-sender)\n")
        self.assertTrue(any("get-reserve-data" in error for error in errors))
        self.assertTrue(any("oracle" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
