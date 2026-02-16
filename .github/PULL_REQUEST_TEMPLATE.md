
<!--
为提升创建 PR 的质量, 尽量减少出问题概率, 提升 PR review 效率, 特提出简单要求.
-->
### ‼️ 检查以下信息是否符合规范, 确认后删除以下信息
PR 创建注意事项：
1. 标题: 符合[规范](https://github.com/difftim/mobile-docs/blob/main/tools/cicd.md#2-代码提交规范-commit-standard) [type][module] Subject
2. 描述: 附上解决问题或者需求关键逻辑、思路

### 支持命令

> 自测充分后, 如不涉及 server 或者不上线需求, 一律只打 beta 包

```
/tt_tf        // BUILD_TYPE=beta  
/tt_tf online // BUILD_TYPE=online
/tttest_tf
```