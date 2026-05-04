import os
import re

def fix_commas(content):
    parts = []
    i = 0
    stack = []
    while i < len(content):
        c = content[i]
        if c == '{':
            stack.append('{')
            parts.append(c)
            i += 1
        elif c == '}':
            if stack and stack[-1] == '{': stack.pop()
            parts.append(c)
            i += 1
        elif c == '(':
            stack.append('(')
            parts.append(c)
            i += 1
        elif c == ')':
            if stack and stack[-1] == '(': stack.pop()
            parts.append(c)
            i += 1
        elif c == ':' and stack and stack[-1] == '{':
            parts.append(c)
            i += 1
            # Find end of value
            j = i
            nested = 0
            while j < len(content):
                curr = content[j]
                if curr in '{(': nested += 1
                elif curr in '})':
                    if nested == 0: break
                    nested -= 1
                elif nested == 0:
                    # Look for next key
                    k = j
                    while k < len(content) and (content[k].isspace() or content[k] == ';'):
                        if content[k] == ';':
                            while k < len(content) and content[k] != '\n': k += 1
                        else:
                            k += 1
                    if k < len(content):
                        if content[k] == '}': break
                        # Key is identifier followed by colon
                        m = re.match(r'^[^:\s{}()\[\],]+:', content[k:])
                        if m: break
                j += 1

            val_part = content[i:j]
            trimmed = re.sub(r';;.*', '', val_part).strip()

            # Should we add a comma?
            # Yes if there is another key following
            if trimmed and not trimmed.endswith(',') and j < len(content) and content[j] != '}':
                k = j
                while k < len(content) and (content[k].isspace() or content[k] == ';'):
                    if content[k] == ';':
                        while k < len(content) and content[k] != '\n': k += 1
                    else:
                        k += 1
                if k < len(content) and content[k] != '}':
                    m = re.match(r'^[^:\s{}()\[\],]+:', content[k:])
                    if m:
                        # Append comma to value, before trailing whitespace
                        ws_match = re.search(r'\s*$', val_part)
                        ws = ws_match.group() if ws_match else ''
                        parts.append(val_part[:len(val_part)-len(ws)] + ',' + ws)
                        i = j
                        continue

            parts.append(val_part)
            i = j
        else:
            parts.append(c)
            i += 1
    return "".join(parts)

def run():
    count = 0
    for root, dirs, files in os.walk('contracts'):
        for f in files:
            if f.endswith('.clar'):
                p = os.path.join(root, f)
                with open(p, 'r') as file:
                    content = file.read()
                fixed = fix_commas(content)
                if fixed != content:
                    with open(p, 'w') as file:
                        file.write(fixed)
                    count += 1
    print(f"Fixed {count} files")

if __name__ == "__main__":
    run()
