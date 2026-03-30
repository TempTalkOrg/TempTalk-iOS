# Insider Release Notes Generation and Translation Workflow

This rule provides comprehensive guidance for generating insider release notes and translating them to Chinese.

## Release Note Generation Process

### 1. **Get Latest Insider Builds - OPTIMIZED APPROACH**

**CRITICAL**: Always use the helper script to get the LATEST insider builds:

```bash
# Step 1: Find latest pre_release PR
gh pr list --repo difftim/TempTalk-iOS --search "[TempTalk][pre_release]" --state open --limit 1 --json number,title

# Step 2: Get LATEST insider builds using helper script (NO APPROVAL NEEDED)
# Usage: ./.claude/scripts/get-insider-builds.sh <PR_NUMBER> <VERSION>
./.claude/scripts/get-insider-builds.sh 3050 3.4.3
```

**Output sections:**
```
=== LATEST_TT ===              # Latest TempTalk build comment body
=== PREVIOUS_BUILD ===         # Previous build number (e.g., 20260204.010420)
=== PREVIOUS_BUILD_DATE ===    # Git-compatible ISO date (e.g., 2026-02-04T01:04:20)
```

### 2. **Build Information Extraction**
- **Version**: e.g., `3.4.3`
- **Build Number**: Timestamp format e.g., `20260205.013505`
- **TestFlight Link**: Extract from build comment

### 3. **Determine New vs History Cutoff**

Use `PREVIOUS_BUILD_DATE` from the script output to split changes:

```bash
# IMPORTANT: Always fetch and use origin/develop to include latest remote commits
git fetch origin develop

# New changes: commits AFTER the previous insider build
git log --after="{PREVIOUS_BUILD_DATE}" --pretty=format:"%s @@%an" origin/develop

# History changes: commits BEFORE the previous build, after version start
git log --before="{PREVIOUS_BUILD_DATE}" --after="{VERSION_START_DATE}" --pretty=format:"%s @@%an" origin/develop
```

**Rules:**
- **ALWAYS use `origin/develop`** (not local `develop`) - local branch may be behind remote
- Always `git fetch origin develop` before querying commits
- If `PREVIOUS_BUILD_DATE` is `N/A` (first insider build), ALL changes go in `--- New ---`

### 4. **Change Filtering - User-Facing Only**

**INCLUDE (User-facing changes):**
- `[feat]` - New features users can see or use
- `[fix]` - Bug fixes affecting user experience
- `[opt]` - Performance/UX improvements users notice
- `[ui]` - Visual/interface changes
- `[crash]` - Stability fixes users experience
- `[security]` - Security improvements

**EXCLUDE (Tech-only changes):**
- `[chore]` - Build/dependency updates
- `[rfct]`, `[refactor]` - Code refactoring
- `[CI]` - CI/CD pipeline changes
- `[dev]` - Developer tooling
- `[infra]` - Infrastructure changes
- `[agent]` - Claude agent/skill updates

### 5. **Output Format Structure**

```
TempTalk-{version} build: {build_number} [beta]
{TestFlight link}
--- New ---
{NEW_CHANGES - since last insider release}
--- History ---
{PREVIOUS_CHANGES - accumulated from earlier releases}
```

**Format for each item:**
```
{number}. [{type}][{scope}] {description} (#{PR_number}) @{author}
```

## Chinese Translation Requirements

### **Header Preservation**
- Keep `TempTalk-{version} build: {build_number} [beta]` unchanged
- Keep TestFlight URL unchanged
- Keep `--- New ---` and `--- History ---` section headers unchanged

### **Change List Translation Rules**

**PRESERVE UNCHANGED (Never Translate):**
- Item numbers, technical tags, PR numbers, author usernames
- Technical abbreviations: NPE, DNS, UIKit, SwiftUI, UI, JSON, API, OOM, etc.

**MUST TRANSLATE TO SIMPLIFIED CHINESE:**
- ALL English descriptive text after the scope tag
- Convert Traditional Chinese to Simplified Chinese

### **Translation Quality Checklist**

1. Technical tags `[xxx][yyy]` remain in English
2. PR numbers `(#xxxx)` and author usernames `@xxx` unchanged
3. ALL English text after the scope tag is translated to Chinese
4. Technical terms preserved appropriately

## Final Step: Copy to Clipboard

```bash
printf '%s' "YOUR_RELEASE_NOTES_CONTENT" | pbcopy
```
