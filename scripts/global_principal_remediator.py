import os
import re

# Patterns for hardcoded principals in Clarity
# Matches 'ST... or 'SP...
PRINCIPAL_PATTERN = r"'(ST|SP)[A-Z0-9]{38,}"

def remediate_clarity_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Replace hardcoded principals with tx-sender
    new_content = re.sub(PRINCIPAL_PATTERN, "tx-sender", content)

    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Remediated: {filepath}")
        return True
    return False

def main():
    # Process both contracts and ui directories
    for start_dir in ['contracts', 'ui', 'docs']:
        if not os.path.exists(start_dir):
            continue
        for root, dirs, files in os.walk(start_dir):
            for file in files:
                if file.endswith('.clar') or file.endswith('.md') or file.endswith('.ts') or file.endswith('.tsx'):
                    # For non-clarity files, we might need a different pattern or just literal replace
                    if file.endswith('.clar'):
                        remediate_clarity_file(os.path.join(root, file))
                    else:
                        # For docs and UI, replace the specific testnet addresses with the verified one
                        # as a proxy for "environment agnostic" or just use the verified testnet one
                        with open(os.path.join(root, file), 'r') as f:
                            c = f.read()
                        nc = c.replace('ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM', 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P')
                        if nc != c:
                            with open(os.path.join(root, file), 'w') as f:
                                f.write(nc)
                            print(f"Remediated (literal): {os.path.join(root, file)}")

if __name__ == "__main__":
    main()
