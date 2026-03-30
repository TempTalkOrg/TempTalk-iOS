# Document Reading Rules

## Primary Tool: markitdown MCP

**Always use `mcp__markitdown__convert_to_markdown`** to read documents:
- PDF, DOCX, XLSX, PPTX, HTML, CSV, and other structured formats
- PRD documents, specs, requirements docs
- Any file attachment the user provides for analysis

### How to Use

```
1. Load the tool:
   ToolSearch("select:mcp__markitdown__convert_to_markdown")

2. Convert the document:
   mcp__markitdown__convert_to_markdown(uri="file:///path/to/document.pdf")
```

## When to Use What

| Format | Use | NOT This |
|--------|-----|----------|
| PDF | markitdown | Read tool, document-skills:pdf |
| DOCX | markitdown | document-skills:docx |
| XLSX | markitdown | document-skills:xlsx |
| PPTX | markitdown | document-skills:pptx |
| Images (OCR) | markitdown | - |
| Source code | Read tool | markitdown |
| Screenshots | Read tool (visual) | markitdown |

## Applies To

This rule applies to **all agents and the main context**, including:
- bug-analyst, feature-analyst (reading PRDs, specs, attached docs)
- architecture-design-specialist (reading design docs)
- Any agent that receives document files as input
