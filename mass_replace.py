import os

root_dir = r"c:\Users\bmokoka\anyachainlabs\Conxian\contracts"
old_str = ".defi-traits.sip-010-ft-trait"
new_str = ".sip-standards.sip-010-ft-trait"

print(f"Scanning {root_dir} for '{old_str}'...")

count = 0
for subdir, dirs, files in os.walk(root_dir):
    for file in files:
        if file.endswith(".clar"):
            filepath = os.path.join(subdir, file)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                if old_str in content:
                    new_content = content.replace(old_str, new_str)
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated {filepath}")
                    count += 1
            except Exception as e:
                print(f"Error processing {filepath}: {e}")

print(f"Finished. Updated {count} files.")
