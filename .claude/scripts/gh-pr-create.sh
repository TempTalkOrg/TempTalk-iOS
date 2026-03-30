#!/bin/bash
# Script to create GitHub PR (avoids multi-line command approval issues)
# Usage: ./.claude/scripts/gh-pr-create.sh <title> <body_file> <base> <head> <reviewers> <label> [--draft]

set -e

TITLE="$1"
BODY_FILE="$2"
BASE="${3:-develop}"
HEAD="$4"
REVIEWERS="$5"
LABEL="$6"
DRAFT_FLAG="$7"

if [ -z "$TITLE" ] || [ -z "$BODY_FILE" ]; then
    echo "Usage: $0 <title> <body_file> [base] [head] [reviewers] [label] [--draft]"
    echo "  title     - PR title (required)"
    echo "  body_file - Path to file containing PR body (required)"
    echo "  base      - Base branch (default: develop)"
    echo "  head      - Head branch (default: current branch)"
    echo "  reviewers - Comma-separated list of reviewers"
    echo "  label     - PR label"
    echo "  --draft   - Create as draft PR (optional, 7th argument)"
    exit 1
fi

# Build the command
CMD="gh pr create --base \"$BASE\" --title \"$TITLE\" --body-file \"$BODY_FILE\""

if [ -n "$HEAD" ]; then
    CMD="$CMD --head \"$HEAD\""
fi

if [ -n "$REVIEWERS" ]; then
    CMD="$CMD --reviewer \"$REVIEWERS\""
fi

if [ -n "$LABEL" ]; then
    CMD="$CMD --label \"$LABEL\""
fi

if [ "$DRAFT_FLAG" = "--draft" ]; then
    CMD="$CMD --draft"
fi

echo "Creating PR..."
echo "Command: $CMD"
eval $CMD
