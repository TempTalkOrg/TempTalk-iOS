---
name: weekly-report
description: Generate a comprehensive weekly report from Git commits for the current work week or specified date range
disable-model-invocation: true
allowed-tools:
argument-hint: "[START_DATE END_DATE]"
---

# Weekly Report Generation

Generate a weekly report based on Git commits for the specified date range or the current work week (Monday-Friday).

Date range: $ARGUMENTS

## Git Commits Data

```bash
${CLAUDE_SKILL_DIR}/scripts/collect-commits.sh $ARGUMENTS
```

## Instructions

本规则用于依据 Git 提交记录自动生成「周报」。

---
## 输出格式
```
YYYY-M-D ～ YYYY-M-D 周报
1. <简洁中文总结 1>
2. <简洁中文总结 2>
3. ...
```
* 使用中文；每条一句话，描述本周主要提交/功能点的价值,每条以「<领域><动作><目的>」方式撰写。
* 列表项之间用两个空格结尾（保证 Markdown 换行）。

---
## 分析与整理

* **完整性检查**：仔细审查一周所有提交，确保不遗漏任何工作内容
* **包含范围 - 所有工作类型**：
  > 周报记录开发者的全部工作产出，包括技术性工作（agent 配置、工具链、CI 等）。
  - 功能实现 (feat)：新增功能、特性
  - 优化改进 (opt)：性能优化、代码重构、体验改善
  - 问题修复 (fix)：崩溃修复、功能修复、UI 修复
  - 工具/Agent (chore[agent])：Claude Code 配置、技能、工作流改进
  - 基础设施 (chore)：CI/CD、构建配置、依赖更新、版本号更新
  - 文档 (docs)：README、CLAUDE.md、技术文档更新
* **合并策略**：
  - 仅合并同一功能的重复提交（如：同一 PR 的多个 commit、修复同一问题的连续提交）
  - 每个独立的功能点、修复、改进都应单独列出，确保工作内容可见
  - **禁止过度合并**：不同功能/工具/配置必须分开列出，即使属于同一领域
* **反面示例 - 禁止这样合并**：
  ```
  ❌ Claude Code 配置优化：更新 Agent 模型、添加分支清理技能、启用 Figma 插件。
  ```
  上述合并隐藏了 3 个独立工作项，应拆分为：
  ```
  ✅ Claude Code Agent 模型更新：优化 agent 配置，移除过时文档。
  ✅ 本地分支清理技能：新增自动清理已合并/关闭的本地 Git 分支功能。
  ✅ Figma 插件集成：启用 Figma MCP 插件，支持设计稿直接转代码。
  ```
* **大型 PR 拆分原则**：如果一个 PR 包含多个独立功能（如 VIP 群分页 + 群文件权限 API），应分别列出
* **输出原则**：列出所有对团队、产品、项目有意义的工作产出，无数量限制

## 中文总结格式

每条以「<领域><动作><目的>」方式撰写，示例：
* 聊天未读消息红点优化：修复已读后红点无法及时清除的问题。

---
## 注意事项
* **一致性**：最终输出必须包裹在 ``` 代码块中。
* **周末需求**：如需覆盖周末，请显式指定 `END_DATE` 为周日或其他日期。

## Demo
```
2029-6-3 ～ 2029-6-7 周报
1. 聊天性能优化：首次打开聊天页面加载速度提升 30%，改善用户体验。
2. 数据库稳定性增强：自动检测并修复 GRDB 损坏，降低崩溃率。
3. 群成员选择交互优化：修复首次搜索后不可勾选问题，提高可用性。
4. 消息滚动逻辑修复：确保新消息到达后聊天窗口自动滚动到底部。
5. VIP 群历史消息分页：实现基于序列号的按需加载，支持重新加入群组后的消息边界处理。
6. 群组文件权限 API 支持：为群组附件上传下载接口添加 gid/gids 字段，支持权限校验。
7. Claude Code Agent 模型更新：优化 agent 配置，移除过时文档。
8. 本地分支清理技能：新增自动清理已合并/关闭的本地 Git 分支功能。
9. Figma 插件集成：启用 Figma MCP 插件，支持设计稿直接转代码。
10. 项目临时目录配置：使用项目本地 tmp/ 目录，避免 Claude Code 权限提示。
11. 版本号更新至 2.1.0：完成新版本迭代准备。
```
