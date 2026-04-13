import os
import re
import sys

# Constants
CONTAMINATION_PATTERN = r'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
# Added 'ui' to EXCLUDE_DIRS as front-end configuration often requires devnet principals
EXCLUDE_DIRS = {'.git', 'node_modules', 'tests', 'settings', 'deployments', 'audit', 'ui'}
EXCLUDE_FILES = {'Clarinet.toml', 'Clarinet.complete.toml', 'package-lock.json', 'verify_contamination_guard.py', 'global_principal_remediator.py'}

def verify_contamination():
    failures = []
    for root, dirs, files in os.walk('.'):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for file in files:
            if file in EXCLUDE_FILES or file.endswith('.test.ts') or file.endswith('.spec.ts'):
                continue

            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    matches = re.findall(CONTAMINATION_PATTERN, content)
                    if matches:
                        failures.append((path, matches))
            except Exception as e:
                # Skip binary files or unreadable files
                pass

    if failures:
        print(f"CRITICAL: Found {len(failures)} files with testnet contamination:")
        for path, matches in failures:
            print(f"  {path}: {list(set(matches))}")
        return False

    print("SUCCESS: No testnet contamination found in core paths.")
    return True

if __name__ == "__main__":
    if not verify_contamination():
        sys.exit(1)
    sys.exit(0)
