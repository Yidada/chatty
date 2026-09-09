# 实施计划

## 已有授权
用户对 iterations/ios-v1/plan.md 完整范围及执行顺序明确批准「没问题，全部执行开发完吧」。本变更规格和计划将该已有方案落实为文件分工，未增加发布、后台推送、语音或服务端修改。沿用该授权记录 spec/plan 决策；真实发信/Agent测试消息等待具体内容授权。

## 顺序
1. P1：ChattyCore 网络、CredentialVault、SessionModel、作用域与受保护本地存储；原生登录和工作区。
2. P2：WorkspaceModel/ChatModel、消息分页/单次发送/回执不明、REST恢复、前台Socket。
3. P3：RichContent 解析、原生视图、任务详情、上传、受限下载和预览、草稿与退出清理。
4. P4：ProjectsModel、Issue详情/修改、完整Settings资源与工作区切换。
5. P5：扩展独立 iOS fixture 场景，Swift边界/并发测试、iOS XCTest、agent-device真实流程与重启、画面检查；正式Release构建和隔离检查。
6. 审查完整diff、更新验收矩阵和LAN报告；尽可能完成真实设备验证。无法取得的外部依赖明确保留，不将整体验收标为完成。

## 文件和命令
现有核心包 ios/Packages/ChattyKit，宿主 ios/Chatty 和 ios/Fixture。本地参考 android/core-network、feature-chat、feature-workspace 和 Multica 1cc46b269；脚本 scripts/chat-fixture.py 协议为基线。新增 iOS 专用 fixture 扩展文件，避免破坏 Android 测试。

swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build；XcodeBuildMCP build_run_sim/test_sim；scripts/ios-dev-loop.sh；agent-device .ad + semantics；xcodebuild Release无签名Simulator。相关变更后重跑相关检查。
