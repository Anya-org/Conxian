import json
import re
from pathlib import Path

def get_contract_files():
    """Finds all .clar files in the contracts directory."""
    return list(Path("contracts").rglob("*.clar"))

def get_dependencies(contract_path: Path):
    """Parses a contract file to find all its dependencies."""
    try:
        content = contract_path.read_text(encoding='utf-8')
    except Exception as e:
        print(f"Warning: Could not read {contract_path}: {e}")
        return []

    # Strip comments to avoid parsing commented-out code
    content = re.sub(r";.*$", "", content, flags=re.MULTILINE)

    dependencies = set()

    # Regex to find dependencies of the form: .contract-alias or .contract-alias.trait-name
    # This covers `use-trait`, `impl-trait`, and `contract-call?`
    # It captures the alias, which is the part after the dot and before the next dot, space, or parenthesis.
    dependency_re = re.compile(r"\s+\.([a-zA-Z0-9_-]+)")

    for match in dependency_re.finditer(content):
        dependencies.add(match.group(1))

    return list(dependencies)

def build_dependency_graph():
    """Builds and saves the contract dependency graph."""
    print("--- Building Contract Dependency Graph ---")
    graph = {}
    contract_files = get_contract_files()

    if not contract_files:
        print("Error: No contract files found in 'contracts' directory.")
        return

    print(f"Found {len(contract_files)} contract files to analyze.")

    for contract_file in contract_files:
        contract_name = contract_file.stem
        # The contract name itself should not be in its dependency list
        dependencies = [dep for dep in get_dependencies(contract_file) if dep != contract_name]
        graph[contract_name] = dependencies

    try:
        with open('dependency-graph.json', 'w', encoding='utf-8') as f:
            json.dump(graph, f, indent=2)
        print("Successfully built and saved dependency-graph.json")
    except Exception as e:
        print(f"Error saving dependency graph: {e}")

    print("--- Dependency Graph Build Complete ---")

if __name__ == "__main__":
    build_dependency_graph()
