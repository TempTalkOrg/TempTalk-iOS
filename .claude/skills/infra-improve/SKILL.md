---
name: infra-improve
description: Long-running infrastructure improvement command with built-in review-and-improve cycle. Each improvement is reviewed, problems are identified and fixed, and lessons are captured. Use "/infra-improve" to start, "/infra-improve overnight" for extended run, or "/infra-improve quick" for single cycle.
allowed-tools: Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, Bash
argument-hint: "[quick|overnight|resume]"
skills:
  - explore-codebase
hooks:
  Stop:
    - type: command
      command: "./.claude/skills/infra-improve/stop-hook.sh"
---

# Infrastructure Improvement System

> **Version**: 1.12 (2026-03-10) - Functional validation, encoded lessons
> **Changes**: Added Functional Validation sub-check to Phase 1.2, encoded operational lessons as Known Pitfalls, added taskType tracking
> **Adapted for**: TempTalk iOS

You are the Infrastructure Improvement Agent. Your mission is to continuously analyze and improve the Claude Code infrastructure for this project, making it more reliable and efficient over time.

**Mode:** $ARGUMENTS (default: quick)

## ⚠️ CRITICAL: Review-and-Improve Cycle

Every improvement MUST go through a full cycle:

```
┌─────────────────────────────────────────────────────────────────┐
│                    IMPROVEMENT CYCLE (6 Phases)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. ANALYZE ──▶ 2. PLAN ──▶ 3. EXECUTE ──▶ 4. REVIEW ──┐       │
│       ▲                                          │               │
│       │                                          ▼               │
│       │                                    5. REFINE            │
│       │                                    (Fix problems)        │
│       │                                          │               │
│       └──────────── 6. LEARN ◀──────────────────┘               │
│                    (Capture lessons)                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**DO NOT skip phases 4-6. They are what make the system improve itself.**

## ⚠️ CRITICAL: Context-First Principle

> **Read `.claude/rules/context-first.md`** - it defines the global Context-First principle.

**Key points for infra-improve:**
1. **Before EACH phase** - actively gather context, don't just check if you have it
2. **Research persistence** - If one source fails, try alternatives
3. **Verify sufficiency** - Can you explain WHY this change is correct?

## ⚠️ CRITICAL: Format Verification from Authoritative Sources

> **"Before modifying Claude Code infrastructure, verify you have the current correct format."**

### When This Applies

This applies when modifying ANY Claude Code configuration:
- CLAUDE.md files (project or user-level)
- Skill definitions (`.claude/skills/*/SKILL.md`)
- Agent configurations (`.claude/agents/*.md`)
- Hooks, commands, or any `.claude/` configuration

### How to Verify

**Step 1: Use claude-code-guide agent**
```
Task(subagent_type="claude-code-guide", prompt="What is the current correct format for [skill YAML frontmatter | agent configuration | CLAUDE.md best practices]?")
```

**Step 2: Cross-check with authoritative sources**
| Source | URL | Use For |
|--------|-----|---------|
| Official Claude Code Docs | https://code.claude.com/docs/en/ | All configuration |
| Skills Documentation | https://code.claude.com/docs/en/skills | Skill format, frontmatter |
| Best Practices Guide | https://code.claude.com/docs/en/best-practices | CLAUDE.md structure |

## State Management

Load current state from `.claude/infra-improve-state.json` if it exists. Create it if not.

```json
{
  "version": 3,
  "lastRun": "ISO timestamp",
  "iteration": 0,
  "mode": "quick|overnight",
  "phase": "analyze|plan|execute|review|refine|learn",
  "currentTask": null,
  "completedTasks": [],
  "pendingTasks": [],
  "discoveries": [],
  "reviewFindings": [],
  "lessonsLearned": [],
  "metrics": {
    "tasksCompleted": 0,
    "issuesFound": 0,
    "issuesFixed": 0,
    "lessonsRecorded": 0
  },
  "searchHistory": {},
  "lastHistoryAnalyzed": "ISO timestamp"
}
```

---

## Phase 1: ANALYZE

**Goal:** Understand current state and identify improvement opportunities.

### Mode-Specific Sub-Phases

| Sub-Phase | Quick | Overnight | Resume |
|-----------|:---:|:---------:|:------:|
| 1.1 Agent Configuration Audit | Yes | Yes | Yes |
| 1.2 Skill Effectiveness Review | Yes | Yes | Yes |
| 1.3 Context-First Compliance Audit | Yes | Yes | Yes |
| 1.4 Codebase Pattern Discovery | **Skip** | Yes | If needed |
| 1.5 Execution History Analysis | **Skip** | Yes | If needed |
| 1.6 External Knowledge Research | **Skip** | Yes | If needed |

> In **quick** mode, focus on 1.1-1.3 (structural audits) to find actionable tasks fast.
> In **overnight** mode, run all 6 sub-phases for comprehensive analysis.

**1.1 Agent Configuration Audit**
```
- Read all agents in .claude/agents/
- Check doc references point to correct locations
- Verify agent descriptions are clear
- Look for missing capabilities
```

**1.2 Skill Effectiveness Review**
```
- Review all skills in .claude/skills/
- Check for unused or redundant skills
- Identify missing utility skills
- Verify skill documentation is complete
```

**Functional Validation** (for skills with scripts):
```
For each skill that references scripts:
1. Read SKILL.md and extract script paths
2. Resolve paths per .claude/rules/skill-script-paths.md:
   - "scripts/xxx.sh" → "./{skill_base_dir}/scripts/xxx.sh"
   - "./.claude/scripts/xxx.sh" → as-is (project root)
3. Verify each script FILE EXISTS at resolved path (Glob or ls)
4. Verify each script is EXECUTABLE (ls -la)
5. Check settings.json allowlist covers the resolved path
6. If script parses external output (GitHub API, CI comments):
   - Verify regex/jq patterns match ACTUAL output format
   - Check for language mismatches (English vs Chinese text)
   - Check for case sensitivity issues in brand names
```

**1.3 Context-First Compliance Audit**

> **"Before EACH key step, agents must ACTIVELY gather enough context - not passively check or ask."**

**What to Check:**

| Component | Required Elements |
|-----------|-------------------|
| **All Agents** | "Before EACH key step, actively gather" pattern |
| **All Agents** | "How to Gather Context" table with specific tools/methods |
| **All Agents** | "Only Ask User If Gathering Fails" section (last resort) |
| **Skills** | Pre-execute context gathering step |

**1.4 Codebase Pattern Discovery**
Use `Skill("explore-codebase", args="thorough: find undocumented patterns")` to:
```
- Find code patterns not yet documented
- Discover new anti-patterns
- Identify frequently used utilities
- Map data flows not in knowledge base
```

**1.5 Execution History Analysis**

```bash
# Analyze only NEW data since last infra-improve run
./.claude/scripts/analyze-history.sh new-insights

# Full analysis
./.claude/scripts/analyze-history.sh improvement-insights 14
```

**1.6 External Knowledge Research** (Continuous Learning)

Each agent has multiple search topics. Rotate through them:

| Agent | Search Topics (rotate through) |
|-------|-------------------------------|
| bug-analyst | 1. "iOS crash debugging best practices" 2. "Swift error handling patterns" 3. "root cause analysis techniques" 4. "Xcode instruments debugging" |
| feature-analyst | 1. "technical PRD writing" 2. "requirements analysis" 3. "user story best practices" 4. "technical feasibility analysis" |
| architecture-design-specialist | 1. "iOS MVVM architecture" 2. "Swift async/await patterns" 3. "SOLID principles iOS" 4. "iOS modularization" |
| code-simplifier | 1. "Swift refactoring patterns" 2. "code smell detection" 3. "Swift idioms best practices" 4. "simplify complex code" |
| git-workflow-enforcer | 1. "git workflow best practices" 2. "PR review strategies" 3. "commit message conventions" |
| figma-ui-alignment-reviewer | 1. "figma to code verification" 2. "design implementation QA" 3. "UI pixel perfect comparison" |

---

## Phase 2: PLAN

**Goal:** Prioritize and select next improvement task.

| Priority | Type | Description |
|----------|------|-------------|
| P0 | Critical | Broken references, missing essential docs |
| P1 | High | Gaps in core functionality documentation |
| P2 | Medium | Enhancements to existing docs |
| P3 | Low | Nice-to-have improvements |

**Select ONE task** from highest priority available.

---

## Phase 3: EXECUTE

**Goal:** Complete the selected improvement task.

### Pre-Execute Context Gate

**Before writing ANY content, verify:**
```
□ Have I read the relevant existing files?
□ Have I successfully fetched external knowledge (if needed)?
□ Can I explain WHY this change is correct?
□ Do I have specific examples/values (not generic patterns)?
□ For Claude Code infra changes: Have I verified the current correct format?
```

**Save output to appropriate location.**

---

## Phase 4: REVIEW (⚠️ CRITICAL - DO NOT SKIP)

**Goal:** Deeply analyze the output quality and find problems.

### 4.1 Re-Read Output
Read the file(s) you just created or modified. Don't assume it's correct.

### 4.2 Quality Checklist

**For Documentation:**
```
□ Is the title clear and descriptive?
□ Are code examples from REAL codebase (not generic patterns)?
□ Are cross-references valid? (Glob/Read to verify each referenced file exists)
□ Is it consistent with other docs in style and depth?
□ No placeholder or generic content ("TODO", "example.com", template leftovers)?
```

**For Agent/Skill Updates:**
```
□ Are all file paths in references correct? (verify with Glob)
□ Is the description accurate for what the agent/skill actually does?
□ Are frontmatter fields correct? (name, model, skills, allowed-tools, hooks)
□ Do all referenced rules/guidelines exist? (.claude/rules/*.md, .claude/guidelines/*.md)
□ Do all referenced docs exist? (docs/claude/*.md)
□ Would it work if invoked right now? (no missing dependencies)
□ Does this change interact with other agents/skills? (check for conflicts)
□ Are iOS-specific adaptations correct? (Swift not Kotlin, UIKit not Compose, etc.)
```

### 4.3 Scoring Rubric

Score the task on a 10-point scale with specific deductions:

| Deduction | Points | Trigger |
|-----------|:------:|---------|
| Broken cross-reference | -3 | Any referenced file doesn't exist |
| Wrong frontmatter field | -2 | Invalid name, model, skills, or allowed-tools |
| Stale platform reference | -2 | Android/Kotlin/Gradle in iOS agent |
| Missing iOS adaptation | -1 | Generic content not adapted to project |
| Inconsistent style | -1 | Doesn't match other agents/docs in format |
| Incomplete section | -1 | Added section missing key content |

**Score = 10 - (sum of deductions), minimum 0.**

Record score and any findings in `reviewFindings` array of state file:
```json
{
  "taskId": 1,
  "score": 8,
  "findings": [
    { "severity": "medium", "issue": "description", "fixed": true }
  ]
}
```

---

## Phase 5: REFINE (⚠️ CRITICAL - DO NOT SKIP)

**Goal:** Fix all issues found in review before moving on.

Fix high-severity issues first, then medium, then low.

---

## Phase 6: LEARN (⚠️ CRITICAL - DO NOT SKIP)

**Goal:** Capture lessons to improve future iterations.

### 6.1 Update State
Add to `lessonsLearned` in state file. Update `metrics` counters.

### 6.2 Output Iteration Report

Output the following report format at the end of each iteration:

```markdown
## Iteration [N] Report

**Task**: [Title] (Priority: [P0-P3])
**Files Modified**: [list]
**Review Score**: [X]/10

### What Changed
- [Concise description of each change]

### Review Findings
- [Issues found during review, if any, and whether fixed]

### Lessons Learned
- [New lesson captured, if any]

### Metrics Delta
| Metric | Before | After |
|--------|--------|-------|
| Tasks Completed | X | X+1 |
| Issues Found | X | Y |
| Issues Fixed | X | Y |
```

### 6.3 Meta-Improvement Trigger
If 5+ iterations have been completed since the last `/infra-improve-meta analyze`, suggest running it to evaluate system effectiveness.

---

## Mode Behaviors

### `quick` (Default)
- Single full cycle (all 6 phases)
- Complete one improvement with review
- Update state and exit

### `overnight` (Long-running)
- Multiple iterations via **native stop hook**
- Each iteration runs all 6 phases
- Continue until all P0/P1 tasks complete or max iterations (20) reached

### `resume`
- Load state from previous run
- Continue from where stopped

---

## Key Files

| File | Purpose |
|------|---------|
| `docs/claude/` | Project documentation |
| `.claude/infra-improve-state.json` | Progress tracking |
| `.claude/agents/*.md` | Agent configurations |
| `.claude/skills/*/SKILL.md` | Skill definitions |
| `.claude/scripts/analyze-history.sh` | History analysis script |

---

## Safety Rules

1. **Never delete** - Only add or update
2. **Backup first** - Read before overwriting
3. **Small changes** - One improvement per iteration
4. **Review always** - Never skip phases 4-6
5. **Track everything** - Update state file after each phase
