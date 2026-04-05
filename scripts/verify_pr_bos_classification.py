#!/usr/bin/env python3
from __future__ import annotations

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


BOS_CLASSIFICATION_HEADER_RE = re.compile(
    r"^[ ]{0,3}#{1,6}\s*bos change classification\b.*$",
    re.IGNORECASE,
)
HEADING_RE = re.compile(r"^[ ]{0,3}#{1,6}\s*\S")


def normalize_label(label: str) -> str:
    return " ".join(label.lower().split())


CLASSIFICATION_LABELS_BY_NORMALIZED = {
    normalize_label(label): label for label in CLASSIFICATION_LABELS
}


def extract_bos_classification_section(body: str) -> str:
    lines = body.splitlines()

    start = None
    for i, line in enumerate(lines):
        if BOS_CLASSIFICATION_HEADER_RE.match(line):
            start = i + 1
            break

    if start is None:
        return ""

    end = next(
        (j for j in range(start, len(lines)) if HEADING_RE.match(lines[j])),
        len(lines),
    )
    return "\n".join(lines[start:end])


def main() -> int:
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path:
        print("GITHUB_EVENT_PATH not set; cannot validate PR classification")
        return 1

    with open(event_path, "r", encoding="utf-8") as f:
        event = json.load(f)

    pr = event.get("pull_request")
    if not pr:
        print("No pull_request payload found; nothing to validate")
        return 0

    pr_author = ((pr.get("user") or {}).get("login") or "").strip()
    if pr_author == "dependabot[bot]":
        print("Skipping BOS PR classification for dependabot")
        return 0

    body = pr.get("body") or ""

    section = extract_bos_classification_section(body)
    if not section.strip():
        print("BOS PR classification section not found.")
        print("Add a heading like '### BOS change classification' and check exactly one box.")
        return 1

    selected: list[str] = []
    checkbox_re = re.compile(r"^\s*[-*]\s*\[[xX]\]\s*(.+?)\s*$")
    for line in section.splitlines():
        match = checkbox_re.match(line)
        if not match:
            continue
        raw_label = match.group(1).strip()
        raw_label = re.split(r"\s*<!--", raw_label, 1)[0]
        canonical = CLASSIFICATION_LABELS_BY_NORMALIZED.get(normalize_label(raw_label))
        if canonical is not None:
            selected.append(canonical)

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
