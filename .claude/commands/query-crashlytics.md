---
description: Query Firebase Crashlytics for top FATAL crashes (last 30 days, latest 5 versions)
allowed-tools: ToolSearch, mcp__plugin_firebase_firebase__crashlytics_get_report, mcp__plugin_firebase_firebase__crashlytics_get_issue
---

# Query Key Crashlytics - FATAL Crashes

Query Firebase Crashlytics for top FATAL crashes from the TempTalk iOS app.

## CRITICAL: Load Tools First

**Firebase MCP tools are deferred and MUST be loaded before use.**

```
ToolSearch(query="+firebase crashlytics")
```

This loads the required tools. Without this step, API calls will fail.

## Configuration

- **App ID**: (use `firebase_list_apps` to discover)
- **Time Range**: Last 30 days
- **Error Type**: FATAL only (crashes)
- **Versions**: Latest 5 versions - ALL builds (discovered dynamically)

## Task

### Step 1: Discover Latest Versions

Use `crashlytics_get_report` with:
- `report`: `topVersions`
- `pageSize`: 50
- `filter`:
  - `intervalStartTime`: 30 days ago (ISO 8601 format)
  - `intervalEndTime`: today (ISO 8601 format)
  - `issueErrorTypes`: ["FATAL"]

From results:
1. Extract ALL unique version numbers (e.g., "3.4.2", "3.4.1")
2. Sort by semantic version (highest first)
3. Select the **latest 5 major versions**
4. Collect ALL build display names for these 5 versions

### Step 2: Query Top Issues (100 results)

Use `crashlytics_get_report` with:
- `report`: `topIssues`
- `pageSize`: **100**
- `filter`:
  - `intervalStartTime`: 30 days ago
  - `intervalEndTime`: today
  - `issueErrorTypes`: ["FATAL"]
  - `versionDisplayNames`: [all build display names from Step 1]

**IMPORTANT - Handling Large Results:**

Crashlytics results often exceed 80KB and will be saved to a file. When this happens:
- Do NOT use the `Read` tool (25K token limit will fail)
- Use the bundled `parse-crashlytics.py` script to parse the results:

```bash
python3 .claude/skills/query-crashlytics/parse-crashlytics.py "<result_file_path>"
```

### Step 3: Categorize Results

**Top Issues by Event Count**: Show top 15 issues sorted by crash count

**New/Fresh Issues**: Filter ALL 100 results for issues with:
- `SIGNAL_FRESH` - Newly appeared issues
- `SIGNAL_REGRESSED` - Previously closed, now returned

### Step 4: Format Output

```
## Top FATAL Crashes (Last 30 Days)
**Versions**: [5 versions] ([X] builds total)
**Total Issues Found**: [count]

### Top 15 by Crash Count

| # | Issue | Crashes | Users | Versions | Status |
|---|-------|---------|-------|----------|--------|

### New/Fresh Issues (SIGNAL_FRESH)

| # | Issue | Crashes | Users | First Seen | Status |
|---|-------|---------|-------|------------|--------|

### Regressed Issues (SIGNAL_REGRESSED)

| # | Issue | Crashes | Users | Regressed In | Status |
|---|-------|---------|-------|--------------|--------|
```
