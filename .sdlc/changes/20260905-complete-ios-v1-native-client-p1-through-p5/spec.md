# 规格

采用已被用户确认的 .sdlc/changes/20260905-complete-ios-v1-native-client-p1-through-p5/design-plan.md §2–9 作为完整规格；本文件明确实现边界。

- 登录：邮箱验证码；Keychain ThisDeviceOnly；恢复 /me 与 workspaces；403/503 不删凭据；401 仅使当前 token 和 generation 失效。切换/退出取消旧任务、socket 与上传下载，旧结果不能污染新工作区。
- 对话：system_key=mika + owner/public_to permission；最近未归档会话；首次发送时创建。双游标分页，ID 去重，固定阅读锚点；草稿按 account/workspace/agent 隔离。单次 POST，未知回执不自动重发；有效回执后即使刷新失败也保持已接受。
- 实时：前台单个 WebSocket，auth 首帧，无 URL token，auth_ack 后消费；认证超时和退避；后台停止，恢复用 REST 收敛。未知事件保留可读类型，任务过程按 task_id/seq 去重。
- 内容：原生 Markdown 标题、列表、引用、加粗、链接、行内代码、代码块、表格、删除线、任务列表；HTML/Mermaid 作为源码。任务失败/无回复、快捷提示只填草稿。PhotosPicker/fileImporter 上传，附件回执绑定、下载刷新metadata、图片缩放与Quick Look。
- 安全网络：TLS正式地址 https://api.multica.ai；ephemeral会话、无cookies/磁盘缓存；同源API请求才附凭据；外部HTTPS附件无凭据。禁重定向；下载流式大小上限和受保护临时文件；退出清理；不写私密日志。
- 项目：服务端聚合、无项目入口、搜索/状态/50分页、新鲜详情与revision；一次PUT显式suppress_run=true；冲突只重读不重写。
- 设置：工作区选择、退出，Runtime/Agent/Squad 列表详情与错误/空态。
- 质量：语义字体、44pt目标、可访问性ID、系统键盘安全区、深浅色/小屏/大字号；真实设备和账户验证保留独立证据。

A01–A13 映射到 Swift 单元/URLProtocol并发测试、实际fixture集成、iOS XCTest、agent-device和存储审计。A14 需要可连接的 iPhone、签名与真实账户，并在消息内容获授权后执行。
