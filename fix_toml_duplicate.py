import re

with open('Clarinet.toml', 'r') as f:
    content = f.read()

# Find the first [project] block and the second one
# We want to keep the first one and remove the second one's header if it exists

# Actually, the old one was likely at the beginning but I prepended a new one.
# So now I have two [project] sections.

# I'll just keep the first one and remove any subsequent [project] headers and their immediate fields until the next table.
parts = content.split('[project]')
if len(parts) > 2:
    # Keep everything before the first [project] (usually empty)
    # Plus the first [project] block content
    # Plus everything after the last [project] block's next table

    first_project_block = parts[1]
    last_parts = parts[2:]

    # In each subsequent part, find the first '[' which starts the next table
    cleaned_last_parts = []
    for p in last_parts:
        next_table_start = p.find('[')
        if next_table_start != -1:
            cleaned_last_parts.append(p[next_table_start:])
        else:
            # If no other table, just discard (it was just duplicate project fields)
            pass

    content = '[project]' + first_project_block + ''.join(cleaned_last_parts)

with open('Clarinet.toml', 'w') as f:
    f.write(content)
