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

    def test_rejects_trait_parameter_forwarded_to_raw_call(self):
        consumer = """
(define-private (raw-read (por <raw-por-trait>))
  (contract-call? por get-snapshot u1))

(define-read-only (consumer)
  (raw-read .proof-of-reserves))
"""
        errors = self.errors(consumer)
        self.assertTrue(any("get-snapshot" in error and "raw-read" in error and ":6" in error for error in errors))

    def test_rejects_multi_hop_parameter_forwarding(self):
        consumer = """
(define-private (raw-read (target principal))
  (contract-call? target get-validated-attestation u1))
(define-private (forward (candidate principal))
  (raw-read candidate))
(define-read-only (consumer)
  (forward .proof-of-reserves))
"""
        errors = self.errors(consumer)
        self.assertTrue(any("get-validated-attestation" in error and "forward" in error for error in errors))

    def test_rejects_parameter_alias_inside_helper(self):
        consumer = """
(define-private (raw-read (por <raw-por-trait>))
  (let ((nested por))
    (let ((again nested))
      (contract-call? again get-snapshot u1))))
(define-read-only (consumer)
  (raw-read .proof-of-reserves))
"""
        self.assertTrue(any("get-snapshot" in error for error in self.errors(consumer)))

    def test_rejects_raw_calls_in_let_binding_values(self):
        consumers = (
            """
(define-read-only (consumer)
  (let ((snapshot (contract-call? .proof-of-reserves get-snapshot u1)))
    snapshot))
""",
            """
(define-private (raw-read (target principal))
  (contract-call? target get-snapshot u1))
(define-read-only (consumer)
  (let ((snapshot (raw-read .proof-of-reserves)))
    snapshot))
""",
        )
        for consumer in consumers:
            self.assertTrue(any("get-snapshot" in error for error in self.errors(consumer)))

    def test_match_binding_propagates_parameter_flow(self):
        consumer = """
(define-private (raw-read (target principal))
  (match (some target)
    resolved (contract-call? resolved get-snapshot u1)
    (err u1)))
(define-read-only (consumer)
  (raw-read .proof-of-reserves))
"""
        self.assertTrue(any("get-snapshot" in error for error in self.errors(consumer)))

    def test_match_binding_shadows_same_named_parameter(self):
        consumer = """
(define-private (raw-read (target principal))
  (match (some .some-other-contract)
    target (contract-call? target get-snapshot u1)
    (err u1)))
(define-read-only (consumer)
  (raw-read .proof-of-reserves))
"""
        self.assertEqual(self.errors(consumer), [])

    def test_response_match_bindings_propagate_parameter_flow(self):
        consumer = """
(define-private (raw-read (target principal))
  (match (ok target)
    resolved (contract-call? resolved get-snapshot u1)
    problem (err problem)))
(define-read-only (consumer)
  (raw-read .proof-of-reserves))
"""
        self.assertTrue(any("get-snapshot" in error for error in self.errors(consumer)))

    def test_rejects_constant_and_fully_qualified_values_passed_to_helper(self):
        consumers = (
            """
(define-constant por .proof-of-reserves)
(define-private (raw-read (target principal))
  (contract-call? target get-snapshot u1))
(define-read-only (consumer) (raw-read por))
""",
            """
(define-private (raw-read (target principal))
  (contract-call? target get-snapshot u1))
(define-read-only (consumer)
  (raw-read 'SP000000000000000000002Q6VF78.proof-of-reserves))
""",
        )
        for consumer in consumers:
            self.assertTrue(any("get-snapshot" in error for error in self.errors(consumer)))

    def test_allows_helper_that_only_reads_approved_status(self):
        consumer = """
(define-private (status (por <proof-of-reserves-trait>))
  (let ((target por))
    (contract-call? target is-fully-backed token)))
(define-read-only (consumer)
  (status .proof-of-reserves))
"""
        self.assertEqual(self.errors(consumer), [])

    def test_rejects_helper_parameter_used_for_approved_and_raw_calls(self):
        consumer = """
(define-private (mixed-read (por principal))
  (begin
    (contract-call? por get-proof-status token)
    (contract-call? por get-snapshot u1)))
(define-read-only (consumer)
  (mixed-read .proof-of-reserves))
"""
        errors = self.errors(consumer)
        self.assertTrue(any("get-snapshot" in error for error in errors))
        self.assertFalse(any("unsafe function get-proof-status" in error for error in errors))

    def test_helper_parameter_shadowing_does_not_inherit_por_flow(self):
        consumer = """
(define-constant target .proof-of-reserves)
(define-private (raw-read (target principal))
  (let ((target .some-other-contract))
    (contract-call? target get-snapshot u1)))
(define-read-only (consumer)
  (raw-read .proof-of-reserves))
"""
        self.assertEqual(self.errors(consumer), [])

    def test_nested_caller_let_shadowing_preserves_lexical_scope(self):
        consumer = """
(define-constant por .proof-of-reserves)
(define-private (raw-read (target principal))
  (contract-call? target get-snapshot u1))
(define-read-only (consumer)
  (let ((por .some-other-contract))
    (let ((nested por))
      (raw-read nested))))
"""
        self.assertEqual(self.errors(consumer), [])

    def test_interprocedural_analysis_ignores_comments_and_strings(self):
        consumer = '''
(define-private (safe (target principal))
  ;; (contract-call? target get-snapshot u1)
  "(contract-call? target submit-attestation signature)")
(define-read-only (consumer) (safe .proof-of-reserves))
'''
        self.assertEqual(self.errors(consumer), [])

    def test_por_calls_exposes_call_site_context(self):
        source = """
(define-private (raw-read (por principal))
  (contract-call? por get-snapshot u1))
(define-read-only (consumer)
  (raw-read .proof-of-reserves))
"""
        calls = guard.por_calls(source)
        self.assertEqual([str(call) for call in calls], ["get-snapshot"])
        self.assertEqual(calls[0].call_name, "raw-read")
        self.assertEqual(calls[0].enclosing_function, "consumer")
        self.assertEqual(calls[0].line, 5)

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
