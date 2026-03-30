#!/bin/bash
# Collect git commits for weekly report
# Usage: ./collect-commits.sh [START_DATE] [END_DATE]
# If no dates provided, uses current work week (Monday-Friday)

set -e

# Get author
AUTHOR=$(git config user.name)
if [ -z "$AUTHOR" ]; then
    echo "Error: git user.name not configured" >&2
    exit 1
fi

# Calculate dates
if [ -n "$1" ] && [ -n "$2" ]; then
    START_DATE="$1"
    END_DATE="$2"
else
    # macOS date command
    if date -v-mon +%Y-%m-%d >/dev/null 2>&1; then
        START_DATE=$(date -v-mon +%Y-%m-%d)
        END_DATE=$(date +%Y-%m-%d)
    else
        # GNU date (Linux)
        START_DATE=$(date -d "last monday" +%Y-%m-%d)
        END_DATE=$(date +%Y-%m-%d)
    fi
fi

# Get local timezone offset (e.g., +0800, -0500)
TZ_OFFSET=$(date +%z)

# Output metadata
echo "AUTHOR: $AUTHOR"
echo "START_DATE: $START_DATE"
echo "END_DATE: $END_DATE"
echo "---METADATA_END---"

# Fetch latest (fail if network error - don't collect stale data)
git fetch --all

# Collect commits with explicit local timezone
# Exclude pre_release merge commits (contain other authors' work)
git log --all --author="$AUTHOR" \
    --after="$START_DATE 00:00:00 $TZ_OFFSET" \
    --before="$END_DATE 23:59:59 $TZ_OFFSET" \
    --no-merges \
    --grep='\[TempTalk\|tt\]\[pre_release\]' --invert-grep \
    --pretty=format:"%s%n%b%n---GIT_COMMIT_SEPARATOR---"
