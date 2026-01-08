# Simple script to check for syntax issues in Clarity files
import os
import re

def check_clarity_syntax(file_path):
    """Check for common syntax issues in Clarity files"""
    issues = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        lines = content.split('\n')
    
    paren_stack = []
    brace_stack = []
    
    for i, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith(';;'):
            continue
            
        # Check for unbalanced parentheses
        for char in line:
            if char == '(':
                paren_stack.append((i, char))
            elif char == ')':
                if not paren_stack:
                    issues.append(f"Line {i}: Unmatched closing parenthesis")
                else:
                    paren_stack.pop()
            elif char == '{':
                brace_stack.append((i, char))
            elif char == '}':
                if not brace_stack:
                    issues.append(f"Line {i}: Unmatched closing brace")
                else:
                    brace_stack.pop()
        
        # Check for common syntax issues
        if 'use-trait' in line and line.count('(') != line.count(')'):
            issues.append(f"Line {i}: Unbalanced parentheses in use-trait")
        
        if 'define-map' in line and '{' in line and '}' not in line and line.strip().endswith('{'):
            issues.append(f"Line {i}: Unclosed map definition")
    
    # Check for unclosed structures at end of file
    if paren_stack:
        issues.append(f"Unclosed parentheses starting at line {paren_stack[0][0]}")
    if brace_stack:
        issues.append(f"Unclosed braces starting at line {brace_stack[0][0]}")
    
    return issues

def main():
    contracts_dir = "contracts"
    problematic_files = []
    
    for root, dirs, files in os.walk(contracts_dir):
        for file in files:
            if file.endswith('.clar'):
                file_path = os.path.join(root, file)
                issues = check_clarity_syntax(file_path)
                if issues:
                    problematic_files.append((file_path, issues))
    
    print("Problematic files:")
    for file_path, issues in problematic_files:
        print(f"\n{file_path}:")
        for issue in issues:
            print(f"  {issue}")

if __name__ == "__main__":
    main()
