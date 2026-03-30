#!/bin/bash
# Helper script to update PR title and body using GitHub REST API
# This avoids the "Projects (classic) deprecated" error from gh pr edit
# and the approval prompts from && chains and subshells
#
# Usage: ./gh-pr-update.sh <PR_NUMBER> <TITLE> <BODY_FILE>
#   PR_NUMBER: The PR number to update
#   TITLE: New PR title
#   BODY_FILE: Path to file containing PR body content

set -e

PR_NUMBER="$1"
TITLE="$2"
BODY_FILE="$3"

if [ -z "$PR_NUMBER" ] || [ -z "$TITLE" ] || [ -z "$BODY_FILE" ]; then
    echo "Usage: $0 <PR_NUMBER> <TITLE> <BODY_FILE>"
    echo "  PR_NUMBER: The PR number to update"
    echo "  TITLE: New PR title"
    echo "  BODY_FILE: Path to file containing PR body content"
    exit 1
fi

if [ ! -f "$BODY_FILE" ]; then
    echo "Error: Body file not found: $BODY_FILE"
    exit 1
fi

BODY=$(cat "$BODY_FILE")

gh api repos/difftim/TempTalk-iOS/pulls/"$PR_NUMBER" -X PATCH \
    -f title="$TITLE" \
    -f body="$BODY"

# Clean up the body file after successful update
rm -f "$BODY_FILE"

echo "PR #$PR_NUMBER updated successfully"
