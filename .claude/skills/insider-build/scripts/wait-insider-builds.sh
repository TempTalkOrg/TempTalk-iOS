#!/bin/bash
# Usage: wait-insider-builds.sh <PR_NUMBER>
# Triggers TempTalk beta build and waits for completion

set -e

PR_NUMBER=$1

if [ -z "$PR_NUMBER" ]; then
  echo "Usage: $0 <PR_NUMBER>"
  exit 1
fi

REPO="difftim/TempTalk-iOS"

# Step 1: Record trigger timestamp (ISO 8601 format for GitHub API comparison)
TRIGGER_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Step 2: Trigger build
echo "Triggering TempTalk beta build on PR #${PR_NUMBER}..."
gh pr comment "$PR_NUMBER" --repo "$REPO" --body "/tt_tf"
echo "Build trigger sent at ${TRIGGER_TIME}"

# Step 3: Wait for build to start (give CI time to pick up the comment)
echo "Waiting for build to start..."
sleep 10

# Step 4: Poll for build result comments created AFTER trigger time
echo "Waiting for build to complete..."
MAX_WAIT=1500  # 25 minutes
ELAPSED=0
INTERVAL=30

while [ $ELAPSED -lt $MAX_WAIT ]; do
  # Get comments created after trigger time, check each for build results
  BUILD_STATUS=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
    --paginate \
    --jq "[.[] | select(.created_at > \"${TRIGGER_TIME}\")] | .[] |
      if (.body | test(\"## [Tt]emp[Tt]alk-.*build:\"; \"i\")) and ((.body | contains(\"successfully\")) or (.body | contains(\"成功\"))) then \"TT_OK\"
      elif (.body | test(\"## [Tt]emp[Tt]alk-.*build:\"; \"i\")) and ((.body | contains(\"failed\")) or (.body | contains(\"失败\"))) then \"TT_FAIL\"
      else empty end" 2>/dev/null || echo "")

  # Count results
  TT_DONE=$(echo "$BUILD_STATUS" | grep -c "TT_OK" || true)
  TT_FAIL=$(echo "$BUILD_STATUS" | grep -c "TT_FAIL" || true)

  if [ "$TT_DONE" -gt 0 ]; then
    echo ""
    echo "=== BUILD COMPLETE ==="
    echo "TempTalk Beta: Success"
    echo "======================"
    exit 0
  fi

  if [ "$TT_FAIL" -gt 0 ]; then
    echo ""
    echo "=== BUILD FAILED ==="
    echo "TempTalk Beta: Failed"
    echo "===================="
    exit 1
  fi

  echo "$(date '+%H:%M:%S') - Waiting for: TempTalk build... (${ELAPSED}s elapsed)"
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "=== BUILD TIMEOUT ==="
echo "Build did not complete within ${MAX_WAIT} seconds"
exit 1
