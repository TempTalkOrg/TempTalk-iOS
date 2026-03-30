---
name: sync-claude-config
description: |
  Sync Claude config (.claude/ directory) from another project repo.
  Compares source vs target, adapts platform content (Android↔iOS),
  preserves target-only customizations. Incremental sync via git diff.

  Use when user says "sync config", "sync from android", "sync claude config",
  or "/sync-claude-config <path>".
argument-hint: "<source-project-path>"
allowed-tools: ["Bash(chmod:*)", "Bash(diff:*)", "Bash(git -C:*)", "Bash(python3:*)"]
---

# Sync Claude Config

Sync `.claude/` from **$ARGUMENTS** (source) → this repo (target).

## State

`.claude/sync-claude-state.json` — fields: `sourceRepo` (remote URL), `sourceCommit` (last synced hash), `syncedAt`.

## Steps

1. **Fetch** both repos: `git -C $SOURCE fetch origin` + `git fetch origin`
2. **Find changes** — State file exists: `git -C $SOURCE diff --name-only <stored_hash>..origin/develop -- .claude/`. No state file: full scan both `.claude/` dirs
3. **Classify** each file: NEW (source only → create) | MODIFIED (differs → update) | IDENTICAL (→ skip) | TARGET-ONLY (→ preserve)
4. **Adapt** — Read `references/platform-map.md` for Android↔iOS substitutions. Skip items in skip list.
5. **Present plan** — Migration table with actions and reasons. **Stop and wait for approval.**
6. **Execute** in order: Rules → Scripts → Skills → Agents → Commands → Hooks → Settings.json. For each: read source → adapt → write. `chmod +x` scripts.
7. **Verify & save** — Files exist, scripts executable, settings.json valid JSON, no stale source refs. Save source `origin/develop` HEAD to state file.
