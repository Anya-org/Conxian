from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
VERIFIER_PATH = REPO_ROOT / "scripts" / "verify_codeowners_policy.py"
SPEC = importlib.util.spec_from_file_location("verify_codeowners_policy", VERIFIER_PATH)
assert SPEC is not None and SPEC.loader is not None
verifier = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verifier
SPEC.loader.exec_module(verifier)


VALID_CODEOWNERS = """\
# Root authority
* @botshelomokoka @admin-conxian-labs
/.github/ @botshelomokoka @admin-conxian-labs
/CODEOWNERS @botshelomokoka @admin-conxian-labs
/contracts/ @botshelomokoka @admin-conxian-labs
/scripts/ @botshelomokoka @admin-conxian-labs
/deployments/ @botshelomokoka @admin-conxian-labs
/docs/ @botshelomokoka @admin-conxian-labs
"""


class CodeownersPolicyTests(unittest.TestCase):
    def write_codeowners(
        self, root: Path, content: str = VALID_CODEOWNERS, location: str = "CODEOWNERS"
    ) -> None:
        path = root / location
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def test_accepts_valid_root_policy(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_codeowners(root)
            self.assertEqual(verifier.verify_policy(root), [])

    def test_rejects_duplicate_supported_location(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_codeowners(root)
            self.write_codeowners(root, location=".github/CODEOWNERS")
            self.assertEqual(
                verifier.verify_policy(root),
                [
                    "exactly root CODEOWNERS must exist in GitHub-supported locations; "
                    "found: .github/CODEOWNERS, CODEOWNERS"
                ],
            )

    def test_rejects_missing_codeowners_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(
                verifier.verify_policy(Path(directory)),
                [
                    "exactly root CODEOWNERS must exist in GitHub-supported locations; "
                    "found: none"
                ],
            )

    def test_rejects_missing_required_global_owner(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_codeowners(
                root,
                VALID_CODEOWNERS.replace(
                    "* @botshelomokoka @admin-conxian-labs", "* @botshelomokoka", 1
                ),
            )
            self.assertEqual(
                verifier.verify_policy(root),
                ["global rule '*' is missing required owner @admin-conxian-labs"],
            )

    def test_rejects_missing_required_protected_path(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_codeowners(
                root,
                VALID_CODEOWNERS.replace(
                    "/deployments/ @botshelomokoka @admin-conxian-labs\n", ""
                ),
            )
            self.assertEqual(
                verifier.verify_policy(root),
                ["missing explicit CODEOWNERS rule for /deployments/"],
            )


if __name__ == "__main__":
    unittest.main()
