# 验证证据

## 范围与环境
2026-09-05，main 工作区基线 3c003f9。iOS 26.5 / iPhone 17 Pro Simulator / Xcode 26.6 / agent-device 0.20.10。所有 UI 写入均在独立合成服务；没有真实账户 E2E 或发布。

## 已通过
- Swift Package：33 tests、0 failures，日志 `.tools/ios-v1/full-run/swift-tests.log`。
- iOS XCTest：4 passed、0 failed、1 skipped。最后系统测试结果：`~/Library/Developer/XcodeBuildMCP/workspaces/chatty-a525cea81dd1/result-bundles/test_sim_2026-09-05T15-43-43-879Z_pid78253_821e034c.xcresult`。真实 Keychain 写入、读取、更新、删除和 ThisDeviceOnly 属性通过；文件排除备份、过期删除、退出清理通过。物理文件保护属性在 Simulator 不可见，明确跳过。
- 原生 Fixture Debug 构建、安装和运行：最后构建日志 `build_run_sim_2026-09-05T15-36-38-187Z_pid78253_cf7d2e14.log`（同一 XcodeBuildMCP logs 目录）。
- 回归场景：core 56 steps，resources 29 steps，workspaces 32 steps；均 0 healed。可提交摘要在 `iterations/ios-v1/evidence/v1/replay-{core,resources,workspaces,summary,fixture-audit}.json`。
- 回放服务审计：2 条消息 POST、1 次 Issue PUT；`suppress_run=true`，`expected_revision=1`，自定义状态 `qa_custom`。每次仅 1 条有效 Socket，退出后 0 条；其他工作区和账号没有消息/Issue 写入；auth 请求没有 Bearer，WS URL 没有 token。
- 退出后受保护目录内无文件；草稿和临时预览清理。测试包 Documents 中的合成输入样本单独保留，不属于私密缓存。
- API 重定向：正式 APIClient 与历史 FixtureClient 均拒绝真实本机 302，目标收到 0 次请求；`.tools/ios-v1/full-run/redirect.log`。
- 正常 Release Simulator 与通用 iPhone 无签名编译通过；`iterations/ios-v1/evidence/v1/release-isolation.json` 记录普通包无 Fixture token、回环地址、FixtureSupport 与 ATS 例外。最终构建日志为 build_sim_2026-09-05T15-40-41-949Z_pid78253_c16ec159.log；通用 iPhone 日志为 `.tools/ios-v1/full-run/iphone-build.log`，隔离文件哈希已刷新。
- PhotosPicker 已选择自己注入的 320 B 合成 PNG，上传后发送并确认 attachment ID，读到 `CHATTY_CHAT_OK · IOS_V1_ATTACHMENT`，打开原生图片预览；`photo-upload.json` / `photo-preview.png`。

- FilesPicker 从 Fixture Documents 选择 52 B 文本，上传后发送 IOS_V1_FILE，绑定 upload-2 后用 Quick Look 读到原文；`file-upload.json` / `file-import.png`。
- 后台连接和轮询均停止；返回前台和强制断线后重新认证且最多 1 条连接；503 冷启动仅显示恢复草稿；恢复后没有额外消息。项目页面后台服务端合成更新后 25/55 → 26/55；`lifecycle.json`。
- 未知回执原生测试：发送一次后按钮禁用，冷启动和手动刷新仍保留待确认状态，消息总数未增加；`uncertain.png` / `extra-ui-audit.json`。
- iPhone SE 3 / 375×667：深色、accessibility-medium 与最大辅助字号、输入和键盘收起、项目/设置滚动及 Issue 状态按钮通过；`small-screen.json` 和 small-*.png。最大字号需要滚动；人工 VoiceOver 未验证。

## 测试过程中的修正
- 初次无签名宿主 Keychain 失败，改用本地 ad-hoc 签名后通过。
- 初次物理文件保护断言在模拟器返回 nil，改为明确标记设备专属检查；没有把跳过当通过。
- 录制器的 UIKit 层级身份发生变化，去掉动态祖先绑定；一次长回放的 XCTest 查询中断后，确认原生页面正常，添加唯一详情标识并拆为三段独立流程。最终三段全部通过。

- 后台验证发现共享 URLSession 的 WebSocket 优雅关闭保留旧连接；改为独立 session 立即取消，复测后台 0 / 前台最多 1 条。
- 最终回放一度卡在退出弹窗动画；使用回放格式支持的 wait stable 等待退出弹窗稳定，core 与 resources 完整通过；workspace Sheet 同样增加稳定等待并单独重测，三段使用同一份合成服务状态接受最终写入与退出审计。

## 保留门禁
原生 Files 文本导入及 Quick Look 读回、生命周期、未知回执冷启动、小屏深色和两档辅助大字号检查已记录到 `iterations/ios-v1/evidence/v1/verification.json`。真实目标 iPhone 在最近一次 `devicectl list devices` 中为 unavailable。真实邮箱、Team 和指定测试消息未提供，A14、实机保护/锁屏和人工 VoiceOver 验收保持未完成；SDLC 不关闭。

- 普通 Release 已安装并启动到邮箱登录页，未输入真实邮箱或发送验证码；日志 build_run_sim_2026-09-05T15-55-23-366Z_pid78253_6e2471e9.log，截图 normal-login.png。最终二进制哈希与隔离记录一致。
- 最后工作区回放将文本查询限定为 statictext，并在 Sheet 进入/退出后等待原生界面稳定；32 步通过，0 healed。完整三段 117 步，合成服务最终审计仍为 2 次消息 + 1 次 Issue、最多 1 Socket、退出文件 0。

- 局域网静态报告已更新：`http://192.168.88.32:8876/progress.html`，根入口同样指向最新报告。HTTP 校验 19 个不同链接工件可读，页面字节与本地产物一致。原生截图已目视检查；未将 HTTP 验证表述为浏览器视觉测试。
