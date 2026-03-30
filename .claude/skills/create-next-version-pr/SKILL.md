---
name: create-next-version-pr
description: Create next version release branch and PRs.
disable-model-invocation: true
argument-hint: "<version> (e.g. 2.0.0)"
allowed-tools:
context: fork
agent: git-workflow-enforcer
---

# Create Next Version Release

Creates the next version release by preparing a release branch, bumping version numbers, and creating the necessary PRs.

**Argument (optional):** $ARGUMENTS — the target version number (e.g. `2.0.0`)

## Pre-flight Checks

Before starting, verify:

1. **Working tree is clean** — run `git status` and confirm no uncommitted changes
2. **Switch to develop** — run `git checkout develop` then `git pull origin develop` (no need to already be on develop)
3. **Read current version** — read `TempTalk.xcodeproj/project.pbxproj` and find `MARKETING_VERSION` to get the current version

### Determine target version

- **If argument provided:** use it as the target version
- **If no argument:** auto-calculate next version from current:
  - Parse current version as `major.minor.patch`
  - If **patch is 9** and **minor is 9**: increment **major**, reset minor and patch → `(major+1).0.0`
  - If **patch is 9** (minor not 9): increment **minor**, reset patch → `major.(minor+1).0`
  - Otherwise: increment **patch** → `major.minor.(patch+1)`
  - Examples: `1.9.9` → `2.0.0`, `1.8.9` → `1.9.0`, `2.3.5` → `2.3.6`

Report the current version and target version to the user before proceeding.

## Phase 1: Create Release Branch

Create and push the release branch from develop:

```bash
git checkout -b release/<version> develop
./.claude/scripts/git-push.sh origin release/<version>
```

## Phase 2: Bump Version in develop

### 2a. Create version upgrade branch

```bash
git checkout -b feature/version-upgrade-<version> develop
```

### 2b. Update version numbers

Edit `TempTalk.xcodeproj/project.pbxproj` — update all `MARKETING_VERSION` entries to the new version.

Use the Edit tool to make these changes.

### 2c. Commit, push, and create PR

```bash
git add TempTalk.xcodeproj/project.pbxproj
./.claude/scripts/git-commit-push.sh "[chore][app] Update version to <version>"
```

Create PR body using Write tool to `tmp/TEMP_PR_BODY.md`:
```
## Summary
Update app version to <version> for the next development cycle.

### Changes
- Update `MARKETING_VERSION` to `<version>` in Xcode project
```

Then create PR:
```bash
./.claude/scripts/gh-pr-create.sh "[chore][app] Update version to <version>" tmp/TEMP_PR_BODY.md develop feature/version-upgrade-<version> "krisDev000,Henry-yhz,small3flower"
rm -f tmp/TEMP_PR_BODY.md
```

Report the version bump PR URL to the user.

## Phase 3: Create Release PR

**Wait for version bump PR to be merged** by running the wait script:

```bash
${CLAUDE_SKILL_DIR}/scripts/wait-pr-merge.sh <PR_NUMBER>
```

- If the script exits successfully (PR merged), proceed immediately
- If it exits with error (closed without merge or timeout), STOP and report to user

Once merged:

```bash
git checkout develop
git pull origin develop
```

Create PR body using Write tool to `tmp/TEMP_PR_BODY.md`:
```
## Release <version>

This PR marks the beginning of the <version> release cycle.

### Status
- Version has been updated to <version>
- Development for <version> starts on this branch
- New features and bug fixes will be added throughout the development cycle

### CI Build Commands
Add these as comments to trigger builds:
- `/tt_tf` - TempTalk Beta build
- `/tt_tf online` - TempTalk Production build

### Next Steps
1. Continue development of new features and bug fixes
2. Trigger CI builds as needed for testing
3. Merge after all development is complete and approved
```

Then create PR:
```bash
./.claude/scripts/gh-pr-create.sh "[TempTalk][pre_release] <version>" tmp/TEMP_PR_BODY.md develop release/<version> "krisDev000,Henry-yhz,small3flower" "Release"
rm -f tmp/TEMP_PR_BODY.md
```

Report the release PR URL to the user.

## Phase 4: Summary

After all phases complete, report:

- Version bump PR: URL and status
- Release PR: URL
- Next steps: development continues on `release/<version>` branch

## Important Notes

- The release PR marks the **BEGINNING** of the development cycle, not the end
- The release PR body should **NOT** contain any changelog from previous versions
- **NO AI tool attributions** in any commits or PR descriptions
