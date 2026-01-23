import toml
from collections import OrderedDict

def get_contracts_from_toml(toml_path):
    try:
        with open(toml_path, 'r', encoding='utf-8') as f:
            data = toml.load(f)
    except FileNotFoundError:
        return {}, {}

    active_contracts = data.get("contracts", {})
    disabled_contracts = data.get("disabled", {})

    return active_contracts, disabled_contracts
