#!/bin/bash
# Usage: wait-pr-merge.sh <PR_NUMBER>
# Waits for a PR to be merged, polling every 15 seconds

set -e

PR_NUMBER=$1

if [ -z "$PR_NUMBER" ]; then
  echo "Usage: $0 <PR_NUMBER>"
  exit 1
fi

REPO="difftim/TempTalk-iOS"
MAX_WAIT=43200  # 12 hours
ELAPSED=0
INTERVAL=15

echo "Waiting for PR #${PR_NUMBER} to be merged..."

while [ $ELAPSED -lt $MAX_WAIT ]; do
  STATE=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json state,mergedAt --jq '.state')

  if [ "$STATE" = "MERGED" ]; then
    echo ""
    echo "=== PR #${PR_NUMBER} MERGED ==="
    exit 0
  fi

  if [ "$STATE" = "CLOSED" ]; then
    echo ""
    echo "=== PR #${PR_NUMBER} CLOSED (not merged) ==="
    exit 1
  fi

  echo "$(date '+%H:%M:%S') - PR #${PR_NUMBER} state: ${STATE} (${ELAPSED}s elapsed)"
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "=== TIMEOUT ==="
echo "PR #${PR_NUMBER} was not merged within ${MAX_WAIT} seconds"
echo "You can merge it manually and re-run the skill to continue with Phase 3"
exit 1
