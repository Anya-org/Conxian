import os

def sanitize_files(root_dir):
    print(f"Scanning directory: {root_dir}")
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith(".clar"):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'rb') as f:
                        content = f.read()
                    
                    # Decode handling BOM if present
                    if content.startswith(b'\xef\xbb\xbf'):
                        text = content.decode('utf-8-sig')
                        print(f"Found UTF-8 BOM in {file}")
                    elif content.startswith(b'\xff\xfe') or content.startswith(b'\xfe\xff'):
                        text = content.decode('utf-16')
                        print(f"Found UTF-16 in {file}")
                    else:
                        # Try utf-8, fallback to latin-1
                        try:
                            text = content.decode('utf-8')
                        except UnicodeDecodeError:
                            text = content.decode('latin-1')
                            print(f"Fallback to latin-1 for {file}")
                    
                    # Normalize line endings
                    text = text.replace('\r\n', '\n')
                    
                    # Write back as clean UTF-8
                    with open(file_path, 'w', encoding='utf-8', newline='\n') as f:
                        f.write(text)
                        
                except Exception as e:
                    print(f"Error processing {file_path}: {e}")
    print("Sanitization complete.")

if __name__ == "__main__":
    sanitize_files("contracts")
