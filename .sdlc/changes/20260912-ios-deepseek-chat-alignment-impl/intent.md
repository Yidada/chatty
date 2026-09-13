# Intent: iOS 聊天体验对齐 DeepSeek —— 实施

- Author: 实施会话
- Status: 进行中（阶段 1/2/3/4/5/6 已完成并验证；发布已归档 0.2.0 (6)，等 Organizer 上传）
- Stage: Build
- 上游规范：[`20260912-ios-deepseek-chat-alignment`](../20260912-ios-deepseek-chat-alignment/intent.md)
  — 本 change **不重复其计划**，阶段划分、文件清单、验证命令与风险全部见上游
  [`plan.md`](../20260912-ios-deepseek-chat-alignment/plan.md)。
- Last updated: 2026-09-12

## 1. 目标

按上游 `plan.md` 的 8 个阶段实施「iOS Mika 聊天体验对齐 DeepSeek iOS v2.5.x」。
本 change 记录实际交付、验证命令与证据。

## 2. 范围（逐阶段推进，已完成部分在下表勾选）

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 1 | 契约与受保护存储底座 | ✅ 完成（85 tests 全绿 + 宿主 BUILD SUCCEEDED） |
| 2 | ChatModel 会话模型、停止与队列 | ✅ 完成（会话切换、停止、队列四项、按会话出站队列） |
| 3 | 视觉令牌与主题 | ✅ 完成（13 个语义令牌，浅色取实测值、深色用系统语义色） |
| 4 | 富文本与公式 | ✅ 完成（纯 Swift 子集：`$…$` / `\(…\)` / `$$…$$` / `\[…\]`，95 tests） |
| 5 | Mika 页重写 | ✅ 完成（顶栏、欢迎态、消息行、过程块、队列区、输入区） |
| 6 | 会话历史界面 | ✅ 完成（抽屉 + 搜索 + 未读/当前标记，无长按菜单） |
| 7 | 合成服务与验收剧本扩展 | ✅ 完成（剧本：欢迎/发送/过程块/回答/**历史列表+搜索+切换**/公式/停止/队列/深色模式；队列单条动作语义由单元测试固定，见 `evidence.md §16、§19`） |
| 8 | 回归、无障碍与交付证据 | 🟡 部分：宿主 XCTest 11 项通过（新增令牌对比度断言，**并因此抓到深色模式底色漏配回退的真 bug**，见 `evidence.md §18`）；标准档与全部五档无障碍字号通过；真机矩阵与 VoiceOver 人工走查未做 |

发布：见 [`release.md`](release.md) —— 已归档 `0.2.0 (6)`，CLI 无法导出分发版本
（`No Accounts`，本机无 ASC API Key），按 `ios/TESTFLIGHT.md` 走 Organizer 上传。

## 3. 已确认的约束（来自上游 `decisions.md`）

- **D5**：保留 `动态 / Mika / 项目` 三 Tab，本 change **不动主导航**。
- **D6**：iPad 与 iPhone 同样单栏，限宽约 700pt。
- **D7**：历史行本期**不做长按菜单**（服务端不支持写 `title`/`pinned`/删除）。
- **J1/J2**：不做「深度思考 / 智能搜索」假开关；过程块不照搬「已搜索到 N 个网页」文案。
- **A10**：界面不得存在无服务端语义的控件。

## 4. 环境事实（影响验证命令）

- `swift test` 在文件策略为 `workspace-write` 时**必须加 `--disable-sandbox`**：
  SwiftPM 编译 manifest 会调用 `sandbox-exec`，而嵌套 `sandbox_apply` 被拒
  （`sandbox-exec: sandbox_apply: Operation not permitted`），manifest 编译失败、
  测试不会运行。策略为 `danger-full-access` 时不需要该参数。
  基线：**75 tests / 0 failures**（2026-09-12 实测）。
- 一律用 `set -o pipefail`（或 `${PIPESTATUS[0]}`）读取退出码：被管道包住的
  `swift test` 曾返回 0，而实际是 manifest 编译失败。
- 宿主 `xcodebuild` 需把 DerivedData 放在仓库内（`$CHATTY_IOS_DERIVED_DATA`），
  且 SwiftPM 还要写 `~/Library/Caches/org.swift.swiftpm`；受限策略下表现为
  `Could not resolve package dependencies`，重定向 `HOME` 无效。
- 阶段 1 只改 `ios/Packages/ChattyKit`（SwiftPM 自动发现文件），
  **不需要**运行 `scripts/generate-ios-project.py`。
- 未纳入本 change 的既有改动：`ios/Chatty.xcodeproj/project.pbxproj`、
  `scripts/generate-ios-project.py`、`.gitignore` 在本次实施开始前就已是修改状态，
  **不属于本 change，未被触碰**。
