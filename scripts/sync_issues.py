#!/usr/bin/env python3
"""Sync issues from source GitHub repo to destination.

Usage:
  export GH_TOKEN=your_token   # needs repo scope
  python scripts/sync_issues.py --source botshelomokoka/AutoVault --dest Anya-org/AutoVault [--close-source]

Idempotency:
- Skips issues already migrated (tracked via footer tag in body)
- Does not migrate pull requests

Limitations:
- Only basic fields; milestones/assignees copied best-effort
- Labels created in dest if missing
"""
import os, sys, argparse, time, requests

API = "https://api.github.com"
MIGRATION_TAG = "<!-- migrated-from:"

class GH:
    def __init__(self, token: str):
        self.s = requests.Session()
        self.s.headers.update({"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"})
    def get(self, path, **params):
        r = self.s.get(f"{API}{path}", params=params)
        r.raise_for_status(); return r.json()
    def post(self, path, data):
        r = self.s.post(f"{API}{path}", json=data)
        r.raise_for_status(); return r.json()
    def patch(self, path, data):
        r = self.s.patch(f"{API}{path}", json=data)
        r.raise_for_status(); return r.json()


def paged(gh, path, params=None):
    page=1
    while True:
        data = gh.get(path, per_page=100, page=page, **(params or {}))
        if not data: break
        for item in data: yield item
        page += 1


def ensure_labels(gh, dest, labels):
    existing = {l['name'] for l in paged(gh, f"/repos/{dest}/labels")}
    created = []
    for name in labels:
        if name not in existing:
            try:
                gh.post(f"/repos/{dest}/labels", {"name": name, "color": "ededed"})
                created.append(name)
            except requests.HTTPError as e:
                print(f"Warn: could not create label {name}: {e}")
    return created


def migrate_issue(gh, source, dest, issue, close_source=False):
    if 'pull_request' in issue: return 'skip-pr'
    orig_number = issue['number']
    footer = f"\n\n{MIGRATION_TAG} {source}#{orig_number} -->"
    if issue['body'] and MIGRATION_TAG in issue['body']:
        return 'already-tagged'
    labels = [l['name'] for l in issue.get('labels', [])]
    ensure_labels(gh, dest, labels)
    body = (issue.get('body') or '') + footer + "\nMigrated from %s#%d at %s" % (source, orig_number, issue['created_at'])
    data = {"title": issue['title'], "body": body, "labels": labels}
    created = gh.post(f"/repos/{dest}/issues", data)
    print(f"Created issue #{created['number']} from {source}#{orig_number}")
    # comments
    comments = gh.get(f"/repos/{source}/issues/{orig_number}/comments")
    for c in comments:
        gh.post(f"/repos/{dest}/issues/{created['number']}/comments", {"body": f"[Migrated comment from {c['user']['login']} at {c['created_at']}]\n\n{c['body']}"})
    # close source if requested
    if close_source and issue['state'] == 'open':
        gh.patch(f"/repos/{source}/issues/{orig_number}", {"state": "closed"})
    return 'migrated'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--source', required=True)
    ap.add_argument('--dest', required=True)
    ap.add_argument('--close-source', action='store_true')
    args = ap.parse_args()
    token = os.getenv('GH_TOKEN')
    if not token:
        print('GH_TOKEN env var required', file=sys.stderr); sys.exit(1)
    gh = GH(token)
    counts = {'migrated':0,'skip-pr':0,'already-tagged':0}
    for issue in paged(gh, f"/repos/{args.source}/issues", params={'state':'all'}):
        res = migrate_issue(gh, args.source, args.dest, issue, close_source=args.close_source)
        counts[res]+=1
        time.sleep(0.2)  # gentle rate throttle
    print('Summary:', counts)

if __name__ == '__main__':
    main()
