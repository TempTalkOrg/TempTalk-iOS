# Bash Usage Rules

## Blocked Patterns

### Deny List (settings.json)
Commands that cannot be used - use built-in tools instead:
- `grep`, `rg` → **Grep** tool
- `cat`, `head`, `tail` → **Read** tool
- `find` → **Glob** tool

### Hook-Blocked (block-bash-patterns.sh)
Patterns blocked by PreToolUse hook with helpful error messages:
- Heredocs (`<<`, `<<<`) → Use **Write** tool
- Pipes (`|`) → Run commands separately or use built-in tools
- Redirects (`>`, `>>`) → Use **Write** tool
- Command chains (`&&`, `;`) → Run commands separately
- `/tmp/` paths → Use `tmp/` (relative) or scratchpad
- Absolute project paths → Use relative paths (e.g., `tmp/file` not `/Users/.../tmp/file`)
- Git modifying (`commit`, `push`, `reset`...) → Use **git-workflow-enforcer** agent
  - `git merge`, `git rebase`, `git stash` are **allowed** (needed for conflict resolution and working tree management)
- GitHub CLI modifying (`gh pr create`, `gh pr merge`...) → Use **git-workflow-enforcer** agent

## Preferred Tool Mapping

| Task | Use This | Why |
|------|----------|-----|
| Search file content | `Grep` tool | Regex, context, head_limit |
| Read files | `Read` tool | Line numbers, offset support |
| Find files | `Glob` tool | Pattern matching |
| Write files | `Write` tool | No approval needed |
| Edit files | `Edit` tool | Precise replacements |

## NEVER Use `$()` Subshells Inline

Subshells can't be blocked, so this rule enforces it:

```bash
# ❌ BAD:
ls $(pwd)/src

# ✅ GOOD - use relative paths:
ls src
```
