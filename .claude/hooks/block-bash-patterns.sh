#!/bin/bash
# Block bash patterns that should use built-in tools instead
# PreToolUse hook for Bash commands

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Pattern 1: Heredocs (<< EOF, <<EOF, << 'EOF')
# Should use Write tool instead
if echo "$COMMAND" | grep -qE '<<'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Heredoc patterns are blocked. Use the Write tool instead."
    }
  }'
  exit 0
fi

# Pattern 2: Pipes (cmd | cmd)
# Should run commands separately or use built-in tools
# Match single pipe but NOT double pipe (|| is OR operator, not a pipe)
if echo "$COMMAND" | grep -qE '\|' && ! echo "$COMMAND" | grep -qE '\|\|'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Pipe patterns are blocked. Run commands separately or use built-in tools (Grep, Read)."
    }
  }'
  exit 0
fi

# Pattern 3: Output redirects (> file, >> file)
# Should use Write tool instead
# Match file redirects but allow fd redirects like 2>&1
if echo "$COMMAND" | grep -qE '>>' || (echo "$COMMAND" | grep -qE '>' && ! echo "$COMMAND" | grep -qE '>&'); then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Redirect patterns (> >>) are blocked. Use the Write tool instead."
    }
  }'
  exit 0
fi

# Pattern 4: Command chains (&& or ;)
# Should run commands separately
if echo "$COMMAND" | grep -qE '&&|;'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Command chains (&& ;) are blocked. Run commands separately in sequential tool calls."
    }
  }'
  exit 0
fi

# Pattern 5: Git modifying commands
# Should use git-workflow-enforcer agent instead
# Read-only commands (status, log, diff, show, blame, branch) are allowed
# Note: git-workflow-enforcer agent has its own hook that allows git commands
if echo "$COMMAND" | grep -qE '^git (commit|push|reset|checkout \.|restore \.)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Git modifying commands are blocked. Use git-workflow-enforcer agent instead (Task tool with subagent_type=git-workflow-enforcer)."
    }
  }'
  exit 0
fi

# Pattern 6: GitHub CLI modifying commands
# Should use git-workflow-enforcer agent instead
# Read-only commands (view, list, diff, checks) are allowed
if echo "$COMMAND" | grep -qE '^gh (pr|issue|release) (create|merge|edit|close|reopen)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "GitHub CLI modifying commands are blocked. Use git-workflow-enforcer agent instead."
    }
  }'
  exit 0
fi

# Pattern 7a: Approve rm on relative tmp/ paths only
# This auto-approves deletion of temp files without user prompt
# Matches: rm tmp/, rm -f tmp/, rm -rf tmp/, rm -f ./tmp/, etc.
if echo "$COMMAND" | grep -qE '^rm\b[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*(\./)?tmp/'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "rm on relative tmp/ path is allowed."
    }
  }'
  exit 0
fi

# Pattern 7: /tmp/ paths (system tmp directory only)
# Should use tmp/ (relative) or scratchpad
# Only block paths starting with /tmp/, not ./tmp/ or other paths containing /tmp/
if echo "$COMMAND" | grep -qE '(^|[[:space:]])/tmp/'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "/tmp/ paths are blocked. Use tmp/ (relative) or scratchpad directory instead."
    }
  }'
  exit 0
fi

# Pattern 8: Absolute project directory paths
# Should use relative paths instead
# Blocks commands containing the project's absolute path to enforce relative path usage
if [ -n "$CLAUDE_PROJECT_DIR" ] && echo "$COMMAND" | grep -qF "$CLAUDE_PROJECT_DIR"; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Absolute project paths are blocked. Use relative paths instead (e.g., tmp/file instead of '"$CLAUDE_PROJECT_DIR"'/tmp/file)."
    }
  }'
  exit 0
fi

# Allow all other commands
exit 0
