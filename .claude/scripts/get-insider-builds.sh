#!/bin/bash
# Get latest insider/beta builds from a pre_release PR
# Separately finds latest TempTalk builds, plus previous build date for New/History cutoff
#
# Usage: ./get-insider-builds.sh <PR_NUMBER> <VERSION>
# Example: ./get-insider-builds.sh 3008 3.4.3
#
# Output sections:
#   === LATEST_TT ===              Latest TempTalk build comment
#   === PREVIOUS_BUILD ===         Previous build number (YYYYMMDD.HHMMSS)
#   === PREVIOUS_BUILD_DATE ===    Git-compatible ISO date of previous build

set -e

PR_NUMBER=$1
VERSION=$2

if [ -z "$PR_NUMBER" ] || [ -z "$VERSION" ]; then
    echo "Usage: $0 <PR_NUMBER> <VERSION>"
    exit 1
fi

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# Fetch all comments, filter for build result comments matching this version
# Build comments start with "## tt-{VERSION} build:"
gh api "repos/difftim/TempTalk-iOS/issues/${PR_NUMBER}/comments?per_page=100" --paginate \
  | jq -s 'add | [.[] | select(.body | test("^## tt-'"${VERSION}"' build:"; "i"))]' > "$TMPFILE"

# Latest TempTalk build
echo "=== LATEST_TT ==="
jq -r '
  [.[] | select(.body | test("^## tt-"; "i"))]
  | sort_by(.created_at) | reverse
  | if length > 0 then .[0].body else "No TempTalk build found" end
' "$TMPFILE"

# Get latest TempTalk build number to exclude from "previous" search
LATEST_TT_BUILD=$(jq -r '
  [.[] | select(.body | test("^## tt-"; "i")) | .body
   | capture("build: (?<b>[0-9]+\\.[0-9]+)") | .b]
  | sort | reverse | if length > 0 then .[0] else "" end
' "$TMPFILE")

# Previous build = most recent build that is NOT the current build
echo "=== PREVIOUS_BUILD ==="
PREV_BUILD=$(jq -r --arg tt "$LATEST_TT_BUILD" '
  [.[].body | capture("^## tt-[^ ]+ build: (?<build>[0-9]+\\.[0-9]+)"; "i") | .build]
  | unique | map(select(. != $tt))
  | sort | reverse
  | if length > 0 then .[0] else "N/A" end
' "$TMPFILE")
echo "$PREV_BUILD"

# Convert build number to git-compatible date (20260205.013505 -> 2026-02-05T01:35:05)
echo "=== PREVIOUS_BUILD_DATE ==="
if [ "$PREV_BUILD" != "N/A" ]; then
  DATE_PART="${PREV_BUILD%%.*}"
  TIME_PART="${PREV_BUILD##*.}"
  echo "${DATE_PART:0:4}-${DATE_PART:4:2}-${DATE_PART:6:2}T${TIME_PART:0:2}:${TIME_PART:2:2}:${TIME_PART:4:2}"
else
  echo "N/A"
fi
