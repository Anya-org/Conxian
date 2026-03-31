import os
import glob

def replace_unwrap_panic(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'unwrap-panic' not in content:
        return False

    # A simple regex won't work perfectly for Lisp due to nested parens, 
    # but we can try to find `(unwrap-panic ` and find the matching closing paren.
    
    new_content = ""
    i = 0
    changed = False
    while i < len(content):
        idx = content.find('(unwrap-panic ', i)
        if idx == -1:
            new_content += content[i:]
            break
        
        new_content += content[i:idx]
        
        # find matching closing parenthesis
        paren_count = 1
        j = idx + 14 # len('(unwrap-panic ')
        while j < len(content):
            if content[j] == '(':
                paren_count += 1
            elif content[j] == ')':
                paren_count -= 1
                if paren_count == 0:
                    break
            j += 1
        
        # content[idx:j+1] is the full `(unwrap-panic ...)`
        inner_expr = content[idx+14:j]
        new_content += f"(unwrap! {inner_expr} (err u9999))"
        changed = True
        i = j + 1

    if changed:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True
    return False

if __name__ == "__main__":
    count = 0
    for root, _, files in os.walk('Conxian/contracts'):
        for file in files:
            if file.endswith('.clar'):
                file_path = os.path.join(root, file)
                if replace_unwrap_panic(file_path):
                    count += 1
                    print(f"Updated {file_path}")
    print(f"Total files updated: {count}")
