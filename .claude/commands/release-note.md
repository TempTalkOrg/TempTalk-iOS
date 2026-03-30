# Release Notes Generation and Translation Workflow

This rule provides comprehensive guidance for generating regular release notes and translating them to Chinese.

## Release Note Generation Process

### 1. **Get Latest Official Builds - OPTIMIZED APPROACH**

**CRITICAL**: Always use the helper script to get the LATEST official builds:

```bash
# Step 1: Find latest pre_release PR
gh pr list --repo difftim/TempTalk-iOS --search "[TempTalk][pre_release]" --state open --limit 1 --json number,title

# Step 2: Get LATEST official builds using helper script (NO APPROVAL NEEDED)
# Usage: ./.claude/scripts/get-official-builds.sh <PR_NUMBER> <VERSION>
./.claude/scripts/get-official-builds.sh 3050 3.4.3
```

**Output sections:**
```
=== LATEST_TT ===   # Latest TempTalk online build comment body
```

### 2. **Build Information Extraction**
- **Version**: e.g., `3.4.3`
- **Build Number**: Timestamp format e.g., `20260111.105210`
- **TestFlight Link**: Extract from build comment

### 3. **Collect All Version Changes**

```bash
# IMPORTANT: Always fetch and use origin/develop to include latest remote commits
git fetch origin develop

# Get all commits for this version (from version bump to HEAD)
git log --after="{VERSION_START_DATE}" --pretty=format:"%s @@%an" origin/develop
```

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
[release] TempTalk-{version} build: {build_number}
{TestFlight link}
1. Bug fixes and improvements
---
{CHANGELOG_ITEMS - filtered for user-facing only}
```

**Format for each item:**
```
{number}. [{type}][{scope}] {description} (#{PR_number}) @{author}
```

## Chinese Translation Requirements

### **Header Preservation**
- Keep `[release] TempTalk-{version} build: {build_number}` unchanged
- Keep TestFlight URL unchanged
- Keep `---` divider and `1. Bug fixes and improvements` unchanged

### **Change List Translation Rules**

**PRESERVE UNCHANGED (Never Translate):**
- Item numbers, technical tags, PR numbers, author usernames
- Technical abbreviations

**MUST TRANSLATE TO SIMPLIFIED CHINESE:**
- ALL English descriptive text after the scope tag

### **Translation Quality Checklist**

1. Technical tags `[xxx][yyy]` remain in English
2. PR numbers and author usernames unchanged
3. ALL English text translated to Chinese
4. Technical terms preserved

## Final Step: Copy to Clipboard

```bash
printf '%s' "YOUR_RELEASE_NOTES_CONTENT" | pbcopy
```
