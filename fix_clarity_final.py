import os
import re

TARGET_PRINCIPAL = "'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'"
DYNAMIC_OWNER = "(contract-call? .conxian-access get-contract-owner)"

def process_file(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()

    changed = False
    new_lines = []
    for line in lines:
        # If it's a data-var or constant definition, we keep it literal but maybe change the value to a dummy
        if 'define-data-var' in line or 'define-constant' in line:
            if TARGET_PRINCIPAL in line:
                # Replace with tx-sender or a placeholder principal for init
                # tx-sender is allowed in define-data-var in some contexts but usually literals are safer.
                # Let's use the same principal but add a comment or just use a generic one if we're moving to dynamic.
                # Actually, let's just keep the literal for init but replace in logic.
                new_lines.append(line)
            else:
                new_lines.append(line)
        else:
            if TARGET_PRINCIPAL in line:
                print(f"Replacing literal in logic: {filepath}")
                new_line = line.replace(TARGET_PRINCIPAL, DYNAMIC_OWNER)
                new_lines.append(new_line)
                changed = True
            else:
                new_lines.append(line)

    if changed:
        with open(filepath, 'w') as f:
            f.writelines(new_lines)

for root, dirs, files in os.walk('Conxian/contracts'):
    for file in files:
        if file.endswith('.clar'):
            process_file(os.path.join(root, file))
