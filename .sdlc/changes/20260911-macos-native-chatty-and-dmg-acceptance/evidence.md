# 验证证据

- Outcome: pass
- 范围：2026-09-11 本地 DMG 交付；真实业务验收由用户使用正式账号完成。
- 用户明确批准规格和计划，记录见 approvals.md/state.json。批准版 spec/plan 保留原文，其未来式命令由本文件提供执行结果。

## 自动检查

- macOS Debug、ChattyFixture Debug、Universal Release archive 成功，Xcode 26.6 (17F113)。
- 共享核心 Swift tests：43 项，0 失败，含队列恢复、项目快照、冲突处理及新增 macOS 0700/0600、原子替换、账户/工作区隔离和清理验证。
- iOS Simulator 正式 target 回归编译成功。共享代码仅追加 macOS 文件权限，未改动 iOS 行为。
- 正式二进制不含 synthetic-device-fixture-token、CHATTY_FIXTURE_PORT、fixture.banner；正式 Info.plist 无 ATS 例外。
- 架构 x86_64 + arm64；沙盒权限仅出站网络、用户所选文件读取，Hardened Runtime。
- git diff --check 通过；现有 Android 和 iOS 发布文档修改保留，提交范围仅含 Mac 代码及必要共享变更，未推送。
- 日志仅在本地保留，不纳入提交；完整本机日志在 .tools/macos-chatty/。

## CUA 桌面检查

- 合成邮箱验证码登录和工作区选择成功；重开恢复登录。
- 动态展示其他成员的验收事项及第 55 个阻塞事项；查看后待处理仍为 2，只清除对应未读状态，审计无任务写入。
- 第一组三条消息分别提交至 p2/p1/p1，切换项目和编辑草稿正常。
- 第二组三条发送使用 20 秒服务端延迟：界面呈现发送中/等待发送，同时可输入草稿 D。最终共 6 次发送，延迟组间隔 20.082/20.042 秒，无重复提交，草稿 D 未发送。
- 设置弹窗返回、Cmd+1/2/3 导航、项目搜索权限事项通过；退出重开后草稿 D 保留。
- fixture-note.txt 在原生 QuickLook 中显示 Chatty attachment preview OK。
- 原始合成 API 审计：evidence/ui-api-audit.json，无真实账号数据。

## 安装包

- 版本 0.1.0 (1)，bundle ai.chatty.macos，Developer ID Application: [private signing identity]。
- Apple 公证 ID [private notarization reference]，Xcode Organizer Ready to distribute，导出带票据应用。
- codesign --verify --deep --strict、stapler validate 通过。
- DMG 已签名，hdiutil verify 通过；只读挂载后复制至 .tools/macos-chatty/install-check/Chatty.app，再次 stapler 和 Gatekeeper 检查通过：accepted / Notarized Developer ID。
- CUA 启动安装副本，实际显示正式 Chatty 登录窗口（auth.email/auth.sendCode），未继承 Fixture 会话。
- 文件 macos/dist/Chatty-0.1.0-universal.dmg；3,366,318 bytes。
- SHA-256 ce496988e5fe6f4524676438d2decbeeaf3867eb59ca9fb03a8e74bf1e3a897d。

## 边界与后续验收

- Intel 架构已构建，实机启动仅在当前 Apple Silicon Mac 验证。
- 未向真实账号发送消息或修改任务；真实业务端到端由用户验收。
- 文件选择上传、桌面 401/409 和全部深链未逐项执行 UI 测试；相关共享核心契约已有测试，不能等同桌面全覆盖。
- 构建有非阻断警告：图标目录一张未分配源图、未设 App Category、未依赖 AppIntents 因而跳过元数据提取；签名公证和启动均通过。
- 本轮没有保存 UI 截图文件；UI 结论来自 CUA 实际观察和 API 审计。
