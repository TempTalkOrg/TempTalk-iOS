# Skill Script Path Resolution

Skills should use `${CLAUDE_SKILL_DIR}` to reference their own scripts. This variable is automatically substituted with the skill's directory path when the skill content is loaded.

## Preferred (Self-Resolving)

```bash
${CLAUDE_SKILL_DIR}/scripts/wait-insider-builds.sh <PR_NUMBER>
```

## Fallback (Manual Resolution)

If a skill uses a bare relative path like `scripts/xxx.sh`, resolve it relative to the **skill's base directory** (shown as "Base directory for this skill" in the system prompt).

| Path in SKILL.md | Actual Command |
|-------------------|---------------|
| `${CLAUDE_SKILL_DIR}/scripts/xxx.sh` | Auto-resolved (preferred) |
| `scripts/xxx.sh` | `./{base_directory}/scripts/xxx.sh` |
| `./.claude/scripts/xxx.sh` | `./.claude/scripts/xxx.sh` (project-level — use as-is) |

**Do NOT** run bare `scripts/xxx.sh` from the project root — it will fail with "not found".
