import os

path = 'conxian-gateway/internal/engine/src/stacks/alex.rs'
with open(path, 'r') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if 'Ok(format!("handshake_{}", uuid::Uuid::new_v4()))' in line:
        new_lines.append(line)
        # Skip the next line which is the leftover '))'
        continue
    if '))' in line and i > 0 and 'Ok(format!("handshake_{}", uuid::Uuid::new_v4()))' in lines[i-1]:
        continue
    new_lines.append(line)

with open(path, 'w') as f:
    f.writelines(new_lines)
