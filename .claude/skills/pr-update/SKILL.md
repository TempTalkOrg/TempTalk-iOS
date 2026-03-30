---
name: pr-update
description: Update PR title and body after new commits
context: fork
agent: git-workflow-enforcer
argument-hint: "[PR number]"
---

Update the PR title and body for: $ARGUMENTS
