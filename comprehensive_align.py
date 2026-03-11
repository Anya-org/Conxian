import os
import re

# Terminology replacements
term_replacements = {
    r'deposit-funds': 'deposit-assets',
    r'withdraw-funds': 'withdraw-assets',
    r'check-clean-hands-compliance': 'verify-sanctions-compliance',
    r'ERR_NON_COMPLIANT': 'E_COMPLIANCE_NON_VALID',
    r'ERR_UNAUTHORIZED': 'E_AUTH_UNAUTHORIZED',
    r'ERR_PAUSED': 'E_SETTLEMENT_PAUSED',
    r'ERR_INSUFFICIENT_BALANCE': 'E_LIQUIDITY_INSUFFICIENT',
    r'ERR_COMPLIANCE_FAILED': 'E_COMPLIANCE_FAILED',
}

# API Route replacements
# Order matters: more specific first
route_replacements = [
    (r'/v1/verify-state', '/api/v1/state/verify'),
    (r'/v1/verify-integrity', '/api/v1/compliance/verify-integrity'),
    (r'/v1/verify', '/api/v1/compliance/attest'),
    (r'/v1/status', '/api/v1/state/status'),
    (r'/v1/proof', '/api/v1/state/proof'),
    (r'/v1/execute', '/api/v1/transaction/execute'),
    (r'/v1/metrics', '/api/v1/system/metrics'),
    (r'/v1/services', '/api/v1/system/services'),
    (r'/v1/billing', '/api/v1/transaction/billing'),
]

# We need to avoid double prefixing if /api/v1 is already there in some files
# or if we are editing the Rust code that defines the routes (where /api/v1 is nested)

def align_content(content, filepath):
    new_content = content

    # Apply terminology
    for old, new in term_replacements.items():
        new_content = re.sub(old, new, new_content)

    # Apply routes
    for old, new in route_replacements:
        # Avoid matching if it's already the new one or contains the new part
        # This is tricky. Let's use negative lookahead/lookbehind if possible or just careful replacement.

        # If it's a Rust file in conxian-gateway/internal/api/src/routes.rs or handlers.rs,
        # we might have already updated it or it might use relative paths.

        # For simplicity, let's just do a string replace but check for double /api/api
        new_content = new_content.replace(old, new)

    # Fix double paths
    new_content = new_content.replace('/api/api/', '/api/')
    new_content = new_content.replace('/v1/api/v1/', '/api/v1/')

    return new_content

extensions = ('.md', '.clar', '.rs', '.ts', '.tsx', '.yaml', '.yml', '.sh', '.sql', 'AGENTS.md')

for root, dirs, files in os.walk('.'):
    if 'node_modules' in dirs:
        dirs.remove('node_modules')
    if '.git' in dirs:
        dirs.remove('.git')
    for file in files:
        if file.endswith(extensions) or file == 'AGENTS.md':
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()

                new_content = align_content(content, filepath)

                if new_content != content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Aligned {filepath}")
            except Exception as e:
                print(f"Skipping {filepath}: {e}")
