# Review
- Reviewer: Codex self-review（同一实现者自审，非独立审查）
- Verdict: approved

## Scope and findings
- WorkspaceScreens.kt 的 WebButton、web URL 构造、20 项网页菜单及 ResourceRow.path 已全部删除；原生 Issue 状态修改路径保持原样。
- Chat 不再构造或传递会话网页 URL。所有 HTTP 浏览器调用经过 externalContentLink；当前只剩第三方内容出口和 Android 本地文件查看器。
- Markdown 在 AST 层移除内部 Link 节点，保留其文字、强调和图片；策略单测覆盖标签保留和相邻节点，防止简单正则损伤内容。
- 图片与图片附件的预览使用原生 AlertDialog 和既有图片加载器；未加入 WebView、执行脚本、依赖或数据协议。
- 首轮内容真机测试因视口滚动定位失败，保留原始证据；测试改为定位实际消息列表并等待刷新后通过，应用代码未因此改动。
- 手工查看设置、Issue 状态详情、图片预览截图，内容和关闭路径清晰。

## Residual scope
- 完整资源配置编辑、HTML/Mermaid 交互渲染仍不在本次范围；相关网页兜底入口已删除。
- 第三方网站后续自行重定向的行为不由应用控制；本次策略约束应用直接发起的浏览器目标。
- 图片缩放手势与离线缓存未新增。真实工作区不发送测试消息、不修改 Issue。
