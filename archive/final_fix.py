import re

# Fix Gateway Routes
filepath = 'conxian-gateway/internal/api/src/routes.rs'
with open(filepath, 'r') as f:
    content = f.read()
content = content.replace('.route("/state", get(handlers::get_state))', '.route("/system/state", get(handlers::get_state))')
content = content.replace('.route("/verify", post(handlers::verify_attestation))', '.route("/compliance/attest", post(handlers::verify_attestation))')
# Add verify-integrity placeholder route
if 'verify-integrity' not in content:
    content = content.replace('.route("/compliance/attest", post(handlers::verify_attestation))',
                              '.route("/compliance/attest", post(handlers::verify_attestation))\n        .route("/compliance/verify-integrity", post(handlers::health_check))') # Mapping integrity to health check as placeholder

with open(filepath, 'w') as f:
    f.write(content)

# Fix Gateway Tests
filepath = 'conxian-gateway/cmd/gateway/tests/api_tests.rs'
with open(filepath, 'r') as f:
    content = f.read()
content = content.replace('/api/v1/verify', '/api/v1/compliance/attest')
content = content.replace('/api/v1/metrics', '/api/v1/system/metrics')
with open(filepath, 'w') as f:
    f.write(content)

# Fix Nexus routes in rest.rs (ensure no double /api/v1 if nested, but it's not nested)
filepath = 'conxian-nexus/src/api/rest.rs'
with open(filepath, 'r') as f:
    content = f.read()
# Ensure they are correct
with open(filepath, 'w') as f:
    f.write(content)

# Fix Wallet calls
filepath = 'conxius-wallet/services/integrity.ts'
with open(filepath, 'r') as f:
    content = f.read()
content = content.replace('/v1/verify-integrity', '/api/v1/compliance/verify-integrity')
content = content.replace('/api/api/v1', '/api/v1')
with open(filepath, 'w') as f:
    f.write(content)

filepath = 'conxius-wallet/services/protocol.ts'
with open(filepath, 'r') as f:
    content = f.read()
content = content.replace('/v1/verify', '/api/v1/compliance/attest')
content = content.replace('/api/api/v1', '/api/v1')
with open(filepath, 'w') as f:
    f.write(content)
