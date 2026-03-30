#!/bin/bash
# Auto-approve bash commands that run scripts under .claude/
# Auto-deny if the script file doesn't exist (prevents approve-then-404 flow)
# PreToolUse hook for Bash commands
#
# Matches:
#   .claude/scripts/*.sh           — project-level scripts
#   .claude/skills/*/scripts/*.sh  — skill scripts (full path)
#   scripts/*.sh                   — skill scripts (relative, run from SKILL.md)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Exclusion list: scripts that require manual approval (pass through to normal prompt)
if echo "$COMMAND" | grep -q 'copy-to-clipboard\.sh'; then
  exit 0
fi

# Pattern 1: command contains .claude/scripts/ or .claude/skills/*/scripts/
SCRIPT_PATH=$(echo "$COMMAND" | grep -oE '(\.\/)?\.claude/(scripts|skills)/[^ ]+\.sh' | head -1)

if [ -n "$SCRIPT_PATH" ]; then
  # Normalize: strip leading ./
  SCRIPT_PATH=$(echo "$SCRIPT_PATH" | sed 's|^\./||')

  if [ -f "$SCRIPT_PATH" ]; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        permissionDecisionReason: "Script exists in .claude/ directory — auto-approved."
      }
    }'
  else
    jq -n --arg path "$SCRIPT_PATH" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("Script not found: " + $path)
      }
    }'
  fi
  exit 0
fi

# Pattern 2: bare "scripts/*.sh" (skill scripts run from SKILL.md context)
BARE_SCRIPT=$(echo "$COMMAND" | grep -oE '(^|[ ])scripts/[^ ]+\.sh' | sed 's|^ ||' | head -1)

if [ -n "$BARE_SCRIPT" ]; then
  # Check if it exists under any skill directory
  FOUND=""
  for candidate in .claude/skills/*/"$BARE_SCRIPT"; do
    if [ -f "$candidate" ]; then
      FOUND="$candidate"
      break
    fi
  done

  if [ -n "$FOUND" ]; then
    jq -n --arg path "$FOUND" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        permissionDecisionReason: ("Script exists at " + $path + " — auto-approved.")
      }
    }'
  else
    jq -n --arg path "$BARE_SCRIPT" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("Script not found in any .claude/skills/*/ directory: " + $path)
      }
    }'
  fi
  exit 0
fi

# No script pattern matched — pass through
