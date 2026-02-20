import toml
import os

with open('Clarinet.toml', 'r') as f:
    config = toml.load(f)

with open('Clarinet.complete.toml', 'r') as f:
    complete_config = toml.load(f)

for contract_name, contract_info in complete_config.get('contracts', {}).items():
    if contract_name not in config['contracts']:
        path = contract_info.get('path', '')
        if os.path.exists(path):
            print(f"Adding {contract_name} at {path}")
            config['contracts'][contract_name] = contract_info

with open('Clarinet.toml', 'w') as f:
    toml.dump(config, f)
