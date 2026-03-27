import os

TARGET = "'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'"
REPLACEMENT = "(contract-call? .conxian-access get-contract-owner)"

def fix_file(path):
    with open(path, 'r') as f:
        content = f.read()

    if TARGET in content:
        # Only replace in lines that are NOT define-data-var or define-constant
        lines = content.split('\n')
        new_lines = []
        changed = False
        for line in lines:
            if TARGET in line and 'define-data-var' not in line and 'define-constant' not in line:
                print(f"Replacing in {path}: {line.strip()}")
                new_lines.append(line.replace(TARGET, REPLACEMENT))
                changed = True
            else:
                new_lines.append(line)

        if changed:
            with open(path, 'w') as f:
                f.write('\n'.join(new_lines))

for root, dirs, files in os.walk('Conxian/contracts'):
    for file in files:
        if file.endswith('.clar'):
            fix_file(os.path.join(root, file))
