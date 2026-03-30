#!/bin/bash
# History Analysis Script v2
# Reads from Claude Code's existing history storage
# Timeline-aware: filters by agent/skill version changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Derive Claude project dir from PROJECT_DIR (replaces / with -)
CLAUDE_PROJECT_DIR="$HOME/.claude/projects/$(echo "$PROJECT_DIR" | tr '/' '-')"
AGENTS_DIR="${PROJECT_DIR}/.claude/agents"
SKILLS_DIR="${PROJECT_DIR}/.claude/skills"

ACTION="${1:-help}"
DAYS="${2:-7}"
SINCE="${3:-}"  # Optional: only analyze data after this ISO timestamp

# State file for tracking last analyzed timestamp
STATE_FILE="${PROJECT_DIR}/.claude/infra-improve-state.json"

# Get last analyzed timestamp from state
get_last_analyzed() {
  if [[ -f "$STATE_FILE" ]]; then
    jq -r '.lastHistoryAnalyzed // ""' "$STATE_FILE" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# Update last analyzed timestamp in state
update_last_analyzed() {
  local new_ts="$1"
  if [[ -f "$STATE_FILE" ]]; then
    local tmp_file="${STATE_FILE}.tmp"
    jq --arg ts "$new_ts" '.lastHistoryAnalyzed = $ts' "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
  fi
}

# Get file modification timestamp (seconds since epoch)
get_mtime() {
  local file="$1"
  if [[ -f "$file" ]]; then
    stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# Get ISO date from epoch seconds
epoch_to_iso() {
  date -r "$1" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -d "@$1" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null
}

# Get epoch from ISO date (handles both with and without milliseconds)
iso_to_epoch() {
  local ts="${1%.*}Z"  # Remove milliseconds if present
  ts="${ts/Z/}"        # Remove trailing Z
  ts="${ts}Z"          # Add it back consistently
  date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null || echo 0
}

case "$ACTION" in
  "sessions")
    # List recent sessions with metadata
    CUTOFF=$(date -v-${DAYS}d -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -d "-$DAYS days" -u +%Y-%m-%dT%H:%M:%SZ)
    jq --arg cutoff "$CUTOFF" '
      .entries |
      map(select(.modified > $cutoff)) |
      sort_by(.modified) |
      reverse |
      map({
        sessionId: .sessionId,
        summary: .summary,
        firstPrompt: (.firstPrompt | if length > 80 then .[0:80] + "..." else . end),
        messageCount: .messageCount,
        modified: .modified,
        gitBranch: .gitBranch
      })
    ' "$CLAUDE_PROJECT_DIR/sessions-index.json" 2>/dev/null || echo "[]"
    ;;

  "agents-list")
    # List all agent transcript files with metadata
    echo "["
    first=true
    for f in "$CLAUDE_PROJECT_DIR"/agent-*.jsonl; do
      [[ -f "$f" ]] || continue
      agent_id=$(basename "$f" .jsonl | sed 's/agent-//')
      file_mtime=$(get_mtime "$f")
      file_size=$(stat -f %z "$f" 2>/dev/null || stat -c %s "$f" 2>/dev/null || echo 0)
      line_count=$(wc -l < "$f" | tr -d ' ')

      # Get agent type from first line if possible
      agent_type=$(head -1 "$f" 2>/dev/null | jq -r '.agentType // .subagentType // "unknown"' 2>/dev/null || echo "unknown")
      session_id=$(head -1 "$f" 2>/dev/null | jq -r '.sessionId // "unknown"' 2>/dev/null || echo "unknown")
      timestamp=$(head -1 "$f" 2>/dev/null | jq -r '.timestamp // ""' 2>/dev/null || echo "")

      [[ "$first" == "true" ]] || echo ","
      first=false

      jq -n \
        --arg id "$agent_id" \
        --arg type "$agent_type" \
        --arg session "$session_id" \
        --arg ts "$timestamp" \
        --argjson lines "$line_count" \
        --argjson size "$file_size" \
        '{
          agentId: $id,
          agentType: $type,
          sessionId: $session,
          timestamp: $ts,
          messageCount: $lines,
          fileSize: $size
        }'
    done
    echo "]"
    ;;

  "agent-versions")
    # Show agent definition modification times
    echo "{"
    echo "  \"agents\": {"
    first=true
    for f in "$AGENTS_DIR"/*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f" .md)
      mtime=$(get_mtime "$f")
      mtime_iso=$(epoch_to_iso "$mtime")

      [[ "$first" == "true" ]] || echo ","
      first=false

      printf '    "%s": {"modified": "%s", "epoch": %d}' "$name" "$mtime_iso" "$mtime"
    done
    echo ""
    echo "  },"
    echo "  \"skills\": {"
    first=true
    for f in "$SKILLS_DIR"/*/SKILL.md; do
      [[ -f "$f" ]] || continue
      name=$(dirname "$f" | xargs basename)
      mtime=$(get_mtime "$f")
      mtime_iso=$(epoch_to_iso "$mtime")

      [[ "$first" == "true" ]] || echo ","
      first=false

      printf '    "%s": {"modified": "%s", "epoch": %d}' "$name" "$mtime_iso" "$mtime"
    done
    echo ""
    echo "  }"
    echo "}"
    ;;

  "recent-agents")
    # List agent executions from last N days, with version awareness
    CUTOFF_EPOCH=$(( $(date +%s) - DAYS * 86400 ))

    echo "["
    first=true
    for f in "$CLAUDE_PROJECT_DIR"/agent-*.jsonl; do
      [[ -f "$f" ]] || continue

      # Get timestamp from first line
      timestamp=$(head -1 "$f" 2>/dev/null | jq -r '.timestamp // ""' 2>/dev/null || echo "")
      [[ -z "$timestamp" ]] && continue

      ts_epoch=$(iso_to_epoch "$timestamp")
      [[ "$ts_epoch" -lt "$CUTOFF_EPOCH" ]] && continue

      agent_id=$(basename "$f" .jsonl | sed 's/agent-//')
      line_count=$(wc -l < "$f" | tr -d ' ')

      # Extract more details
      first_line=$(jq -s '.[0]' "$f" 2>/dev/null)
      agent_type=$(echo "$first_line" | jq -r '.agentType // .subagentType // "subagent"' 2>/dev/null || echo "subagent")
      session_id=$(echo "$first_line" | jq -r '.sessionId // "unknown"' 2>/dev/null || echo "unknown")
      # Try to extract agent purpose from first message
      first_prompt=$(echo "$first_line" | jq -r '.message.content // ""' 2>/dev/null | head -c 100 || echo "")

      # Get last line for duration estimate
      last_ts=$(tail -1 "$f" 2>/dev/null | jq -r '.timestamp // ""' 2>/dev/null || echo "")

      [[ "$first" == "true" ]] || echo ","
      first=false

      jq -n \
        --arg id "$agent_id" \
        --arg type "$agent_type" \
        --arg session "$session_id" \
        --arg start "$timestamp" \
        --arg end "$last_ts" \
        --arg prompt "$first_prompt" \
        --argjson messages "$line_count" \
        '{
          agentId: $id,
          agentType: $type,
          sessionId: $session,
          startTime: $start,
          endTime: $end,
          messageCount: $messages,
          firstPrompt: $prompt
        }'
    done
    echo "]"
    ;;

  "agent-stats")
    # Aggregate stats for agent types (recent only)
    $0 recent-agents "$DAYS" | jq '
      group_by(.agentType) |
      map({
        agentType: .[0].agentType,
        executionCount: length,
        totalMessages: (map(.messageCount) | add),
        avgMessages: (map(.messageCount) | add / length | floor)
      }) |
      sort_by(-.executionCount)
    '
    ;;

  "version-filtered")
    # Show only executions AFTER the current agent/skill version was created
    VERSIONS=$($0 agent-versions)
    RECENT=$($0 recent-agents "$DAYS")

    echo "$RECENT" | jq --argjson versions "$VERSIONS" '
      map(
        . as $exec |
        ($versions.agents[$exec.agentType].epoch // 0) as $agent_mtime |
        ($exec.startTime | fromdateiso8601) as $exec_time |
        select($exec_time > $agent_mtime) |
        . + {versionValid: true, agentModified: ($agent_mtime | todate)}
      )
    '
    ;;

  "summary")
    echo "=== Claude Code History Analysis (Last $DAYS days) ==="
    echo ""
    echo "--- Recent Sessions ---"
    $0 sessions "$DAYS" | jq -r '.[0:5] | .[] | "[\(.modified[0:10])] \(.summary // .firstPrompt)"'
    echo ""
    echo "--- Agent Types Used (Current Session) ---"
    CURRENT_SESSION=$(ls -t "$CLAUDE_PROJECT_DIR"/*.jsonl 2>/dev/null | grep -v agent- | head -1 | xargs basename 2>/dev/null | sed 's/.jsonl//')
    if [[ -n "$CURRENT_SESSION" ]]; then
      $0 agent-type-mapping "$CURRENT_SESSION" 2>/dev/null | jq -r 'group_by(.subagentType) | map({type: .[0].subagentType, count: length}) | sort_by(-.count) | .[] | "\(.type): \(.count) runs"'
    fi
    echo ""
    echo "--- Agent/Skill Versions ---"
    $0 agent-versions | jq -r '.agents | to_entries | .[] | "\(.key): \(.value.modified[0:10])"'
    ;;

  "json")
    # Full JSON export for infra-improve
    echo "{"
    echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"period_days\": $DAYS,"
    echo "  \"sessions\": $($0 sessions "$DAYS"),"
    echo "  \"agent_stats\": $($0 agent-stats "$DAYS"),"
    echo "  \"agent_versions\": $($0 agent-versions),"
    echo "  \"version_filtered_executions\": $($0 version-filtered "$DAYS")"
    echo "}"
    ;;

  "agent-type-mapping")
    SESSION_ID="${2:-}"
    if [[ -z "$SESSION_ID" ]]; then
      echo "Usage: $0 agent-type-mapping <session-id>"
      exit 1
    fi

    SESSION_FILE="$CLAUDE_PROJECT_DIR/$SESSION_ID.jsonl"
    if [[ ! -f "$SESSION_FILE" ]]; then
      echo "Session file not found: $SESSION_FILE"
      exit 1
    fi

    TOOL_USES=$(jq -r 'select(.message.content | type == "array") | .message.content[] | select(.type == "tool_use" and .name == "Task") | "\(.id)|\(.input.subagent_type)|\(.input.description[0:60])"' "$SESSION_FILE" 2>/dev/null)
    TOOL_RESULTS=$(jq -r 'select(.message.content | type == "array") | .message.content[] | select(.type == "tool_result") | select(.content | type == "array") | select(.content | any(.text | test("agentId:"))) | "\(.tool_use_id)|\(.content | map(select(.text | test("agentId:"))) | .[0].text | capture("agentId: (?<id>[a-z0-9]+)").id)"' "$SESSION_FILE" 2>/dev/null)

    echo "["
    first=true
    while IFS='|' read -r tool_id agent_id; do
      [[ -z "$tool_id" ]] && continue
      match=$(echo "$TOOL_USES" | grep "^$tool_id|" 2>/dev/null || echo "")
      if [[ -n "$match" ]]; then
        subagent_type=$(echo "$match" | cut -d'|' -f2)
        description=$(echo "$match" | cut -d'|' -f3)
        [[ "$first" == "true" ]] || echo ","
        first=false
        jq -n --arg id "$agent_id" --arg type "$subagent_type" --arg desc "$description" \
          '{agentId: $id, subagentType: $type, description: $desc}'
      fi
    done <<< "$TOOL_RESULTS"
    echo "]"
    ;;

  "corrections")
    if [[ -n "$SINCE" ]]; then
      CUTOFF_TS="$SINCE"
    else
      CUTOFF_TS=$(date -v-${DAYS}d -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -d "-$DAYS days" -u +%Y-%m-%dT%H:%M:%SZ)
    fi

    jq -s --arg cutoff "$CUTOFF_TS" '
      [.[] |
        select(.timestamp > $cutoff) |
        select(.type == "user") |
        select(.message.content | type == "string") |
        select(.message.content | test("^This session is being continued") | not) |
        select(.message.content | test("^<system-reminder>") | not) |
        select(.message.content | test("(?i)(^no[,. ]|^dont |dont use|thats wrong|actually,|instead of|should be .+ not|fix this|thats not right)")) |
        {
          timestamp: .timestamp,
          content: (.message.content | .[0:200])
        }
      ] | .[0:20]
    ' "$CLAUDE_PROJECT_DIR"/*.jsonl 2>/dev/null || echo "[]"
    ;;

  "positive-feedback")
    if [[ -n "$SINCE" ]]; then
      CUTOFF_TS="$SINCE"
    else
      CUTOFF_TS=$(date -v-${DAYS}d -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -d "-$DAYS days" -u +%Y-%m-%dT%H:%M:%SZ)
    fi

    jq -s --arg cutoff "$CUTOFF_TS" '
      [.[] |
        select(.timestamp > $cutoff) |
        select(.type == "user") |
        select(.message.content | type == "string") |
        select(.message.content | test("(?i)^(perfect|great|excellent|good job|nice|awesome|thanks|thank you|well done|exactly|correct|yes|lgtm)")) |
        {
          timestamp: .timestamp,
          content: (.message.content | .[0:100])
        }
      ] | .[0:20]
    ' "$CLAUDE_PROJECT_DIR"/*.jsonl 2>/dev/null || echo "[]"
    ;;

  "repeated-patterns")
    echo "Analyzing repeated patterns in last $DAYS days..."
    jq -rs '
      [.[] | select(.type == "user") | select(.message.content | type == "string") | .message.content] |
      map(select(length > 20 and length < 500)) |
      map(gsub("[^a-zA-Z ]"; "") | ascii_downcase | split(" ") | map(select(length > 3)) | .[0:5] | join(" ")) |
      group_by(.) |
      map(select(length >= 2)) |
      map({pattern: .[0], count: length}) |
      sort_by(-.count) |
      .[0:10]
    ' "$CLAUDE_PROJECT_DIR"/*.jsonl 2>/dev/null || echo "[]"
    ;;

  "improvement-insights")
    corrections_data=$($0 corrections "$DAYS" 2>/dev/null || echo "[]")
    corrections_count=$(echo "$corrections_data" | jq 'length' 2>/dev/null || echo 0)

    positive_data=$($0 positive-feedback "$DAYS" 2>/dev/null || echo "[]")
    positive_count=$(echo "$positive_data" | jq 'length' 2>/dev/null || echo 0)

    sessions_data=$($0 sessions "$DAYS" 2>/dev/null || echo "[]")
    session_count=$(echo "$sessions_data" | jq 'length' 2>/dev/null || echo 0)

    CURRENT_SESSION=$(ls -t "$CLAUDE_PROJECT_DIR"/*.jsonl 2>/dev/null | grep -v agent- | head -1 | xargs basename 2>/dev/null | sed 's/.jsonl//')
    if [[ -n "$CURRENT_SESSION" ]]; then
      agent_usage=$($0 agent-type-mapping "$CURRENT_SESSION" 2>/dev/null | jq 'group_by(.subagentType) | map({type: .[0].subagentType, count: length}) | sort_by(-.count)' 2>/dev/null || echo "[]")
    else
      agent_usage="[]"
    fi

    if [[ "$session_count" -gt 0 && "$corrections_count" =~ ^[0-9]+$ ]]; then
      quality_score=$(echo "scale=0; 100 - ($corrections_count * 100 / $session_count)" | bc 2>/dev/null || echo "N/A")
    else
      quality_score="N/A"
    fi

    recommendations="[]"
    if [[ "$corrections_count" =~ ^[0-9]+$ && "$corrections_count" -gt 3 ]]; then
      recommendations=$(jq -n --arg count "$corrections_count" '[{priority: "high", type: "corrections", message: "\($count) corrections detected - review agent/skill prompts"}]')
    fi

    jq -n \
      --arg generated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson days "$DAYS" \
      --argjson corrections_count "$corrections_count" \
      --argjson recent_corrections "$(echo "$corrections_data" | jq '.[0:5]' 2>/dev/null || echo '[]')" \
      --argjson positive_count "$positive_count" \
      --argjson agent_usage "$agent_usage" \
      --argjson session_count "$session_count" \
      --arg quality_score "$quality_score" \
      --argjson recommendations "$recommendations" \
      '{
        generated_at: $generated,
        period_days: $days,
        corrections_count: $corrections_count,
        recent_corrections: $recent_corrections,
        positive_feedback_count: $positive_count,
        agent_usage: $agent_usage,
        session_count: $session_count,
        quality_score: $quality_score,
        recommendations: $recommendations
      }'
    ;;

  "new-insights")
    LAST_ANALYZED=$(get_last_analyzed)
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [[ -z "$LAST_ANALYZED" ]]; then
      echo "No previous analysis found. Running full analysis for last $DAYS days..."
      SINCE=""
    else
      echo "Last analyzed: $LAST_ANALYZED"
      echo "Analyzing only NEW data since then..."
      SINCE="$LAST_ANALYZED"
    fi

    export SINCE
    corrections_data=$($0 corrections "$DAYS" "$SINCE" 2>/dev/null || echo "[]")
    corrections_count=$(echo "$corrections_data" | jq 'length' 2>/dev/null || echo 0)

    positive_data=$($0 positive-feedback "$DAYS" "$SINCE" 2>/dev/null || echo "[]")
    positive_count=$(echo "$positive_data" | jq 'length' 2>/dev/null || echo 0)

    if [[ -n "$SINCE" ]]; then
      new_sessions=$(jq --arg cutoff "$SINCE" '.entries | map(select(.modified > $cutoff)) | length' "$CLAUDE_PROJECT_DIR/sessions-index.json" 2>/dev/null || echo 0)
    else
      new_sessions=$(jq '.entries | length' "$CLAUDE_PROJECT_DIR/sessions-index.json" 2>/dev/null || echo 0)
    fi

    update_last_analyzed "$NOW"

    jq -n \
      --arg generated "$NOW" \
      --arg since "${LAST_ANALYZED:-never}" \
      --argjson new_corrections "$corrections_count" \
      --argjson recent_corrections "$(echo "$corrections_data" | jq '.[0:5]' 2>/dev/null || echo '[]')" \
      --argjson new_positive "$positive_count" \
      --argjson new_sessions "$new_sessions" \
      '{
        generated_at: $generated,
        analyzed_since: $since,
        new_corrections: $new_corrections,
        recent_corrections: $recent_corrections,
        new_positive_feedback: $new_positive,
        new_sessions: $new_sessions,
        note: "Only analyzing data since last infra-improve run"
      }'
    ;;

  "all-agent-types")
    echo "["
    first=true
    for session_file in "$CLAUDE_PROJECT_DIR"/*.jsonl; do
      [[ -f "$session_file" ]] || continue
      [[ "$session_file" == *"agent-"* ]] && continue

      session_id=$(basename "$session_file" .jsonl)
      mappings=$($0 agent-type-mapping "$session_id" 2>/dev/null | jq -c '.[]' 2>/dev/null)
      while IFS= read -r mapping; do
        [[ -z "$mapping" ]] && continue
        [[ "$first" == "true" ]] || echo ","
        first=false
        echo "$mapping" | jq -c ". + {sessionId: \"$session_id\"}"
      done <<< "$mappings"
    done
    echo "]"
    ;;

  "read-agent")
    AGENT_ID="${2:-}"
    if [[ -z "$AGENT_ID" ]]; then
      echo "Usage: $0 read-agent <agent-id>"
      exit 1
    fi

    AGENT_FILE="$CLAUDE_PROJECT_DIR/agent-$AGENT_ID.jsonl"
    if [[ ! -f "$AGENT_FILE" ]]; then
      echo "Agent transcript not found: $AGENT_FILE"
      exit 1
    fi

    jq -s '
      map({
        type: .type,
        timestamp: .timestamp,
        content: (
          if .type == "user" then
            .message.content | if type == "string" then .[0:200] else .[0].text[0:200] end
          elif .type == "assistant" then
            .message.content | map(select(.type == "text")) | .[0].text[0:200] // "no text"
          else
            "tool_use"
          end
        )
      })
    ' "$AGENT_FILE"
    ;;

  *)
    echo "Usage: $0 <action> [days|session-id] [since-timestamp]"
    echo ""
    echo "Actions (Data Collection):"
    echo "  sessions             - List recent sessions with summaries"
    echo "  agents-list          - List all agent transcript files"
    echo "  recent-agents        - List agent executions from last N days"
    echo "  agent-type-mapping   - Extract agent-id to type mapping from a session"
    echo "  all-agent-types      - Build complete agent type mapping from all sessions"
    echo "  read-agent <id>      - Read specific agent transcript"
    echo ""
    echo "Actions (Analysis - inspired by claude-reflect):"
    echo "  corrections          - Detect user corrections ('no', 'don't', 'wrong')"
    echo "  positive-feedback    - Detect positive feedback ('great', 'perfect')"
    echo "  repeated-patterns    - Find repeated requests (skill candidates)"
    echo "  improvement-insights - Combined insights with recommendations"
    echo "  new-insights         - INCREMENTAL: Only analyze NEW data since last run"
    echo ""
    echo "Actions (Version Awareness):"
    echo "  agent-versions       - Show agent/skill definition modification times"
    echo "  version-filtered     - Only executions after current version"
    echo ""
    echo "Actions (Reports):"
    echo "  summary              - Human-readable summary"
    echo "  json                 - Full JSON export for infra-improve"
    echo ""
    echo "Deduplication:"
    echo "  - 'new-insights' tracks last analyzed timestamp in state file"
    echo "  - Subsequent runs only analyze NEW data, avoiding duplicates"
    echo "  - Use 'improvement-insights' for full analysis (reprocesses all)"
    echo ""
    echo "Examples:"
    echo "  $0 summary 7                        # Last 7 days summary"
    echo "  $0 corrections 14                   # Find corrections in last 14 days"
    echo "  $0 improvement-insights 7           # Full analysis (may reprocess)"
    echo "  $0 new-insights                     # Only NEW data since last run"
    echo "  $0 corrections 7 2026-01-30T00:00:00Z  # Only after specific timestamp"
    ;;
esac
