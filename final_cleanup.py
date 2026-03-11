import os
import re

replacements = {
    r'PppState': 'ExchangeRateState',
    r'ppp_indices': 'exchange_rates',
    r'ppp_tracker': 'oracle_service',
    r'ZkcVerifier': 'AttestationVerifier',
    r'Zkc': 'ComplianceAttestation',
    r'zkc': 'compliance',
    r'PPP': 'ExchangeRate',
}

def align_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        new_content = content
        for old, new in replacements.items():
            new_content = re.sub(r'\b' + old + r'\b', new, new_content)
            # Also catch lower case variations for file names/modules
            if old.lower() != old: # Only if it's not already lower case
                new_content = re.sub(r'\b' + old.lower() + r'\b', new.lower(), new_content)

        if new_content != content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Aligned {filepath}")
    except Exception as e:
        print(f"Error alignment in {filepath}: {e}")

# Target files that were found in previous grep
target_files = [
    'conxian-nexus/migrations/20240101000006_oracle_history.sql',
    'conxian-nexus/docs/enhancements_summary.md',
    'conxian-nexus/src/oracle/mod.rs',
    'conxian-nexus/src/oracle/oracle_service.rs',
    'conxian-nexus/src/oracle/ppp_tracker.rs',
    'conxian-gateway/internal/compliance/src/zkc.rs',
    'conxian-gateway/internal/compliance/src/compliance.rs',
    'conxian-gateway/internal/compliance/src/lib.rs'
]

for filepath in target_files:
    if os.path.exists(filepath):
        align_file(filepath)

# Targeted file renames if they still exist
renames = [
    ('conxian-nexus/src/oracle/ppp_tracker.rs', 'conxian-nexus/src/oracle/oracle_service.rs'),
    ('conxian-gateway/internal/compliance/src/zkc.rs', 'conxian-gateway/internal/compliance/src/compliance.rs')
]

for old, new in renames:
    if os.path.exists(old):
        if os.path.exists(new):
            # If new exists, maybe merge or just overwrite if it's a small file
            # In this case, I'll just overwrite to be sure
            os.remove(new)
        os.rename(old, new)
        print(f"Renamed {old} -> {new}")
