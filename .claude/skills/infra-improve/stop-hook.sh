#!/bin/bash
# Stop hook for infra-improve skill
# Blocks stopping when in overnight mode and iterations remain

# Read input from stdin (Claude Code passes hook context as JSON)
INPUT=$(cat)

# Check if this is already a stop hook continuation (prevent infinite loops)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | grep -o '"stop_hook_active":\s*true' || true)
if [ -n "$STOP_HOOK_ACTIVE" ]; then
  # Already in a stop hook continuation, allow exit
  exit 0
fi

# Path to state file (relative to project root)
STATE_FILE=".claude/infra-improve-state.json"

# Check if state file exists
if [ ! -f "$STATE_FILE" ]; then
  # No state file, allow exit
  exit 0
fi

# Read state file
MODE=$(grep -o '"mode":\s*"[^"]*"' "$STATE_FILE" | sed 's/.*"\([^"]*\)"/\1/' | head -1)
ITERATION=$(grep -o '"iteration":\s*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*' | head -1)
MAX_ITERATIONS=$(grep -o '"maxIterations":\s*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*' | head -1)
PHASE=$(grep -o '"phase":\s*"[^"]*"' "$STATE_FILE" | sed 's/.*"\([^"]*\)"/\1/' | head -1)

# Default values
MAX_ITERATIONS=${MAX_ITERATIONS:-20}
ITERATION=${ITERATION:-0}

# Only continue if mode is "overnight"
if [ "$MODE" != "overnight" ]; then
  exit 0
fi

# Check if we've reached max iterations
if [ "$ITERATION" -ge "$MAX_ITERATIONS" ]; then
  exit 0
fi

# Check if phase indicates completion (all P0/P1 done)
if [ "$PHASE" = "infrastructure_complete" ]; then
  exit 0
fi

# Calculate remaining iterations
REMAINING=$((MAX_ITERATIONS - ITERATION))

# Block stopping and request continuation
cat << EOF
{
  "decision": "block",
  "reason": "Overnight mode iteration $ITERATION/$MAX_ITERATIONS complete. $REMAINING iterations remaining. Continue with next improvement cycle: ANALYZE → PLAN → EXECUTE → REVIEW → REFINE → LEARN"
}
EOF
