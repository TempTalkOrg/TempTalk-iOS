#!/bin/bash
# Hook for git-workflow-enforcer agent
# Allows git commands, but applies normal blocking for everything else

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Block git commit/push — must use helper scripts
if echo "$COMMAND" | grep -qE '^git (commit|push)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Use helper scripts: ./.claude/scripts/git-commit.sh, ./.claude/scripts/git-push.sh, or ./.claude/scripts/git-commit-push.sh"
    }
  }'
  exit 0
fi

# Block gh pr create/edit — must use helper scripts
if echo "$COMMAND" | grep -qE '^gh pr (create|edit)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Use helper scripts: ./.claude/scripts/gh-pr-create.sh or ./.claude/scripts/gh-pr-update.sh"
    }
  }'
  exit 0
fi

# Allow all other git commands
if echo "$COMMAND" | grep -qE '^git '; then
  exit 0
fi

# Allow all other gh commands
if echo "$COMMAND" | grep -qE '^gh '; then
  exit 0
fi

# Allow helper scripts in .claude/scripts/
if echo "$COMMAND" | grep -qE '^\./\.claude/scripts/'; then
  exit 0
fi

# For all other commands, apply normal blocking by calling the main hook
echo "$INPUT" | "$CLAUDE_PROJECT_DIR"/.claude/hooks/block-bash-patterns.sh
