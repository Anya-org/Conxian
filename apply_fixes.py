import os
import re

def fix(path, pattern, replacement):
    if not os.path.exists(path): return
    with open(path, 'r') as f: content = f.read()
    new_content = re.sub(pattern, replacement, content)
    if new_content != content:
        with open(path, 'w') as f: f.write(new_content)
        print(f"Fixed {path}")

# Regex to match the compliance check call
# We wrap it in unwrap-panic to convert (response bool uint) -> bool
# This is the standard in the codebase for inter-contract calls in simulation.
compliance_pattern = r'\(contract-call\?\s+\.regulatory-adapter\s+check-clean-hands-compliance\s+([^)]+)\)'
compliance_replacement = r'(unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance \1))'

targets = [
    "contracts/bonding/bond-factory.clar",
    "contracts/dex/route-manager.clar",
    "contracts/vaults/sbtc-vault.clar",
    "contracts/governance/community-governance-token.clar",
    "contracts/governance/community-dao.clar",
    "contracts/governance/ico-offering.clar",
    "contracts/governance/community-voting-engine.clar",
    "contracts/tokens/cxvg-token.clar",
    "contracts/tokens/token-system-coordinator.clar",
    "contracts/dex/liquidity-manager.clar",
    "contracts/core/conxian-paas-factory.clar",
    "contracts/yield/cxd-staking.clar",
    "contracts/treasury/opex-vault.clar",
    "contracts/bonding/cxd-bonding-curve-amm.clar",
    "contracts/governance/governance-handover.clar"
]

for t in targets:
    fix(t, compliance_pattern, compliance_replacement)
    # Also fix get-contract-owner
    fix(t, r'\(contract-call\?\s+\.regulatory-adapter\s+get-contract-owner\)', r'(unwrap-panic \g<0>)')
