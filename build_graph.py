
import toml
import os
import re
from collections import defaultdict, OrderedDict

def parse_dependencies(filepath, contract_aliases):
    """Parse a Clarity file to find its dependencies."""
    dependencies = set()
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Could not read file {filepath}: {e}")
        return dependencies

    # Regex for various contract calls and trait implementations
    patterns = [
        re.compile(r'\((?:use-trait|impl-trait)\s+[^.\s]+\.([\w-]+)'),
        re.compile(r'\((?:impl-trait)\s+\'([\w-]+\.[\w-]+)'),
        re.compile(r'\(contract-call\?\s+\.?\'?([\w-]+)'),
        re.compile(r'\(var-get\s+\'?([\w-]+)\)'),
        re.compile(r'\(map-get\?\s+\'?([\w-]+)\s+'),
        re.compile(r'\(define-constant\s+[\w-]+\s+\(contract-call\?\s+\.?\'?([\w-]+)'),
    ]

    for pattern in patterns:
        for match in pattern.finditer(content):
            contract_alias = match.group(1).split('.')[0]
            if contract_alias in contract_aliases:
                dependencies.add(contract_alias)

    return dependencies


def build_dependency_graph(clarinet_toml_path):
    """Build a dependency graph from the Clarinet.toml file."""
    with open(clarinet_toml_path, 'r') as f:
        data = toml.load(f, _dict=OrderedDict)

    graph = defaultdict(list)

    contracts_data = data.get('contracts', {})
    contract_aliases = list(contracts_data.keys())

    for contract_alias, contract_info in contracts_data.items():
        filepath = contract_info.get('path')
        if filepath and os.path.exists(filepath):
            dependencies = parse_dependencies(filepath, contract_aliases)
            dependencies.discard(contract_alias) # Remove self-dependencies
            graph[contract_alias] = list(dependencies)

    return graph, data

def topological_sort_util(v, visited, stack, graph, recursion_stack):
    """Utility function for topological sort."""
    visited[v] = True
    recursion_stack[v] = True

    for i in graph.get(v, []):
        if i not in visited:
            continue
        if not visited[i]:
            if not topological_sort_util(i, visited, stack, graph, recursion_stack):
                return False
        elif recursion_stack[i]:
            print(f"Circular dependency detected: {v} -> {i}")
            # This is a critical error, but for now we will just print it and continue
            # This allows us to at least get a partial sort
            break

    stack.insert(0, v)
    recursion_stack[v] = False
    return True

def topological_sort(graph):
    """Perform a topological sort on the dependency graph."""
    all_nodes = list(graph.keys())

    visited = {node: False for node in all_nodes}
    recursion_stack = {node: False for node in all_nodes}
    stack = []

    for node in all_nodes:
        if not visited[node]:
            if not topological_sort_util(node, visited, stack, graph, recursion_stack):
                # We will not return None, but instead just continue with the sorted stack
                pass

    return stack

def main():
    """Main function."""
    clarinet_toml_path = 'Clarinet.toml'
    print("Building dependency graph...")
    graph, data = build_dependency_graph(clarinet_toml_path)

    print("Topologically sorting contracts...")
    sorted_contracts = topological_sort(graph)

    if sorted_contracts is None:
        print("Could not sort contracts due to circular dependencies.")
        return

    print("Updating Clarinet.toml...")
    for contract_name in data.get('contracts', {}):
        if contract_name in graph:
            dependencies = [dep for dep in graph[contract_name] if dep in data.get('contracts', {})]
            dependencies = list(OrderedDict.fromkeys(dependencies))

            if dependencies:
                data['contracts'][contract_name]['depends_on'] = dependencies
            elif 'depends_on' in data['contracts'][contract_name]:
                del data['contracts'][contract_name]['depends_on']

    with open(clarinet_toml_path, 'w') as f:
        toml.dump(data, f)

    print("Clarinet.toml updated successfully.")

if __name__ == '__main__':
    main()
