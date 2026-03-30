---
name: commit-push
description: Git commit and push in one step
context: fork
agent: git-workflow-enforcer
argument-hint: "[context]"
---

Commit and push all current changes with auto-generated message.

## Arguments Handling

User input: `$ARGUMENTS`

**Check format before using:**
- If matches commit format (`[type][scope] Title` + optional body) → use directly
- Otherwise → treat as context hint for auto-generation

**Default behavior**: Auto-generate commit message based on changes (recommended).
