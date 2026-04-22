# Releasing

This repo uses **Semantic Versioning** and **tagged releases**.

- Version tags: `vX.Y.Z`
- Release notes: `CHANGELOG.md` (Keep a Changelog)

For release note format requirements, see `docs/RELEASE_NOTES_AND_CHANGELOG.md`.
For required checks and label-gated CI suites, see `.github/RELEASE_HYGIENE.md`.
## When to cut a release

Cut a release when a change is user-facing (behavior, security posture, public docs that reframe the system), or when a set of changes should be pinned to an immutable reference for downstream repos.

## Release steps

1. Update `CHANGELOG.md`
   - Ensure `## [Unreleased]` exists.
   - Move the changes being released from `## [Unreleased]` into a new `## [X.Y.Z] - YYYY-MM-DD` section.
   - Keep user-facing version strings in sync (for example, the BOS version in `README.md`).

   Note: `Conxian Unified CI` enforces the `## [Unreleased]` section via `scripts/verify_release_hygiene.py`.
2. Create an annotated tag locally:

```bash
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
```

3. Create a GitHub Release using the tag.

If you have `gh` installed:

```bash
# Copy only the vX.Y.Z section from CHANGELOG.md into /tmp/release-notes.md
gh release create vX.Y.Z --title "vX.Y.Z" --notes-file /tmp/release-notes.md
```

## Submodule repositories

`conxian-business` vendors major repositories as Git submodules. Each user-facing submodule repository should:

- Tag releases independently.
- Keep its own `CHANGELOG.md`.
- Add CI and a status badge in its own README.

When bumping a pinned submodule (gitlink) in this repo, prefer bumping to a tagged release commit in the upstream submodule repo.

### Safe submodule bump workflow (SHA-pinned)

Use explicit immutable refs only (exact commit SHA or immutable tag):

```bash
git submodule update --init <path>
cd <path> && git fetch origin --tags && git checkout <exact-sha-or-immutable-tag>
cd -
git add <path>
git commit -m "chore: bump <path> pin to <sha>"
python3 scripts/verify_submodule_integrity.py
git submodule status --recursive
```

Disallowed submodule update patterns:

- `git submodule update --remote`
- `submodule.<name>.branch` tracking config
- `git submodule foreach` loops that perform `git checkout main` + `git pull`

### Evidence to include in release-adjacent submodule PRs

- gitlink diff for each bumped submodule path
- `python3 scripts/verify_submodule_integrity.py` output
- `git submodule status --recursive` output
- when contamination-sensitive paths changed, `python3 scripts/verify_contamination_guard.py` output
