import os
import re
from pathlib import Path

def check_links():
    md_files = list(Path('.').rglob('*.md'))
    broken_links = []

    for md_file in md_files:
        if 'node_modules' in str(md_file):
            continue

        with open(md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # Find markdown links [text](link.md)
        links = re.findall(r'\[.*?\]\((.*?\.md)\)', content)

        for link in links:
            if link.startswith('http'):
                continue

            # Clean up link (remove fragments)
            clean_link = link.split('#')[0]
            if not clean_link:
                continue

            # Resolve relative path
            target_path = (md_file.parent / clean_link).resolve()

            if not target_path.exists():
                broken_links.append((md_file, link, target_path))

    for source, link, target in broken_links:
        print(f"Broken link in {source}: {link} -> {target}")

if __name__ == "__main__":
    check_links()
