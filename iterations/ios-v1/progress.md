# iOS V1 开发进度

更新：2026-09-05。P1–P4 客户端实现完成，P5 本地自动化和原生界面验证完成。真实账号和物理 iPhone 业务验收仍待外部条件，SDLC 保留 Test 阶段。

## 已实现

- P1：验证码登录、Keychain ThisDeviceOnly、工作区选择、退出清理、失效会话隔离、冷启动离线草稿。
- P2：Mika 权限识别、有效会话、首次建会话、单次发送与未知回执保护、双游标分页、前台 WebSocket、后台释放与 REST 恢复。
- P3：原生 Markdown、任务执行过程、照片与 Files 上传、附件绑定核对、图片缩放、Quick Look 和主动分享。
- P4：项目完整统计、Issue 搜索/状态/分页/无项目入口、revision 与 suppress_run 状态修改、Runtime/Agent/Squad 原生详情。
- P5：独立合成服务、3 段可重复 UI 流程、系统存储测试、Release 隔离检查及实际运行截图。

## 验证

| 检查 | 结果 |
|---|---|
| Swift Package | 33 通过，0 失败 |
| iOS XCTest | 4 通过，0 失败；1 项物理文件保护属性需真机 |
| 自动设备回放 | core / resources / workspaces 共 117 步，0 自动修正 |
| 合成核心写入 | 两轮消息各 1 次 POST；Issue 1 次 PUT，包含 suppress_run=true 与 expected_revision |
| 附件 | PhotosPicker 与 Files 的自建样本上传、绑定、原生预览通过 |
| 生命周期 | 后台 0 连接和 0 新请求；恢复和主动断线后最多 1 条连接 |
| 冷启动 | 503 时只开放草稿；联网后恢复历史；未知回执重启/刷新均不重发 |
| 前台项目刷新 | 服务端合成更新后，返回应用自动从 25/55 更新为 26/55 |
| Release | 普通包 Simulator + 通用 iPhone 编译通过；不含 Fixture 源码、token、地址、ATS 例外或 Documents 共享 |
| 小屏与大字号 | 375×667、深色、两档辅助大字号、键盘与原生导航通过；人工 VoiceOver 待验 |

核心回放审计与额外边界测试分别保留。额外照片、文件、未知回执和外部模拟修改产生另外 3 条合成消息及 1 次合成 Issue 修改；没有真实业务写入。

机器摘要：[verification.json](evidence/v1/verification.json)。实际截图：[progress.html](progress.html)。完整架构与运行步骤：[ios/README.md](../../ios/README.md)。

## 验收条件

- 目标 iPhone 连接、Developer Mode 和正确 Apple Development Team。
- 真实 Multica 邮箱与目标工作区，指定允许发送的测试内容。
- 实机文件保护/锁屏、网络切换、Quick Look 缓存行为与人工 VoiceOver 检查。

未制作签名 IPA，未提交、推送、TestFlight 或 App Store 发布。原始设计 [plan.md](plan.md) / [design.html](design.html) 与历史 P0 证据保持独立。
