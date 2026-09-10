# 验证记录

- 开发前基线：2026-09-10，Swift 33 项测试通过，日志 `.tools/ios-testflight/preflight-20260910/swift-tests.log`。
- 当前结果：iOS 第一版实现与本机验证完成；本轮未执行 TestFlight 上传。
- 后续代码交付：构建号已准备为 0.1.0 (2)，新增旧版待确认草稿迁移检查，核心测试增至 42 项。见 [交付记录](release.md)。下面保留初次验证的原始结果。
- 协议来源：本机 Multica 的 `server/internal/handler/chat.go`、`issue.go`、`activity.go`、`inbox.go` 和 `server/cmd/server/router.go`。

## 实现结果

- 底部为动态 / Mika / 项目；右上头像打开设置 Sheet。
- 动态通过工作区全量事项入口读取，不按个人 Inbox 收件人或发起人过滤；新进展和待处理独立分页。
- 待处理采用状态目录中 in_review / blocked 类别；查看仅更新本机已读指纹，验收才更新业务状态。
- Mika 项目选择保存在草稿中。发送时将文本、附件、项目固化到原子持久记录，立即清空输入；串行 PATCH 项目 + POST 消息，保留服务端 FIFO。
- 启动恢复、后台暂停、项目权限失败、旧服务端不支持队列、未知回执均有明确保留与恢复路径。
- 详情突出当前状态、验收与继续讨论，目标/记录折叠。继续讨论携带可见事项引用和项目，不自动发送。

## 已执行验证

| 检查 | 结果与证据 |
| --- | --- |
| Swift 核心 | 41 项通过，0 失败；[原始输出](evidence/swift-tests.log) |
| 原生 iOS 宿主 | iPhone 17 Pro / iOS 26.5：4 通过，0 失败，1 跳过；模拟器不暴露物理文件保护属性。Keychain、原子草稿/队列恢复、备份排除和退出清理通过 |
| 构建 | ChattyFixture Debug 与普通 Chatty Release / generic iPhone 均通过；Release 检查使用 CODE_SIGNING_ALLOWED=NO，属于编译验证 |
| 发布隔离 | 普通包 ai.chatty.ios，无 ATS 例外，无 Fixture 配置变量/合成凭据/FixtureSupport；[摘要与哈希](evidence/validation-summary.json) |
| A1 导航 | 三个 Tab、头像进入设置、关闭后仍在 Mika 并保留草稿；[截图](evidence/04-avatar-settings.png)、[UI 断言](evidence/settings-keeps-draft.json) |
| A2–A4 连续发送 | 回执延迟 20 秒。A 尚在发送时 B 进入等待；B 发送时 C 进入等待；D 可继续输入。A/B/C 仅各提交一次，项目依次 p2/p1/null；[UI 快照](evidence/consecutive-ui-snapshots.json)、[修复后截图](evidence/05-fixed-consecutive.png)、[服务端审计](evidence/final-api-audit.json) |
| A5 失败恢复 | 核心测试覆盖未知回执不自动重发、明确核对后重试、冷恢复队列需继续、后台保留后续消息、项目 PATCH 失败不 POST、草稿/附件/项目不串、旧工作区不能提交 |
| A6 全项目 | 待处理包含他人发起的第 55 个事项，独立于新进展第一页；核心测试验证 50→55 分页、无 creator/assignee/project 筛选 |
| A7 已读与待办 | 查看 i0 后该条“未读”消失，待处理仍为 2，服务端写入为 0；冷启动仍记住已读；新的 issue:updated 使红点恢复。刷新失败保留旧列表；[已读后 UI](evidence/read-keeps-action.json)、[查看后的请求审计](evidence/before-approval-audit.json) |
| A8 验收 | 点击后唯一一次 PUT：status=done / suppress_run=true / expected_revision=1；待处理由 2 变 1。409 刷新最新状态且不自动重复写入的核心回归通过；[验收后 UI](evidence/approval-removes-action.json) |

模拟器暴露的重复显示问题已修复：服务端历史可能在 POST 回执前出现该消息，之前与本机待发送行重复。现在在提交期间保留本机行为可见来源，收到消息 ID 后合并；未用文本去重。专门测试确认两次相同文本仍为两条独立消息。

## 明确边界

- 本轮为应用内红点；没有 APNs、锁屏推送或跨设备已读同步。
- 动态按事项展示最新进展，完整事项 timeline 在详情折叠区读取。
- 真账号联调、物理 iPhone 的文件保护/VoiceOver 人工体验、签名归档和 TestFlight 上传尚未执行。初次编译验证使用 0.1.0 (1)；后续提交配置为 0.1.0 (2)，本机编译不代表新测试版本已发布。
- 后端项目是会话属性；本客户端在每次发送前按快照串行确认。多个客户端同时修改同一会话项目的竞争需要后端提供逐条消息参数才能完全消除。
- 旧 V1 `.ad` 回放保留原始导航证据；其设置 Tab / 计数选择器不适用新版。本轮使用以上原生交互证据，未声称旧回放通过。
- 已有 Android 与其他 `.sdlc` 工作保留。初次实现尚未提交；用户随后授权提交和推送，范围见交付记录。

## 原始日志

- `.tools/ios-activity-mika/swift-tests.log`
- `.tools/ios-activity-mika/fixture-build.log`
- `.tools/ios-activity-mika/release-build.log`
- `/Users/benjamin/Library/Developer/XcodeBuildMCP/workspaces/chatty-a525cea81dd1/logs/test_sim_2026-09-10T07-10-15-388Z_pid26105_f2e8aeec.log`
- `/Users/benjamin/Library/Developer/XcodeBuildMCP/workspaces/chatty-a525cea81dd1/result-bundles/test_sim_2026-09-10T07-10-15-388Z_pid26105_db7b2375.xcresult`
