---
name: explore-codebase
description: Fast codebase exploration for TempTalk iOS. Find files, search code, understand patterns and data flows. Invoke with "<level>: <query>" format where level is quick/medium/thorough. Examples: "quick: find ViewModel files", "medium: how does message sending work", "thorough: encryption flow end to end".
argument-hint: "[quick|medium|thorough]: <query>"
---

# Codebase Exploration

Explore the codebase for: $ARGUMENTS

Parse the input to extract level and query. Format: `<level>: <query>` or just `<query>` (defaults to medium).

## Exploration Levels

### Quick (2-3 searches max)

1. Use Glob to find files matching keyword: `**/*{keyword}*.swift`
2. Use Grep to search patterns: `class.*Keyword|func.*keyword`
3. Return focused file list with brief descriptions

### Medium (follow the trail)

1. Run quick searches first
2. Use Read to examine top 3-5 key files
3. Follow imports to related modules
4. Check ViewModel/Manager/Service patterns

Return file map with relationships.

### Thorough (comprehensive)

1. **Knowledge Base First**: Check `docs/claude/` for relevant docs
2. Read recommended docs from knowledge base for context
3. Search all modules with Glob and Grep
4. Try multiple naming patterns
5. Read complete implementations
6. Map data flow from entry to output

Return complete architecture understanding with knowledge base context.

## Knowledge Base Integration

**ALWAYS check the knowledge base first** for any query:

1. **Search docs/claude/**: Read available docs and find matching keywords
2. **Read relevant docs**: Based on search, read specific docs for context
3. **Then explore code**: Use the context to guide code exploration

### Quick Keyword → Doc Mapping

| Keywords | Read This Doc |
|----------|---------------|
| MVVM, ViewModel, binding | `mvvm-architecture.md` |
| async, await, concurrency | `swift-concurrency.md` |
| UI, Theme, Design | `design-principles.md` |

### Example Workflow

```
Query: "how does message sending work"

Step 1: Check docs/claude/ → finds relevant docs
Step 2: Read relevant documentation
Step 3: Search codebase: MessageSender, SendJob
Step 4: Return findings with doc context
```

## Project Modules

| Module | Purpose |
|--------|---------|
| `TempTalk/src/` | Main app, ViewControllers |
| `TTServiceKit/src/` | Core business logic |
| `TTMessaging/` | Messaging UI framework |
| `TTShareExtension/` | Share extension |
| `NSE/` | Notification Service Extension |
| `Modules/` | Custom modules |
| `Podfile` | Third-party library definitions (CocoaPods) |

## Tools

- **Glob**: Find files by pattern (`**/*ViewModel.swift`)
- **Grep**: Search code content with regex
- **Read**: Examine file content

## Output Format

```markdown
## Exploration: [Query]

**Level**: quick|medium|thorough

### Files Found
| File | Purpose | Relevance |
|------|---------|-----------|
| path/File.swift:42 | Description | High/Med/Low |

### Patterns
- Pattern (file.swift:line)

### Data Flow
[Entry] -> [Process] -> [Output]

### Next Steps
1. Recommendation
```
