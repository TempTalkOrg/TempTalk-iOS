#!/bin/bash
# Get latest official/production builds from a pre_release PR
# Finds latest TempTalk online build
#
# Usage: ./get-official-builds.sh <PR_NUMBER> <VERSION>
# Example: ./get-official-builds.sh 3008 3.4.3
#
# Output sections:
#   === LATEST_TT ===   Latest TempTalk online build comment

set -e

PR_NUMBER=$1
VERSION=$2

if [ -z "$PR_NUMBER" ] || [ -z "$VERSION" ]; then
    echo "Usage: $0 <PR_NUMBER> <VERSION>"
    exit 1
fi

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# Fetch all comments, filter for online build comments matching this version
# Build comments start with "## tt-{VERSION} build:" AND contain "online"
gh api "repos/difftim/TempTalk-iOS/issues/${PR_NUMBER}/comments?per_page=100" --paginate \
  | jq -s 'add | [.[] | select(.body | test("^## tt-'"${VERSION}"' build:"; "i")) | select(.body | test("online"; "i"))]' > "$TMPFILE"

# Latest TempTalk online build
echo "=== LATEST_TT ==="
jq -r '
  [.[] | select(.body | test("^## tt-"; "i"))]
  | sort_by(.created_at) | reverse
  | if length > 0 then .[0].body else "No TempTalk online build found" end
' "$TMPFILE"
