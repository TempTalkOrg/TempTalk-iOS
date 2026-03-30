# Git Workflow Rules

## Modifying Operations → Use Skills/Agent

| Operation | Use This | NOT This |
|-----------|----------|----------|
| Commit | `/commit` | `git commit`, `git-commit.sh` |
| Push | `/push` | `git push`, `git-push.sh` |
| Commit + Push | `/commit-push` | `git commit && git push` |
| Create PR | `/pr-create` | `gh pr create`, `gh-pr-create.sh` |
| Update PR | `/pr-update` | `gh pr edit` |

**Note:** Direct `git commit`, `git push`, etc. are blocked by hook. Skills/agent have their own hooks that allow git commands.

## Why Skills/Agent for These?

- **Commit format** - Ensures `[type][scope] message` convention
- **No AI attribution** - Excludes "Co-Authored-By: Claude" per Critical Rule #3
- **PR workflow** - Draft → code review → ready flow
- **Hook enforced** - Direct commands blocked in main thread

## Read-Only Commands → OK to Run Directly

| Command | Purpose |
|---------|---------|
| `git status` | Check working tree |
| `git log` | View history |
| `git diff` | See changes |
| `git branch` | List branches |
| `git show` | View commit |
| `git blame` | Line history |
| `gh pr view` | View PR details |
| `gh pr list` | List PRs |
