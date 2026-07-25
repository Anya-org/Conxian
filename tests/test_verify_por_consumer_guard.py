import importlib.util
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/verify_por_consumer_guard.py"
SPEC = importlib.util.spec_from_file_location("verify_por_consumer_guard", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class ProofOfReservesConsumerGuardTests(unittest.TestCase):
    def test_allows_direct_fail_closed_status_calls(self):
        source = """
        (contract-call? .proof-of-reserves is-fully-backed token)
        (contract-call? .proof-of-reserves get-proof-status token)
        """
        self.assertEqual(MODULE.scan_clarity_text(source, "contracts/treasury/gate.clar"), [])

    def test_rejects_direct_diagnostic_candidate_authority(self):
        violations = MODULE.scan_clarity_text(
            "(contract-call? .proof-of-reserves get-accepted-reserve asset)",
            "contracts/settlement/bad.clar",
        )
        self.assertTrue(any("get-accepted-reserve" in item for item in violations))

    def test_rejects_alias_bypass(self):
        source = "(define-constant por .proof-of-reserves) (contract-call? por get-snapshot-candidate asset digest)"
        violations = MODULE.scan_clarity_text(source, "contracts/compliance/bad.clar")
        self.assertTrue(any("get-snapshot-candidate" in item for item in violations))

    def test_rejects_chained_alias_binding(self):
        source = """
        (define-constant canonical-por .proof-of-reserves)
        (define-constant por canonical-por)
        (contract-call? por get-attestation asset digest signer)
        """
        violations = MODULE.scan_clarity_text(source, "contracts/compliance/chained.clar")
        self.assertTrue(any("get-attestation" in item for item in violations))

    def test_allows_diagnostic_symbols_in_comments_and_strings(self):
        source = '''
        ;; get-accepted-reserve must never become authority here.
        (print "diagnostic: get-snapshot-candidate raw-attestation")
        (contract-call? .proof-of-reserves get-proof-status token)
        '''
        self.assertEqual(MODULE.scan_clarity_text(source, "contracts/treasury/safe.clar"), [])

    def test_ignores_commented_or_stringified_unsafe_calls(self):
        source = '''
        ;; (contract-call? .proof-of-reserves get-accepted-reserve token)
        (print "(contract-call? .proof-of-reserves get-attestation token digest signer)")
        '''
        self.assertEqual(MODULE.scan_clarity_text(source, "contracts/treasury/safe.clar"), [])

    def test_rejects_fully_qualified_raw_attestation_call(self):
        source = "(contract-call? 'SP000000000000000000002Q6VF78.proof-of-reserves submit-attestation token u1)"
        violations = MODULE.scan_clarity_text(source, "contracts/routing/bad.clar")
        self.assertTrue(any("submit-attestation" in item for item in violations))

    def test_allows_script_inventory_but_rejects_candidate_state(self):
        allowed = "release inventory includes contracts/security/proof-of-reserves.clar"
        rejected = "proof-of-reserves readiness reads get-accepted-reserve candidate-state"
        self.assertEqual(MODULE.scan_script_text(allowed, "scripts/release_inventory.py"), [])
        self.assertEqual(MODULE.scan_script_text(rejected, "scripts/mainnet_readiness.py"), [])

    def test_rejects_recognized_operational_script_invocations(self):
        configured = 'method = "get-accepted-reserve" # proof-of-reserves'
        sdk_call = "callReadOnlyFn('proof-of-reserves', 'get-snapshot-candidate', args)"
        self.assertTrue(MODULE.scan_script_text(configured, "scripts/mainnet_readiness.py"))
        self.assertTrue(MODULE.scan_script_text(sdk_call, "scripts/reserve_check.ts"))


if __name__ == "__main__":
    unittest.main()
