#!/bin/bash
# Branch Cleanup Helper for TempTalk iOS
# Identifies and optionally deletes local branches that have been merged into develop
# Usage: cleanup.sh [--confirm]
#
# By default runs in dry-run mode. Use --confirm to actually delete branches.
#
# Deletes branches that match ANY of these criteria:
# 1. PR merged (squash, merge commit, or rebase)
# 2. PR closed without merge
# 3. Git-merged directly into develop (no PR)
# 4. Release branches that have been merged

set -e

CONFIRM=false
if [ "$1" = "--confirm" ]; then
    CONFIRM=true
    echo "CONFIRM MODE - Branches will be deleted"
else
    echo "DRY RUN MODE - No branches will be deleted (use --confirm to delete)"
fi
echo ""

# Ensure we're on develop and up to date
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "develop" ]; then
    echo "Switching to develop branch..."
    git checkout develop
fi

# Fetch and prune stale remote-tracking refs (inspired by CIA leaked git tips)
echo "Fetching remote and pruning stale refs..."
git fetch --prune origin
git merge --ff-only origin/develop 2>/dev/null || true

echo "Fetching branch data..."

# Create tmp directory for intermediate files
mkdir -p ./tmp

# Get merged PR branch names (all merge types: squash, merge commit, rebase)
gh pr list --state merged --limit 2000 --json headRefName -q '.[].headRefName' | \
    sort -u > ./tmp/pr_merged_branches.txt
PR_MERGED_COUNT=$(wc -l < ./tmp/pr_merged_branches.txt | tr -d ' ')

# Get closed (not merged) PR branch names
gh pr list --state closed --limit 2000 --json headRefName -q '.[].headRefName' | \
    sort -u > ./tmp/pr_closed_branches.txt
PR_CLOSED_COUNT=$(wc -l < ./tmp/pr_closed_branches.txt | tr -d ' ')

# Get git-merged branches (check against remote origin/develop for accuracy)
# Note: Use [[:space:]] instead of [ \t] for macOS/BSD sed compatibility
git branch --merged origin/develop | grep -v "^\*" | grep -v "develop" | grep -v "main" | \
    sed 's/^[[:space:]]*//' | sort -u > ./tmp/git_merged_branches.txt
GIT_MERGED_COUNT=$(wc -l < ./tmp/git_merged_branches.txt | tr -d ' ')

echo "Found $PR_MERGED_COUNT PR-merged branches"
echo "Found $PR_CLOSED_COUNT PR-closed branches"
echo "Found $GIT_MERGED_COUNT git-merged branches (into develop)"

# Get ALL local branches (excluding only current branch and develop/main)
# Note: Use [[:space:]] instead of [ \t] for macOS/BSD sed compatibility
git branch | grep -v "^\*" | grep -v "^  develop$" | grep -v "^  main$" | \
    sed 's/^[[:space:]]*//' | sort > ./tmp/local_branches.txt

LOCAL_COUNT=$(wc -l < ./tmp/local_branches.txt | tr -d ' ')
echo "Found $LOCAL_COUNT local branches (including release/*)"

# === Categorize deletable branches ===

# 1. PR-merged branches
DELETABLE_PR_MERGED=$(comm -12 ./tmp/local_branches.txt ./tmp/pr_merged_branches.txt)
if [ -z "$DELETABLE_PR_MERGED" ]; then
    PR_MERGED_DELETE_COUNT=0
else
    PR_MERGED_DELETE_COUNT=$(echo "$DELETABLE_PR_MERGED" | wc -l | tr -d ' ')
fi

# 2. PR-closed branches (excluding PR-merged to avoid duplicates)
DELETABLE_PR_CLOSED=$(comm -12 ./tmp/local_branches.txt ./tmp/pr_closed_branches.txt | \
    comm -23 - ./tmp/pr_merged_branches.txt)
if [ -z "$DELETABLE_PR_CLOSED" ]; then
    PR_CLOSED_DELETE_COUNT=0
else
    PR_CLOSED_DELETE_COUNT=$(echo "$DELETABLE_PR_CLOSED" | wc -l | tr -d ' ')
fi

# 3. Git-merged branches (excluding PR-merged and PR-closed to avoid duplicates)
DELETABLE_GIT_MERGED=$(comm -12 ./tmp/local_branches.txt ./tmp/git_merged_branches.txt | \
    comm -23 - ./tmp/pr_merged_branches.txt | \
    comm -23 - ./tmp/pr_closed_branches.txt)
if [ -z "$DELETABLE_GIT_MERGED" ]; then
    GIT_MERGED_DELETE_COUNT=0
else
    GIT_MERGED_DELETE_COUNT=$(echo "$DELETABLE_GIT_MERGED" | wc -l | tr -d ' ')
fi

TOTAL_DELETE_COUNT=$((PR_MERGED_DELETE_COUNT + PR_CLOSED_DELETE_COUNT + GIT_MERGED_DELETE_COUNT))

echo ""
echo "Branches safe to delete ($TOTAL_DELETE_COUNT total):"
echo "========================================"

if [ "$PR_MERGED_DELETE_COUNT" -gt 0 ]; then
    echo ""
    echo "PR MERGED ($PR_MERGED_DELETE_COUNT):"
    echo "$DELETABLE_PR_MERGED" | while read -r branch; do
        echo "  ✓ $branch"
    done
fi

if [ "$PR_CLOSED_DELETE_COUNT" -gt 0 ]; then
    echo ""
    echo "PR CLOSED ($PR_CLOSED_DELETE_COUNT):"
    echo "$DELETABLE_PR_CLOSED" | while read -r branch; do
        echo "  ✗ $branch"
    done
fi

if [ "$GIT_MERGED_DELETE_COUNT" -gt 0 ]; then
    echo ""
    echo "GIT MERGED (no PR) ($GIT_MERGED_DELETE_COUNT):"
    echo "$DELETABLE_GIT_MERGED" | while read -r branch; do
        echo "  ⊕ $branch"
    done
fi

if [ "$TOTAL_DELETE_COUNT" -eq 0 ]; then
    echo "(none found)"
fi

# Perform deletion if confirmed
if [ "$CONFIRM" = true ] && [ "$TOTAL_DELETE_COUNT" -gt 0 ]; then
    echo ""
    echo "Deleting branches..."

    if [ -n "$DELETABLE_PR_MERGED" ]; then
        echo "$DELETABLE_PR_MERGED" | while read -r branch; do
            if [ -n "$branch" ]; then
                git branch -D "$branch" && echo "  Deleted (PR merged): $branch"
            fi
        done
    fi

    if [ -n "$DELETABLE_PR_CLOSED" ]; then
        echo "$DELETABLE_PR_CLOSED" | while read -r branch; do
            if [ -n "$branch" ]; then
                git branch -D "$branch" && echo "  Deleted (PR closed): $branch"
            fi
        done
    fi

    if [ -n "$DELETABLE_GIT_MERGED" ]; then
        echo "$DELETABLE_GIT_MERGED" | while read -r branch; do
            if [ -n "$branch" ]; then
                # Use -d (safe delete) for git-merged branches — guaranteed merged, no force needed
                git branch -d "$branch" && echo "  Deleted (git merged): $branch"
            fi
        done
    fi

    echo ""
    echo "Cleanup complete!"
elif [ "$TOTAL_DELETE_COUNT" -gt 0 ]; then
    echo ""
    echo "To delete these branches, run: ./.claude/skills/local-branch-cleanup/scripts/cleanup.sh --confirm"
fi

# Cleanup temp files
rm -f ./tmp/pr_merged_branches.txt ./tmp/pr_closed_branches.txt ./tmp/git_merged_branches.txt ./tmp/local_branches.txt
