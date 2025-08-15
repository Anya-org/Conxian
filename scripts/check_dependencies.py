#!/usr/bin/env python3
"""Dependabot triage helper: list outdated npm & highlight security advisory placeholder."""
import json, subprocess, shutil, typing as t

def main() -> None:
    result: t.Dict[str, t.Any] = {}
    if shutil.which('npm'):
        data: t.Dict[str, t.Any] = {}
        try:
            out = subprocess.check_output(['npm','outdated','--json'], cwd='stacks')
            if out:
                data = json.loads(out.decode())  # type: ignore[assignment]
        except subprocess.CalledProcessError as e:
            # npm outdated returns non-zero if outdated packages exist
            if e.output:
                try:
                    data = json.loads(e.output.decode())  # type: ignore[assignment]
                except Exception:
                    data = {}
        result['outdated'] = data
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
