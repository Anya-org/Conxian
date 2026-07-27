from __future__ import annotations

import json
from pathlib import Path
import re
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
PROTOCOL_WORKFLOW = REPO_ROOT / ".github/workflows/protocol-ci.yml"
STABLE_CONTEXTS = [
    "protocol-merge-gate",
    "jules-audit",
    "gitleaks",
    "dependency-review",
]
CONTEXT_LIST_INTRO = (
    "The stable required check contexts intended for every pull request targeting "
    "`main` are exactly:"
)
CONDITIONAL_POLICY = (
    "`validate-protocol` is conditional and must not be configured as a universally "
    "required context. `protocol-merge-gate` is the stable aggregator"
)


def normalize_whitespace(source: str) -> str:
    return " ".join(source.split())


def extract_job(workflow: str, job_name: str) -> str:
    match = re.search(
        rf"(?ms)^  {re.escape(job_name)}:\n(?P<body>(?:^(?:    |\s*$).*\n?)*)",
        workflow,
    )
    if match is None:
        raise AssertionError(f"missing workflow job: {job_name}")
    return match.group("body")


def extract_markdown_contexts(source: str) -> list[str]:
    normalized = normalize_whitespace(CONTEXT_LIST_INTRO)
    lines = source.splitlines()
    for start in range(len(lines)):
        for end in range(start + 1, min(len(lines), start + 4) + 1):
            if normalize_whitespace("\n".join(lines[start:end])) != normalized:
                continue
            contexts: list[str] = []
            for line in lines[end:]:
                if not line.strip():
                    if contexts:
                        return contexts
                    continue
                item = re.fullmatch(r"- `([a-z0-9-]+)`", line)
                if item is None:
                    break
                contexts.append(item.group(1))
            break
    raise AssertionError("missing designated stable required-context list")


class MainBranchGovernancePolicyTests(unittest.TestCase):
    def test_protocol_workflow_has_stable_aggregator_and_conditional_validation(self) -> None:
        workflow = PROTOCOL_WORKFLOW.read_text(encoding="utf-8")
        self.assertRegex(
            workflow,
            r"(?m)^  pull_request:\n    branches:\n      - main$",
        )

        validation = extract_job(workflow, "validate-protocol")
        self.assertIn("needs: changes", validation)
        self.assertIn(
            "if: ${{ needs.changes.outputs.any_protocol == 'true' || "
            "github.event_name == 'push' }}",
            validation,
        )

        merge_gate = extract_job(workflow, "protocol-merge-gate")
        self.assertRegex(merge_gate, r"(?m)^    name: protocol-merge-gate$")
        self.assertIn("      - changes", merge_gate)
        self.assertIn("      - validate-protocol", merge_gate)
        self.assertIn(
            "if: ${{ always() && github.event_name == 'pull_request' }}",
            merge_gate,
        )
        self.assertIn(
            "VALIDATION_RESULT: ${{ needs.validate-protocol.result }}", merge_gate
        )
        self.assertIn('if [[ "$VALIDATION_RESULT" != "skipped" ]]', merge_gate)
        self.assertIn('if [[ "$VALIDATION_RESULT" != "success" ]]', merge_gate)

    def test_markdown_governance_docs_name_only_stable_contexts(self) -> None:
        for relative_path in (
            "CONTRIBUTING.md",
            "docs/MAIN_BRANCH_GOVERNANCE.md",
        ):
            with self.subTest(path=relative_path):
                source = (REPO_ROOT / relative_path).read_text(encoding="utf-8")
                self.assertEqual(extract_markdown_contexts(source), STABLE_CONTEXTS)
                self.assertIn(
                    normalize_whitespace(CONDITIONAL_POLICY),
                    normalize_whitespace(source),
                )

    def test_documentation_state_records_stable_and_conditional_contexts(self) -> None:
        source = (REPO_ROOT / "docs/DOCUMENTATION_STATE.md").read_text(
            encoding="utf-8"
        )
        # Find the JSON block that contains "implementation"
        idx = 0
        while True:
            try:
                idx = source.index("{", idx)
            except ValueError:
                raise AssertionError("Could not find required implementation JSON block in DOCUMENTATION_STATE.md")
            try:
                session, _ = json.JSONDecoder().raw_decode(source[idx:])
                if "implementation" in session:
                    break
            except ValueError:
                pass
            idx += 1

        implementation = session["implementation"]
        self.assertEqual(implementation["intended_required_checks"], STABLE_CONTEXTS)
        self.assertEqual(
            normalize_whitespace(implementation["conditional_validation"]),
            normalize_whitespace(
                "validate-protocol is conditional and must not be configured as a "
                "universally required context; protocol-merge-gate is the stable "
                "aggregator emitted for every pull request targeting main."
            ),
        )


if __name__ == "__main__":
    unittest.main()
