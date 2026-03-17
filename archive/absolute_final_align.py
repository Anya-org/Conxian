import os
import re

replacements = {
    r'test_zkc_verify': 'test_compliance_verify',
    r'ppp_json': 'exchange_rates_json',
}

def align_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    new_content = content
    for old, new in replacements.items():
        new_content = re.sub(old, new, new_content)
    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Aligned {filepath}")

align_file('conxian-gateway/internal/compliance/src/compliance.rs')
align_file('conxian-nexus/src/oracle/mod.rs')
