import re

def add_dependency(toml, contract, dep):
    pattern = r'(\[contracts\.' + re.escape(contract) + r'\][^\[]*?depends_on = \[)([^\]]*?)(\])'
    def replace(match):
        deps = match.group(2).strip()
        if dep in deps:
            return match.group(0)
        if deps:
            return match.group(1) + deps + ', "' + dep + '"' + match.group(3)
        else:
            return match.group(1) + '"' + dep + '"' + match.group(3)

    new_toml = re.sub(pattern, replace, toml, flags=re.DOTALL)
    if new_toml == toml:
        # Try adding depends_on if it doesn't exist
        pattern2 = r'(\[contracts\.' + re.escape(contract) + r'\][^\[]*?clarity-version = 4)'
        new_toml = re.sub(pattern2, r'\1\ndepends_on = ["' + dep + '"]', toml, flags=re.DOTALL)
    return new_toml

with open('Clarinet.toml', 'r') as f:
    content = f.read()

contracts_to_fix = [
    "conxian-access", "conxian-protocol", "ops-engine", "voting",
    "founder-vesting", "vault", "cxd-staking", "compliance-manager", "regulatory-adapter"
]

for contract in contracts_to_fix:
    content = add_dependency(content, contract, "block-utils")

# Fix agent-risk dependencies
content = add_dependency(content, "agent-risk", "cxd-token")
content = add_dependency(content, "agent-risk", "block-utils")

# Fix lending-manager dependencies (it uses block-utils too now)
content = add_dependency(content, "lending-manager", "block-utils")

with open('Clarinet.toml', 'w') as f:
    f.write(content)
