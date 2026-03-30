# Proactive Best Practice Recommendations

> **"At every key output step, proactively recommend common best practices based on context."**

## The Principle

At EVERY key output step (not just the final output), self-review and recommend improvements the user might not have thought to ask for.

```
Before Each Key Step → Self-Review → Identify Missing Best Practices → Recommend → Then Deliver
```

## When to Apply

This applies at EVERY key output step:
- **Analysis output**: After analyzing, before presenting findings
- **Design output**: After designing, before presenting architecture
- **Implementation output**: After coding, before showing changes
- **Report output**: After generating, before delivering report
- **Any intermediate result**: Any step that produces user-visible content

## Self-Review Checklist

Before delivering output, ask:

| Question | If No → Recommend |
|----------|-------------------|
| Is the scope/domain clear? | Add category/domain prefix |
| Is the language consistent? | Match surrounding documentation language |
| Are error cases handled? | Add error handling guidance |
| Is the format reader-friendly? | Suggest formatting improvements |
| Are there implicit conventions? | Make conventions explicit |
| Could a reader misunderstand? | Add clarifying context |

## Recommendation Format

When recommending improvements, use this format:

```
💡 **建议** / **Recommendation**:
- [Specific recommendation with rationale]
```

Or for multiple recommendations:
```
💡 **建议**:
1. [Recommendation 1] - [Why]
2. [Recommendation 2] - [Why]
```

## When NOT to Recommend

- User explicitly specified format/style
- Recommendation would be redundant with existing content
- Recommendation is purely aesthetic with no practical benefit
- User is in a hurry and explicitly asked for quick output

## Integration with Skills

Skills that produce user-facing output should include:
```markdown
## ⚠️ Before Finalizing Output

Review using `.claude/guidelines/proactive-recommendations.md`:
- Is anything missing that a reader would benefit from?
- Are there best practices that apply to this output?
- If yes, include 💡 建议 section with recommendations.
```
