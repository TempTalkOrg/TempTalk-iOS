---
name: firebase-context
description: Fetches crash/ANR data from Firebase Crashlytics API. Only use when user provides a console.firebase.google.com URL or a 32-character hex Crashlytics ID.
allowed-tools: ToolSearch, mcp__plugin_firebase_firebase__crashlytics_get_issue, mcp__plugin_firebase_firebase__crashlytics_list_events, mcp__plugin_firebase_firebase__crashlytics_get_report, mcp__plugin_firebase_firebase__firebase_list_apps
---

# Firebase Crashlytics Context Collector

Collects structured context from Firebase Crashlytics for bug analysis.

## Auto-Detection

This skill triggers when user message contains:
- Firebase console URLs: `console.firebase.google.com/*/crashlytics/*`
- Crashlytics issue IDs (hex UUID format): `dd772c1f54a84006bf94d7984ced73f9`
- Keywords: "firebase crash", "crashlytics issue", "firebase anr"

## CRITICAL: Load Tools First

**Firebase MCP tools are deferred and MUST be loaded before use.**

```
Step 0: Load Firebase tools
ToolSearch(query="+firebase crashlytics")
```

This loads: `crashlytics_get_issue`, `crashlytics_list_events`, `crashlytics_get_report`

## App ID Reference

| Bundle ID | App ID | Flavor |
|-----------|--------|--------|
| `org.nicegram.nicegram` | `1:559491788638:ios:XXXXXXXX` | WEA Production |
| `org.nicegram.nicegram.test` | (check firebase_list_apps) | WEA Development |
| `org.nicegram.nicegram.beta` | (check firebase_list_apps) | WEA Beta |

**Note**: Use `firebase_list_apps` to get the correct App ID for each bundle.

## URL Parsing

Firebase console URLs follow this pattern:
```
https://console.firebase.google.com/project/{projectId}/crashlytics/app/ios:{bundleId}/issues/{issueId}?time=...
```

Extract:
- `projectId`: e.g., `difft-45c68`
- `bundleId`: e.g., `org.nicegram.nicegram` → lookup App ID from table
- `issueId`: e.g., `dd772c1f54a84006bf94d7984ced73f9`

## Context Collection Workflow

### Step 1: Parse Input

If URL provided:
```
URL: https://console.firebase.google.com/project/difft-45c68/crashlytics/app/ios:org.nicegram.nicegram/issues/dd772c1f54a84006bf94d7984ced73f9

Extracted:
- bundleId: org.nicegram.nicegram
- issueId: dd772c1f54a84006bf94d7984ced73f9
- appId: (lookup from firebase_list_apps)
```

### Step 2: Get Issue Details

```
crashlytics_get_issue(
  appId: "<app_id_from_lookup>",
  issueId: "dd772c1f54a84006bf94d7984ced73f9"
)
```

This returns:
- Issue title (class/method where crash occurred)
- Error type (FATAL, NON_FATAL, ANR)
- Subtitle (exception message)
- First/last seen timestamps
- Event count, impacted users
- Affected versions
- Issue signals (FRESH, REGRESSED, etc.)

### Step 3: Get Stacktraces (Events)

```
crashlytics_list_events(
  appId: "<app_id_from_lookup>",
  filter: {
    issueId: "dd772c1f54a84006bf94d7984ced73f9"
  },
  pageSize: 3
)
```

This returns sample events with:
- Full stacktrace
- Device info (model, iOS version)
- App state at crash time
- Custom keys/logs if set

### Step 4: Output Structured Context

````markdown
## Firebase Crashlytics Context

### Issue Summary
- **Type**: [FATAL/ANR/NON_FATAL]
- **Title**: [class.method where crash occurred]
- **Message**: [exception message]
- **Issue ID**: [id]
- **Status**: [OPEN/CLOSED] [signals: FRESH/REGRESSED]

### Impact
- **Events**: [count] crashes
- **Users Affected**: [count]
- **First Seen**: [date] (version [x.y.z])
- **Last Seen**: [date] (version [x.y.z])
- **Affected Versions**: [list]

### Stacktrace
```
[Full stacktrace from most recent event]
```

### Device Context (from sample events)
| Device | OS | App Version | Timestamp |
|--------|-------|-------------|-----------|
| [model] | iOS [version] | [app version] | [time] |

### Key Observations
- [Notable patterns in stacktrace]
- [Relevant device/version patterns]
- [Any custom keys/logs]
````

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| "Tool not found" | Deferred tools not loaded | Run `ToolSearch(query="+firebase crashlytics")` first |
| "Issue not found" | Invalid issueId | Verify URL/ID is correct |
| "Permission denied" | Not logged in | Run `firebase_login` first |
| "App not found" | Bundle not in Firebase | Check firebase_list_apps for registered apps |

## Integration with tech-product-analyst

After collecting context, pass to tech-product-analyst for:
- Root cause analysis
- Impact assessment
- Fix approach recommendation
- Priority determination

The structured output format is designed for tech-product-analyst to parse and analyze.
