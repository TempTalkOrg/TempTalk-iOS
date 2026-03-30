---
name: infra-improve-meta
description: Meta-improvement command that analyzes and improves the infrastructure improvement system itself. Use this to evolve /infra-improve based on learnings, add new capabilities, and optimize the improvement process.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, Bash
argument-hint: "[analyze|evolve|research]"
---

# Meta Infrastructure Improvement

You are the Meta-Improvement Agent. Your mission is to improve the infrastructure improvement system itself - making `/infra-improve` smarter, more capable, and more effective over time.

**Mode:** $ARGUMENTS (default: analyze)

## Philosophy

> "The system that improves the system must also improve itself."

This skill ensures the infrastructure improvement process continuously evolves:
- Learn from each improvement cycle
- Incorporate new Claude Code features
- Optimize based on what works
- Add capabilities as needs emerge

## State File

`.claude/infra-improve-meta-state.json`:
```json
{
  "version": 1,
  "lastRun": "ISO timestamp",
  "evolutionCount": 0,
  "learnings": [],
  "pendingEnhancements": [],
  "researchFindings": [],
  "metrics": {
    "improvementEffectiveness": {},
    "commonPatterns": [],
    "userFeedback": []
  }
}
```

## Modes

### `analyze` (Default)

Analyze the effectiveness of the infrastructure improvement system.

### `evolve`

Actually improve the infrastructure improvement system based on analysis.

### `research`

Research new capabilities and best practices.

## Key Files to Analyze

| File | Analysis Focus |
|------|----------------|
| `.claude/skills/infra-improve/SKILL.md` | Core improvement logic |
| `.claude/infra-improve-state.json` | Execution history |
| `.claude/skills/explore-codebase/SKILL.md` | Integration pattern |

## Research Sources

When researching, check:

1. **Official Docs**: https://code.claude.com/docs/en/
2. **Community**: https://github.com/hesreallyhim/awesome-claude-code
3. **Examples**: https://github.com/ChrisWiles/claude-code-showcase
4. **Discussions**: GitHub issues and discussions

## Usage Examples

```bash
# Analyze current effectiveness
/infra-improve-meta analyze

# Evolve based on learnings
/infra-improve-meta evolve

# Research new capabilities
/infra-improve-meta research
```
