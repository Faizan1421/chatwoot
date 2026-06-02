# Syncing with Upstream Chatwoot

This guide covers how to keep your fork in sync with the upstream Chatwoot repository.

## Initial Setup

Add the upstream remote (one-time step):

```bash
git remote add upstream https://github.com/chatwoot/chatwoot.git
```

Verify remotes:

```bash
git remote -v
# origin    git@github.com:<your-org>/chatwoot.git (fetch)
# origin    git@github.com:<your-org>/chatwoot.git (push)
# upstream  https://github.com/chatwoot/chatwoot.git (fetch)
# upstream  https://github.com/chatwoot/chatwoot.git (push)
```

## Pulling Updates from Upstream

### Option 1: Merge (recommended)

Preserves your commit history alongside upstream changes:

```bash
git checkout develop
git fetch upstream
git merge upstream/develop
git push origin develop
```

### Option 2: Rebase

Replays your commits on top of upstream (cleaner history, but rewrites commits):

```bash
git checkout develop
git fetch upstream
git rebase upstream/develop
git push origin develop --force-with-lease
```

> **Note:** Only force-push if no one else is working off your `develop` branch.

## Handling Merge Conflicts

If conflicts arise during merge/rebase:

1. Git will list conflicted files
2. Open each file and resolve conflicts (look for `<<<<<<<` markers)
3. Stage resolved files: `git add <file>`
4. Continue:
   - For merge: `git commit`
   - For rebase: `git rebase --continue`

## Syncing a Feature Branch

If you're working on a feature branch and want upstream changes:

```bash
git checkout your-feature-branch
git fetch upstream
git merge upstream/develop
```

## Tips

- Sync regularly (weekly or before starting new work) to avoid large conflict sets
- Custom folders like `docs/` won't be affected by upstream pulls since upstream doesn't have them
- Always fetch before merging to ensure you have the latest upstream state
- Use `git log --oneline upstream/develop..develop` to see commits in your fork that aren't upstream
