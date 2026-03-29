import os
import re

def fix_parens(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Also fix where the original script might have broken things by making it 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
    # when it should be just 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM (without the parens in the string, or properly closed)
    # Let's just fix it universally:
    # A correct declaration looks like: (define-data-var admin principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
    
    # First, let's find any occurrences of 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM that are not followed by )
    # and add the )
    
    lines = content.split('\n')
    changed = False
    for i, line in enumerate(lines):
        if "(define-data-var" in line and "'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM" in line:
            if not line.strip().endswith(')'):
                lines[i] = line.rstrip() + ")"
                changed = True
                
    if changed:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        return True
    
    return False

if __name__ == "__main__":
    count = 0
    for root, _, files in os.walk('Conxian/contracts'):
        for file in files:
            if file.endswith('.clar'):
                file_path = os.path.join(root, file)
                if fix_parens(file_path):
                    count += 1
                    print(f"Fixed {file_path}")
    
    # Also check the specific errors mentioned
    # C:\Users\bmokoka\Conxian-Labs\conxian-business\Conxian\contracts\security\enhanced-circuit-breaker.clar
    # C:\Users\bmokoka\Conxian-Labs\conxian-business\Conxian\contracts\tokens\cxd-token.clar
    # Let's write a direct regex replace to fix those missing parens
    import re
    
    for root, _, files in os.walk('Conxian/contracts'):
        for file in files:
            if file.endswith('.clar'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    c = f.read()
                
                # Check for duplicate parens too, since our previous run might have added them
                lines = c.split('\n')
                changed = False
                for i in range(len(lines)):
                    if "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM" in lines[i]:
                        if "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)" in lines[i]:
                            # Fix the missing quote: ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) -> 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
                            if "'ST1PQ" not in lines[i]:
                                lines[i] = lines[i].replace("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)", "'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)")
                                changed = True
                        
                        # Remove double closing parenthesis if it occurred
                        if lines[i].rstrip().endswith("))") and "(define-data-var" in lines[i]:
                            lines[i] = lines[i].replace("))", ")")
                            changed = True
                                
                if changed:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write('\n'.join(lines))
                    print(f"Force-fixed quotes/parens in {file_path}")
    print(f"Total files fixed: {count}")

