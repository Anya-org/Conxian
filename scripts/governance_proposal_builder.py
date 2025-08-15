#!/usr/bin/env python3
"""Governance proposal builder

Takes ML strategy recommender outputs (JSON lines or a single JSON file)
and converts them into structured governance proposal drafts that can be
fed into on-chain governance (e.g., DAO timelock + proposal contract).

This is a scaffold; adapt field names to match the actual DAO proposal
contract interface (e.g., function names, parameters, execution delay).
"""
from __future__ import annotations
import argparse, json, sys, uuid, datetime as dt, typing as t, pathlib

DEFAULT_TEMPLATE = {
    "title": "<autonomics-adjustment>",
    "description": "Proposed parameter adjustments based on ML + simulation insights.",
    "actions": [
        # Each action: {"contract": "SP...vault", "function": "set-fee", "args": ["u100"], "comment": "Raise base fee"}
    ],
    "metadata": {
        "source": "ml_strategy_recommender",
        "generated_at": None,
        "confidence": None,
        "simulated_net_benefit": None
    }
}


def load_recommendations(path: pathlib.Path) -> t.List[dict]:
    txt = path.read_text().strip()
    if not txt:
        return []
    try:
        data = json.loads(txt)
        if isinstance(data, list):
            return data
        return [data]
    except json.JSONDecodeError:
        # Try JSON lines
        recs: t.List[dict] = []
        for line in txt.splitlines():
            line = line.strip()
            if not line:
                continue
            recs.append(json.loads(line))
        return recs


def build_proposal(rec: dict) -> dict:
    proposal = json.loads(json.dumps(DEFAULT_TEMPLATE))  # deep copy
    proposal["title"] = rec.get("title") or f"Autonomics Adj {uuid.uuid4().hex[:6]}"
    proposal["metadata"]["generated_at"] = dt.datetime.utcnow().isoformat() + "Z"
    for k in ["confidence", "simulated_net_benefit"]:
        if k in rec:
            proposal["metadata"][k] = rec[k]
    # Derive actions from recognized recommendation keys
    actions = []
    if "target_fee_bps" in rec:
        actions.append({
            "contract": rec.get("vault_contract", "SPXXXX.vault"),
            "function": "set-fee-bps",
            "args": [f"u{int(rec['target_fee_bps'])}"],
            "comment": "Adjust trading fee"
        })
    if "new_lower_band" in rec and "new_upper_band" in rec:
        actions.append({
            "contract": rec.get("vault_contract", "SPXXXX.vault"),
            "function": "set-reserve-bands",
            "args": [f"u{int(rec['new_lower_band'])}", f"u{int(rec['new_upper_band'])}"],
            "comment": "Update reserve ratio bands"
        })
    if not actions:
        actions.append({
            "contract": rec.get("vault_contract", "SPXXXX.vault"),
            "function": "noop",
            "args": [],
            "comment": "No actionable fields detected"
        })
    proposal["actions"] = actions
    return proposal


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("input", help="Path to recommendations JSON / JSONL")
    ap.add_argument("-o", "--output", help="Output file (default stdout)")
    ap.add_argument("--bundle", action="store_true", help="Emit a bundle (array) instead of JSON lines")
    args = ap.parse_args(argv)

    path = pathlib.Path(args.input)
    recs = load_recommendations(path)
    proposals = [build_proposal(r) for r in recs]

    if args.bundle:
        out_text = json.dumps(proposals, indent=2)
    else:
        out_text = "\n".join(json.dumps(p) for p in proposals)

    if args.output:
        pathlib.Path(args.output).write_text(out_text + "\n")
    else:
        sys.stdout.write(out_text + "\n")

if __name__ == "__main__":
    main()
