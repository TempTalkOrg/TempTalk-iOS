---
name: local-branch-cleanup
description: Clean up local Git branches that have been merged or closed via PR. Removes stale feature, bugfix, and release branches.
disable-model-invocation: true
allowed-tools:
argument-hint: "[--confirm]"
---

# Clean Up Local Git Branches

Cleans up local branches that are no longer needed by detecting:
1. **PR merged** - Branches with merged PRs (squash, merge commit, or rebase)
2. **PR closed** - Branches with closed PRs (abandoned work)
3. **Git merged** - Branches merged directly into origin/develop (no PR)

Also prunes stale remote-tracking refs via `git fetch --prune`.

## Usage

Run in dry-run mode first to preview what will be deleted:

```bash
${CLAUDE_SKILL_DIR}/scripts/cleanup.sh
```

Then run with `--confirm` to actually delete:

```bash
${CLAUDE_SKILL_DIR}/scripts/cleanup.sh --confirm
```

## What Gets Deleted

- Feature branches (`feature/*`)
- Bugfix branches (`bugfix/*`, `fix/*`)
- Release branches (`release/*`) - only if merged into develop
- Any other branches with merged/closed PRs

## What's Protected

- `develop` - main development branch
- `main` - production branch (if exists)
- Current branch (cannot delete checked-out branch)
- Branches with no PR and not merged into develop

## Output Legend

- `✓` PR MERGED - Branch had a PR that was merged
- `✗` PR CLOSED - Branch had a PR that was closed without merge
- `⊕` GIT MERGED - Branch was merged directly (no PR)
