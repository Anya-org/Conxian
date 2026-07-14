# Git Process Guide

> **Version:** 1.0 (2026-07-14)
> **Authority:** BOS (conxian-business)
> **Reference:** [BRANCHING_AND_PROMOTION_POLICY.md](./BRANCHING_AND_PROMOTION_POLICY.md)

This document defines the standard Git workflow for all Conxian repositories.

---

## Branch Strategy

```
main (production)
  └── staged (staging/pre-release)
        └── dev (development)
              └── feature/xxx, fix/xxx, chore/xxx (short-lived)
```

### Branch Purposes

| Branch | Purpose | Protected | Auto-Deploy |
|--------|---------|-----------|-------------|
| `main` | Production release | ✅ Yes | Yes |
| `staged` | Pre-release validation | ✅ Yes | Optional |
| `dev` | Integration & testing | ✅ Yes | No |
| `feature/*` | New features | ❌ No | No |
| `fix/*` | Bug fixes | ❌ No | No |
| `chore/*` | Maintenance, deps | ❌ No | No |
| `docs/*` | Documentation | ❌ No | No |

---

## Commit Messages

### Format

```
<type>(<scope>): <short summary>

[optional body]

[optional footer]
```

### Types

| Type | When to Use |
|------|--------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `chore` | Build, deps, tooling |
| `docs` | Documentation only |
| `refactor` | Code restructure (no feature/fix) |
| `test` | Adding tests |
| `perf` | Performance improvement |
| `ci` | CI/CD changes |
| `revert` | Revert previous commit |

### Examples

```bash
# Good
feat(gateway): add DLC CET construction endpoint
fix(nexus): resolve settlement race condition
chore(deps): bump rustls to 0.22
docs(bos): add M2M context matrix

# Bad
fixed stuff
WIP
update
```

### Rules

1. **Imperative mood**: "Add" not "Added" or "Adds"
2. **First line ≤72 chars**
3. **Reference Linear issues**: `CON-123`, `CONX-456`
4. **Co-authored by**: Add `Co-authored-by: openhands <openhands@all-hands.dev>` for AI-assisted work

---

## Push Protocol

### Before Push

```bash
# 1. Verify clean state
git status

# 2. Verify tests pass
cargo test  # Rust repos
pnpm test    # Node repos
clarinet check  # Clarity repos

# 3. Verify no secrets
gitleaks detect --source .
```

### Push Commands

```bash
# Feature branches
git push origin feature/my-feature

# Development
git push origin dev

# Hotfixes (emergency only, requires approval)
git push origin main
```

### Push with Co-Author

```bash
# Add co-author for AI work
git commit --amend --no-edit --author "openhands <openhands@all-hands.dev>"
git push origin <branch>
```

---

## Pull Request Process

### Creating PRs

#### From Branch to Dev
```bash
# Create feature branch from dev
git checkout dev
git pull origin dev
git checkout -b feature/my-work

# Make changes, commit
git add .
git commit -m "feat(scope): description"

# Push and create PR
git push origin feature/my-work
gh pr create --base dev --title "feat(scope): description"
```

#### PR Template
```markdown
## Summary
<!-- What does this PR do? -->

## Changes
<!-- List specific changes -->

## Testing
<!-- How was this tested? -->

## Checklist
- [ ] Tests pass
- [ ] No new warnings
- [ ] Documentation updated (if applicable)
- [ ] Linear issue linked

_This PR was created by an AI agent (OpenHands) on behalf of the Conxian team._
```

### PR Labels

| Label | When to Apply |
|-------|---------------|
| `feature` | New features |
| `bugfix` | Bug fixes |
| `chore` | Maintenance, deps |
| `docs` | Documentation |
| `automated` | AI/bot created |
| `security` | Security changes |
| `breaking` | Breaking changes |

### PR Review Requirements

| Change Type | Reviews Required | Approvals |
|-------------|-----------------|-----------|
| Documentation | 0 | Optional |
| Chore/deps | 0 | Optional |
| Features | 1 | 1 |
| Bug fixes | 1 | 1 |
| Security | 2 | 2 |
| Protocol contracts | 2 | 2 |

---

## Promotion Pipeline

### Standard Flow

```
feature/xxx → dev → staged → main
```

### Step-by-Step

#### 1. Merge to Dev
```bash
# PR approved, merge via UI or CLI
gh pr merge <pr-number> --squash --delete-branch
```

#### 2. Promote to Staged
```bash
# From dev branch
git checkout staged
git pull origin staged
git merge dev
git push origin staged

# Or via PR
gh pr create --base staged --head dev --title "chore: promote dev to staged"
```

#### 3. Promote to Main
```bash
# From staged branch (after validation)
git checkout main
git pull origin main
git merge staged
git push origin main

# Or via PR
gh pr create --base main --head staged --title "chore: promote staged to main"
```

---

## Submodule Management

### Adding a Submodule

```bash
# 1. Add submodule (from parent repo)
git submodule add -b main https://github.com/Conxian/repo.git path

# 2. Clean URL (no token)
sed -i 's|https://.*@github.com|https://github.com|g' .gitmodules

# 3. Initialize
git submodule update --init --recursive

# 4. Commit
git add .gitmodules path/
git commit -m "feat(bos): add submodule repo"
git push origin dev
```

### Updating Submodule Pin

```bash
# 1. Go to submodule
cd path/to/submodule

# 2. Pull latest
git fetch origin
git checkout main
git pull origin main

# 3. Get SHA
git rev-parse HEAD

# 4. Go to parent, update pin
cd ..
git add path/to/submodule
git commit -m "chore: bump submodule pin to <sha>"
git push origin dev
```

### Submodule Workflow

```bash
# Initialize all (first time)
git submodule update --init --recursive

# Sync all (after pull)
git submodule update --init

# Sync specific
git submodule update --init path/to/submodule

# Status
git submodule status
```

---

## GitHub Token & Privacy

### Private Email Issue

If you get `GH007: Your push would publish a private email address`:

```bash
# Option 1: Use openhands email
git commit --amend --author "openhands <openhands@all-hands.dev>" --no-edit
git push origin <branch>

# Option 2: Filter all commits
git filter-branch -f --env-filter \
  'export GIT_AUTHOR_EMAIL="openhands@all-hands.dev" GIT_COMMITTER_EMAIL="openhands@all-hands.dev"' \
  HEAD~1..HEAD
git push origin <branch>

# Option 3: Use force-push to new branch (if main requires PRs)
git checkout -b docs/changes
git push origin docs/changes
# Then create PR
```

### Protected Branch Rules

| Branch | Rule |
|--------|------|
| `main` | Must PR, 2 approvals |
| `staged` | Must PR from `dev` |
| `dev` | Must PR, 1 approval |

---

## Quick Reference

```bash
# === Daily Workflow ===
git checkout dev && git pull origin dev
git submodule update --init --recursive
# Make changes...
git add . && git commit -m "type(scope): message"
git push origin feature/my-work
# Create PR via GitHub UI

# === Submodule Update ===
cd submodule && git checkout main && git pull origin main
cd .. && git add submodule && git commit -m "chore: bump submodule"
git push origin dev

# === Promotion ===
git checkout staged && git merge dev && git push origin staged
git checkout main && git merge staged && git push origin main
```

---

## Common Issues

### Detached HEAD in Submodule
```bash
git checkout main  # or the branch you need
```

### Submodule Not Initialized
```bash
git submodule update --init path/to/submodule
```

### Branch Divergence
```bash
# Option 1: Rebase
git rebase origin/dev

# Option 2: Force reset (careful!)
git fetch origin
git reset --hard origin/dev
```

---

*Generated per BOS mandate for standardized Git workflow*
