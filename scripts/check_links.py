import configparser
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIR_PARTS = {
    '.git',
    '.next',
    '.venv',
    '__pycache__',
    'build',
    'coverage',
    'dist',
    'node_modules',
    'out',
    'playwright-report',
    'test-results',
}


def _uninitialized_submodule_dirs() -> list[Path]:
    gitmodules = REPO_ROOT / '.gitmodules'
    if not gitmodules.exists():
        return []

    config = configparser.ConfigParser(interpolation=None)
    config.read(gitmodules, encoding='utf-8')

    submodule_paths = [
        config.get(section, 'path')
        for section in config.sections()
        if config.has_option(section, 'path')
    ]

    dirs = [(REPO_ROOT / p).resolve() for p in submodule_paths]
    return [d for d in dirs if not (d / '.git').exists()]


def _is_within_uninitialized_submodule(path: Path, uninitialized_submodule_dirs: list[Path]) -> bool:
    return any(path.is_relative_to(submodule_dir) for submodule_dir in uninitialized_submodule_dirs)


def _repo_root_for(md_file: Path) -> Path:
    current = md_file.parent
    while True:
        if (current / '.git').exists():
            return current
        if current == current.parent:
            return REPO_ROOT
        current = current.parent


def _find_markdown_files() -> list[Path]:
    md_files: list[Path] = []

    for root, dirs, files in os.walk(REPO_ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIR_PARTS]
        for name in files:
            if name.lower().endswith(('.md', '.markdown')):
                md_files.append(Path(root) / name)

    return md_files

def check_links():
    md_files = _find_markdown_files()
    broken_links = []
    uninitialized_submodule_dirs = _uninitialized_submodule_dirs()

    for md_file in md_files:
        repo_root_for_file = _repo_root_for(md_file)
        content = md_file.read_text(encoding='utf-8')

        # Find markdown links [text](target)
        raw_links = re.findall(r'\[[^\]]*\]\(([^)]+)\)', content)

        for link in raw_links:
            link = link.strip()
            if not link:
                continue

            if link.startswith('#'):
                continue

            if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', link):
                continue

            # Clean up link (remove fragments)
            clean_link = link.split('#', 1)[0].strip()
            if not clean_link:
                continue

            href = clean_link.split()[0]
            if not href.lower().endswith(('.md', '.markdown')):
                continue

            base_dir = repo_root_for_file if href.startswith('/') else md_file.parent
            target_path = (base_dir / href.lstrip('/')).resolve()

            try:
                target_path.relative_to(repo_root_for_file)
            except ValueError:
                broken_links.append((md_file.relative_to(REPO_ROOT), link, target_path))
                continue

            if not target_path.exists():
                if _is_within_uninitialized_submodule(target_path, uninitialized_submodule_dirs):
                    continue
                try:
                    target_rel = target_path.relative_to(REPO_ROOT)
                except ValueError:
                    target_rel = target_path

                broken_links.append(
                    (
                        md_file.relative_to(REPO_ROOT),
                        link,
                        target_rel,
                    )
                )

    for source, link, target in broken_links:
        print(f"Broken link in {source}: {link} -> {target}")

    if broken_links:
        sys.exit(1)

if __name__ == "__main__":
    check_links()
