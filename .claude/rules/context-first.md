# Context-First Principle

> **"Before EACH key step, actively gather enough context. Don't wait for user to provide it."**

This principle applies to ALL agents, skills, and the main Claude Code context.

## The Pattern

```
Before Step → Gather Context → Verify Enough → Then Execute
```

This applies to EVERY key step, not just the start of a task.

## Context Gathering Process

```
1. Identify what context is needed for THIS step
2. Use tools to find it:
   - explore-codebase for code/patterns
   - Read docs in docs/claude/
   - git log/blame for history
   - Check conversation history
   - Context7 MCP for library/framework documentation
3. Find 2-3 similar implementations as reference
4. Assess: Can I proceed correctly with what I found?
5. If still insufficient AFTER trying → THEN ask user (last resort)
```

## Context7 MCP Usage

When working with external libraries or frameworks, use Context7 to fetch up-to-date documentation:

```
1. Resolve library ID:
   mcp__plugin_context7_context7__resolve-library-id(libraryName="<library>")

2. Query documentation:
   mcp__plugin_context7_context7__query-docs(context7CompatibleLibraryID="<id>", topic="<topic>")
```

**When to use Context7:**
- Unfamiliar API usage (UIKit, Combine, async/await, Alamofire, etc.)
- Verifying correct API signatures before writing code
- Understanding library migration patterns (e.g., Promise → async/await)
- Checking latest best practices for a framework

**When NOT to use:**
- Project-internal code (use explore-codebase instead)
- Simple, well-known APIs you're confident about

## Self-Assessment Checklist

Before proceeding with any key step, verify:
- [ ] I have enough information to make correct decisions
- [ ] I've tried multiple sources if first attempts failed
- [ ] I can explain WHY my approach is correct (not just WHAT)
- [ ] I have specific values/examples (not generic patterns)

## Only Ask User If Gathering Fails

Output "Context Needed" **only after** exhausting your own research:

```
## 🔍 Context Needed

I've searched the codebase but couldn't determine:
1. [Specific question that tools couldn't answer]
2. [Ambiguous requirement that can't be inferred]

**What I found so far:**
- [Relevant files/patterns discovered]
- [What's still unclear]
```

## Key Behaviors

| Do This | Not This |
|---------|----------|
| Actively gather context | Passively check if context exists |
| Try multiple sources | Give up after first failure |
| Ask user as last resort | Ask user immediately |
| Gather before EACH step | Gather only at start |
| Show what you found when asking | Ask without showing research effort |
