---
name: insider-build
description: |
  Trigger TempTalk Beta builds, wait for completion, generate release notes.
  Complete workflow: build trigger → wait → release notes → clipboard.

  Trigger keywords: "insider build", "trigger insider", "beta build"
argument-hint: "[PR_NUMBER]"
allowed-tools: ["Skill(release-note-insider)"]
---

# Insider Build and Release Notes Workflow

Triggers TempTalk Beta builds on the release PR, waits for completion, then generates release notes.

## Workflow Execution

### Step 1: Find Release PR

If no PR number provided as argument, find the latest pre_release PR:

```bash
gh pr list --repo difftim/TempTalk-iOS --search "[TempTalk][pre_release]" --state open --limit 1 --json number,title
```

Extract PR number from result.

**Argument provided:** $ARGUMENTS (use this PR number if specified)

### Step 2: Trigger Builds and Wait

Run the wait script in the background and poll until completion (builds take ~20 min, exceeding Bash tool's 10-min max timeout):

```bash
# Step 2a: Start in background (run_in_background: true)
${CLAUDE_SKILL_DIR}/scripts/wait-insider-builds.sh <PR_NUMBER>
```

```
# Step 2b: Poll with 30-minute total timeout
# Repeat TaskOutput(task_id, block: true, timeout: 600000) until task completes
# Total polling budget: 30 minutes (1800000ms) — stop if exceeded
```

**CRITICAL**:
- MUST use `run_in_background: true` — builds take ~20 minutes, exceeding Bash 10-min max
- Poll with `TaskOutput(task_id, block: true, timeout: 600000)` — repeat if `not_ready`
- Total timeout: 30 minutes — if still not done, report timeout and stop
- If script exits with error (non-zero), STOP and report the failure
- Only proceed to Step 3 if both builds completed successfully

### Step 3: Generate Release Notes

After successful build completion, invoke the release-note-insider command:

```
Skill(release-note-insider)
```

This handles:
- Fetching build information
- Filtering user-facing changes
- Translating to Chinese
- Copying to clipboard

## Error Handling

- **PR not found**: Report error, stop
- **Build failed**: Report which build failed, stop
- **Build timeout**: Report timeout (25 min limit), stop
