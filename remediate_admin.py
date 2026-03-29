import os
import re

def replace_hardcoded_admin(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Regex to find `(define-data-var <name> principal tx-sender)`
    pattern = r'\(define-data-var\s+([a-zA-Z0-9_-]+)\s+principal\s+tx-sender\)'
    
    if not re.search(pattern, content):
        return False

    new_content = re.sub(pattern, r"(define-data-var \1 principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)", content)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    return True

if __name__ == "__main__":
    count = 0
    for root, _, files in os.walk('Conxian/contracts'):
        for file in files:
            if file.endswith('.clar'):
                file_path = os.path.join(root, file)
                if replace_hardcoded_admin(file_path):
                    count += 1
                    print(f"Updated {file_path}")
    print(f"Total files updated: {count}")
