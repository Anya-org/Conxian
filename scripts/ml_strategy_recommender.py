#!/usr/bin/env python3
"""Placeholder ML strategy recommender.

Outputs a JSON payload representing a governance proposal suggestion based on
simple heuristics (future: plug in ML model / RL agent).

Current heuristics:
- If utilization > 85% -> recommend raise global cap by 10%.
- If reserve ratio < reserve_low target -> increase deposit fee by 5 bps.
- If reserve ratio > reserve_high target -> decrease deposit fee by 5 bps.
Produces a proposal object with target function and parameters.
"""
import json, argparse, sys, math

DEFAULTS = {
  'util_high_bps': 8500,
  'reserve_low_bps': 500,
  'reserve_high_bps': 1500,
  'deposit_fee_step': 5
}

from typing import Any, Dict, List

def recommend(state: Dict[str, Any]) -> List[Dict[str, Any]]:
  util: int = int(state['utilization_bps'])
  reserve: int = int(state['reserve_ratio_bps'])
  recs: List[Dict[str, Any]] = []
    # Cap recommendation
    if util > DEFAULTS['util_high_bps']:
        new_cap = math.ceil(state['global_cap'] * 1.10)
  recs.append({
          'type': 'PARAM_CHANGE',
          'title': 'Increase Global Cap by 10%',
            'target': 'vault',
            'function': 'set-global-cap',
            'params': [new_cap],
            'rationale': f'Utilization {util/100:.2f}% > 85% threshold'
        })
    # Deposit fee adjustments
    if reserve < DEFAULTS['reserve_low_bps']:
        recs.append({
          'type': 'PARAM_CHANGE',
          'title': 'Increase Deposit Fee (Reserve Low)',
          'target': 'vault',
          'function': 'set-fees-partial',
          'params': {'delta_deposit_fee_bps': DEFAULTS['deposit_fee_step'], 'direction': 'up'},
          'rationale': f"Reserve ratio {reserve/100:.2f}% below {DEFAULTS['reserve_low_bps']/100:.2f}%"
        })
    elif reserve > DEFAULTS['reserve_high_bps']:
        recs.append({
          'type': 'PARAM_CHANGE',
          'title': 'Decrease Deposit Fee (Reserve High)',
          'target': 'vault',
          'function': 'set-fees-partial',
          'params': {'delta_deposit_fee_bps': DEFAULTS['deposit_fee_step'], 'direction': 'down'},
          'rationale': f"Reserve ratio {reserve/100:.2f}% above {DEFAULTS['reserve_high_bps']/100:.2f}%"
        })
    return recs

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--state-json', help='Inline JSON with current protocol state', required=True)
    args = ap.parse_args()
    state = json.loads(args.state_json)
  recs = recommend(state)
    print(json.dumps({'recommendations': recs}, indent=2))

if __name__ == '__main__':
    main()
