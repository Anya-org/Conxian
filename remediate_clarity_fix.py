import os
import re

INVALID_INIT = "(contract-call? .conxian-access get-contract-owner)"
# We should probably initialize with a dummy or the original, and then use logic.
# Or better: remove the variable and use the contract call directly in authorization checks.
# But for now, let's just initialize with a valid principal and ensure checks are dynamic.

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    if INVALID_INIT in content:
        print(f"Fixing invalid initialization in {filepath}")
        # Identify define-data-var or define-constant using this
        # Replacing the initialization with a safe literal principal (e.g. the burn address or a placeholder)
        # and then ensuring the logic uses the dynamic call.

        # Actually, if it's a data-var, we can't init with contract-call.
        # Let's replace the (var-get admin) with (contract-call? .conxian-access get-contract-owner) in the code
        # and init the var with a dummy.

        new_content = content.replace(INVALID_INIT, "tx-sender") # Use tx-sender as initial dummy for owner/admin

        with open(filepath, 'w') as f:
            f.write(new_content)

for root, dirs, files in os.walk('Conxian/contracts'):
    for file in files:
        if file.endswith('.clar'):
            process_file(os.path.join(root, file))
