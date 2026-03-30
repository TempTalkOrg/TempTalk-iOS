---
name: monday-tasks
description: Monday Platform task management - query my tasks, start work, update progress
allowed-tools: ToolSearch, mcp__monday__search, mcp__monday__get_board_items_page, mcp__monday__get_board_info, mcp__monday__list_workspaces, mcp__monday__change_item_column_values, mcp__monday__create_update
argument-hint: "[list|start|done|update] [task-name]"
---

# Monday Tasks Management Skill

Quick access to your Monday.com tasks across all boards.

## Arguments

User input: `$ARGUMENTS`

**Commands:**
| Command | Description | Example |
|---------|-------------|---------|
| (empty) / `list` | Show all incomplete tasks assigned to me | `/monday-tasks` |
| `start <task>` | Mark task as "Working on it" | `/monday-tasks start email link` |
| `done <task>` | Mark task as "Done" | `/monday-tasks done email link` |
| `stuck <task>` | Mark task as "Stuck" | `/monday-tasks stuck markdown table` |
| `update <task>` | Add a comment/update to task | `/monday-tasks update email link` |
| `details <task>` | Show full task details with subitems | `/monday-tasks details VIP History` |

## Workflow

### 1. Load Monday MCP Tools

First, ensure Monday tools are loaded:
```
ToolSearch("select:mcp__monday__get_board_items_page")
ToolSearch("select:mcp__monday__change_item_column_values")
```

### 2. Discover ALL Boards (⚠️ REQUIRED)

**ALWAYS dynamically discover all boards - NEVER use only cached IDs.**

```
mcp__monday__search(searchType="BOARD", limit=100)
```

This returns ALL boards the user has access to. Use the returned board IDs to query tasks.

### 3. Query My Tasks (ALL Boards)

**For EACH board from search results**, query tasks assigned to me:
```
for each board in search_results:
    mcp__monday__get_board_items_page(
      boardId=board.id,
      filters=[{"columnId": "person", "compareValue": ["assigned_to_me"], "operator": "any_of"}],
      includeColumns=true,
      limit=50
    )
```

### 4. Filter Incomplete Tasks

Filter results where status is NOT "Done" or "Done (Lived/Closed)".

### 5. Status Update Commands

**To change status:**
```
mcp__monday__change_item_column_values(
  boardId=<board_id>,
  itemId=<item_id>,
  columnValues={"status": {"label": "Working on it"}}
)
```

### 6. Add Comment/Update

```
mcp__monday__create_update(
  itemId=<item_id>,
  body="<comment text>"
)
```

## Output Format

### For `list` command:

```markdown
## My Incomplete Tasks (X total)

### To-Do / In Progress
| Board | Task | Status | Priority |
|-------|------|--------|----------|
| [Board Name] | Task name | Status | Priority |
```

### For `start` command (creates task context directory):

Creates `tmp/monday-task-[itemId]/` with TASK.md, task.json, and attachments.

### For `done/stuck` commands:

```markdown
✅ Updated: **[Task Name]**
- Board: [Board Name]
- New Status: [Status]
```

## Task Matching

When user provides partial task name:
1. Search across all my tasks
2. Use fuzzy matching on task name
3. If multiple matches, show list and ask user to clarify
4. If single match, proceed with action

## Error Handling

| Error | Action |
|-------|--------|
| No tasks found | "No incomplete tasks assigned to you." |
| Task not found | "Could not find task matching '[query]'. Try `/monday-tasks list`" |
| Multiple matches | Show all matches and ask user to be more specific |
| Update failed | Show error and suggest checking board permissions |
