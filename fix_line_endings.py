import os

def to_lf(path):
    with open(path, 'rb') as f:
        content = f.read()
    content = content.replace(b'\r\n', b'\n')
    with open(path, 'wb') as f:
        f.write(content)
    print(f"Fixed {path}")

def main():
    for root, dirs, files in os.walk("contracts"):
        for file in files:
            if file.endswith(".clar"):
                to_lf(os.path.join(root, file))

if __name__ == "__main__":
    main()
