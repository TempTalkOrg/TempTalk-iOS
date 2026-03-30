---
name: code-logic-investigate
description: |
  Code logic investigation methodology. Trace bugs, find root causes, analyze data flows.
  Reports ONLY verifiable facts - no speculation. Invoke when you need to investigate code behavior.

  Trigger keywords: "investigate code", "trace bug", "find root cause", "code flow"
user-invocable: false
---

# Code Logic Investigation

Investigate: $ARGUMENTS

## Rules

> **Read `.claude/guidelines/truth-only.md`** - the SOUL: follow truth, no speculation.

- **Every statement** needs `file.swift:line` citation + actual code snippet
- **No speculative language**: never "probably", "likely", "seems", "might"
- **If unknown**: say "I could not determine X" and list what you tried

## Investigation Process

### 1. Entry Point Identification

```
1. Identify the symptom (crash, wrong behavior, unexpected state)
2. Find where the symptom manifests in code
3. Document: file:line where issue is observable
```

Use `explore-codebase("quick: [error/feature] entry point")` to find starting location.

### 2. Backward Tracing (Root Cause)

```
Symptom → Called By → Called By → ... → Root Cause
```

For each step:
- What function calls this?
- What data is passed?
- Under what conditions?
- Document: file:line for each hop

### 3. Forward Tracing (Impact Analysis)

```
Change Point → Calls → Calls → ... → Effects
```

For each step:
- What does this function call?
- What data does it modify?
- What side effects occur?
- Document: file:line for each hop

### 4. Data Flow Analysis

```
Source → Transform → Transform → ... → Sink
```

Track: where data originates, how transformed, where consumed.

### 5. Fix Dependency Verification

When proposing a fix, verify that **all data the fix reads/depends on actually exists at the source**.

```
Fix reads X → Trace back → Where is X set? → Prove with file:line + code snippet
```

For each value the fix depends on:
- Where is it written? (`file.swift:line` with code snippet)
- Is it on the same object/dictionary/notification the fix reads from?
- Can it be nil/missing? Under what conditions?

**Example**: If a fix reads `groupId` from a notification's userInfo, verify the notification sender actually calls `userInfo[groupIdKey] = groupId` -- don't assume keys are present just because the key constant exists.

## Evidence Chain Format

Every finding MUST follow this format:

```markdown
## Finding: [What you discovered]

### Evidence Chain

1. **[Location 1]** `file.swift:123`
   ```swift
   // Actual code snippet
   ```
   -> [What this shows]

2. **[Location 2]** `file.swift:456`
   ```swift
   // Actual code snippet
   ```
   -> [What this shows]

### Conclusion
[Factual statement derived from evidence above]
```

## Investigation Types

### Bug Root Cause Analysis

```markdown
## Bug: [Description]

### Symptom
- Observed at: `file.swift:line`
- Behavior: [What happens]

### Root Cause
- Located at: `file.swift:line`
- Reason: [Why it happens - with code evidence]

### Evidence Chain
[Trace from symptom back to root cause]

### Verification
- [ ] Traced complete path from symptom to cause
- [ ] Each step has file:line reference
- [ ] No speculation - only code facts
```

### Code Behavior Analysis

```markdown
## Question: [What does X do?]

### Answer
[Factual description based on code]

### Evidence
1. Entry: `file.swift:line` - [what happens]
2. Process: `file.swift:line` - [what happens]
3. Exit: `file.swift:line` - [what happens]

### Data Flow
Input → [transformations with file:line] → Output
```

### "Why Does X Happen?" Investigation

```markdown
## Question: Why does [behavior]?

### Answer
[Behavior] occurs because:

1. At `file.swift:line`:
   ```swift
   [code that causes it]
   ```

2. This is triggered when [condition] at `file.swift:line`

3. The condition is set by [source] at `file.swift:line`

### Complete Trace
[caller] → [caller] → [function where behavior occurs]
```

## Tools

| Operation | Use For |
|-----------|---------|
| `explore-codebase("quick: ...")` | Find entry points, locate files |
| `explore-codebase("medium: ...")` | Follow relationships, understand feature |

### Search Patterns

| What to Find | How |
|--------------|-----|
| Function definition | `Grep(pattern="func functionName")` |
| Class usages | `Grep(pattern="ClassName")` |
| Variable assignments | `Grep(pattern="variableName =")` |
| Error handling | `Grep(pattern="catch.*ErrorType")` |
| Conditional logic | `Grep(pattern="if.*condition")` |

### Code Reading Strategy

1. **Start narrow**: Read only the directly relevant function
2. **Expand as needed**: Follow calls only when necessary
3. **Document as you go**: Note file:line for every finding
4. **Verify assumptions**: Don't assume - read the actual code

## Output Templates

### Quick Investigation

````markdown
**Question**: [What user asked]

**Answer**: [Factual answer]

**Evidence**: `file.swift:line` shows:
```swift
[relevant code]
```
````

### Deep Investigation

```markdown
# Investigation: [Topic]

## Summary
[1-2 sentence factual summary]

## Findings

### Finding 1: [Title]
[Evidence chain]

### Finding 2: [Title]
[Evidence chain]

## Unknown/Unverified
- [What could not be determined]
- [What needs further investigation]

## Files Examined
- `path/to/file1.swift` - [what was found]
- `path/to/file2.swift` - [what was found]
```

## Quality Checklist

Before delivering findings:
- [ ] Every statement has file:line citation with actual code snippet (verbatim, not paraphrased)
- [ ] No speculative language: never "probably", "likely", "seems", "might"
- [ ] Evidence chain is complete and traceable: Location → Code → What this shows
- [ ] Conclusions follow logically from evidence — no leaps
- [ ] "Could not determine X because Y" stated explicitly for unknowns
- [ ] Investigation examined ≥2 files (symptom location AND at least one upstream/downstream dependency)
- [ ] Root cause findings have ≥2 evidence chain steps (symptom AND cause as minimum)
- [ ] All code paths relevant to the finding documented (or noted as out of scope)
- [ ] For data-related bugs: data traced from source through transformations to where bug manifests
- [ ] For regression bugs: git log/blame checked on affected files for recent changes
- [ ] At least one concrete finding produced (not just a list of files examined)
- [ ] Files Examined section lists all files read with what was found in each
