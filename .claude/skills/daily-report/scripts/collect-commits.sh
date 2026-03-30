#!/bin/bash
# Collect git commits for daily report
# Usage: ./collect-commits.sh [DATE]
# If no date provided, uses today

set -e

# Get author
AUTHOR=$(git config user.name)
if [ -z "$AUTHOR" ]; then
    echo "Error: git user.name not configured" >&2
    exit 1
fi

# Calculate date
if [ -n "$1" ]; then
    DATE="$1"
else
    DATE=$(date +%Y-%m-%d)
fi

# Get local timezone offset (e.g., +0800, -0500)
TZ_OFFSET=$(date +%z)

# Output metadata
echo "AUTHOR: $AUTHOR"
echo "DATE: $DATE"
echo "---METADATA_END---"

# Fetch latest (fail if network error - don't collect stale data)
git fetch --all

# Collect commits with explicit local timezone
# Exclude pre_release merge commits (contain other authors' work)
git log --all --author="$AUTHOR" \
    --after="$DATE 00:00:00 $TZ_OFFSET" \
    --before="$DATE 23:59:59 $TZ_OFFSET" \
    --no-merges \
    --grep='\[TempTalk\|tt\]\[pre_release\]' --invert-grep \
    --pretty=format:"%s%n%b%n---GIT_COMMIT_SEPARATOR---"
