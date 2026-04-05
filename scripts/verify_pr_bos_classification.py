import json
import os
import re
import sys


CLASSIFICATION_LABELS = [
    "docs-only",
    "stub-isolation",
    "dev-only implementation",
    "production implementation",
]


def main() -> int:
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path:
        print("GITHUB_EVENT_PATH not set; cannot validate PR classification")
        return 1

    actor = (os.environ.get("GITHUB_ACTOR") or "").strip()
    if actor == "dependabot[bot]":
        print("Skipping BOS PR classification for dependabot")
        return 0

    with open(event_path, "r", encoding="utf-8") as f:
        event = json.load(f)

    pr = event.get("pull_request")
    if not pr:
        print("No pull_request payload found; nothing to validate")
        return 0

    body = pr.get("body") or ""

    selected: list[str] = []
    checkbox_re = re.compile(r"^\s*-\s*\[[xX]\]\s*(.+?)\s*$")
    for line in body.splitlines():
        match = checkbox_re.match(line)
        if not match:
            continue
        label = match.group(1).strip().lower()
        for expected in CLASSIFICATION_LABELS:
            if label == expected:
                selected.append(expected)
                break

    if len(selected) != 1:
        expected = ", ".join(CLASSIFICATION_LABELS)
        print("BOS PR classification is required.")
        print(f"Select exactly one of: {expected}")
        print(
            "Add a checked box to the PR description under the 'BOS change classification' section."
        )
        if selected:
            print(f"Found multiple classifications checked: {', '.join(selected)}")
        return 1

    print(f"BOS PR classification: OK ({selected[0]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
