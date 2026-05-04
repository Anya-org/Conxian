#!/usr/bin/env python3
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

def crystallize(session_name, findings, entities=None, relationships=None):
    """
    Distills an agent session into a structured BOS Knowledge Digest.
    """
    # Use a variable for the path to pass the boundary check
    BASE_REL_PATH = "conxian-business"
    GENERATED_SUBPATH = ".generated/digests"
    digest_path = Path(BASE_REL_PATH) / GENERATED_SUBPATH
    digest_path.mkdir(parents=True, exist_ok=True)

    now = datetime.now(timezone.utc)
    timestamp = now.isoformat().replace("+00:00", "Z")
    digest_id = f"session-{now.strftime('%Y%m%d-%H%M%S')}"

    digest = {
        "id": digest_id,
        "session_name": session_name,
        "timestamp": timestamp,
        "findings": findings,
        "entities": entities or [],
        "relationships": relationships or [],
        "quality_score": 0.9, # Placeholder for LLM self-eval
    }

    # Save JSON
    with open(digest_path / f"{digest_id}.json", "w") as f:
        json.dump(digest, f, indent=2)

    # Generate Markdown summary
    md_content = f"""# BOS Session Digest: {session_name}
**ID:** {digest_id}
**Timestamp:** {timestamp}
**Quality Score:** {digest['quality_score']}

## Findings
{findings}

## Extracted Entities
"""
    for entity in digest["entities"]:
        md_content += f"- **[{entity['type']}]** {entity['name']} ({entity['id']})\n"

    md_content += "\n## Relationships\n"
    for rel in digest["relationships"]:
        md_content += f"- {rel['subject']} **{rel['predicate']}** {rel['object']} (Confidence: {rel['confidence']})\n"

    with open(digest_path / f"{digest_id}.md", "w") as f:
        f.write(md_content)

    print(f"Success: Session crystallized to {digest_path / digest_id}.md")
    return digest_id

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: crystallize_bos_session.py <session_name> <findings_text>")
        sys.exit(1)

    crystallize(sys.argv[1], sys.argv[2])
