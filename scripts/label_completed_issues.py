#!/usr/bin/env python3
"""Batch label migrated issues as completed.

Usage:
  export GH_TOKEN=...
  python scripts/label_completed_issues.py --repo Anya-org/AutoVault --label completed --match "migrated-from" --state open
"""
import os, argparse, requests, sys
from typing import Generator, Any, Dict

API = "https://api.github.com"

def paged(session: requests.Session, path: str, **params: Any) -> Generator[Dict[str, Any], None, None]:
    page=1
    while True:
        r = session.get(f"{API}{path}", params={**params, 'per_page':100, 'page':page})
        r.raise_for_status()
        data = r.json()
        if not data: break
        for item in data: yield item
        page += 1

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', required=True)
    ap.add_argument('--label', required=True)
    ap.add_argument('--match', default='migrated-from')
    ap.add_argument('--state', default='open')
    args = ap.parse_args()
    token = os.getenv('GH_TOKEN')
    if not token:
        print('GH_TOKEN required', file=sys.stderr); sys.exit(1)
    s = requests.Session(); s.headers.update({'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json'})
    updated=0
    for issue in paged(s, f"/repos/{args.repo}/issues", state=args.state):
        if 'pull_request' in issue: continue
        body = issue.get('body') or ''
        if args.match in body:
            current_labels = [l['name'] for l in issue.get('labels', [])]
            if args.label not in current_labels:
                new_labels = current_labels + [args.label]
                r = s.patch(f"{API}/repos/{args.repo}/issues/{issue['number']}", json={'labels': new_labels})
                r.raise_for_status()
                updated += 1
                print(f"Labeled issue #{issue['number']}")
    print(f"Updated {updated} issues")

if __name__ == '__main__':
    main()
