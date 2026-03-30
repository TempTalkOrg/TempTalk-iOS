---
name: commit-push-update-pr
description: Git commit, push, and update PR title/body
context: fork
agent: git-workflow-enforcer
argument-hint: "[commit message]"
---

Commit, push, and update the PR title/body for current branch.

Commit message: $ARGUMENTS
