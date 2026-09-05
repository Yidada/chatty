# Chatty Android 视觉规范

2026-09-05。目标：高级、简洁、原生；范围为现有对话 / 项目 / 设置。

## 检索与选择

- [Linear Mobile](https://linear.app/mobile)：参考原生移动端的信息层级、紧凑列表和低干扰界面；已打开官方页面与 Inbox 产品图查看。
- [Linear 移动端改版](https://linear.app/changelog/2025-10-16-mobile-app-redesign)：参考底部核心导航与层次分明的表面处理。本次不复制磨砂玻璃效果。
- [Material 3 原生主题指南](https://developer.android.com/codelabs/m3-design-theming?hl=en)：采用颜色角色、字号角色、形状和明暗主题，适配现有 Compose 工程。
- [Google Expressive 设计研究](https://design.google/library/expressive-material-design-google-research)：参考用层级强调主要操作的思路；Chatty 使用较克制的色彩。

这是一套结合现有 Chatty 产品的视觉适配，并非对上述产品逐像素复制。Linear 官方展示中包含 iOS 画面，本次仅借鉴信息层级；Android 的组件与行为遵循 Material 3。

## 设计规则

| 元素 | 规则 |
| --- | --- |
| 页面 | 暖白 `#F6F7F4`；深色 `#141815` |
| 文字 | 石墨 `#202521`；深色 `#E5EAE2` |
| 主色 | 低饱和绿 `#365E50`；深色 `#A9CDB8` |
| 内容表面 | 白色卡片；深色 `#1E241F`；避免重复描边 |
| 文字层级 | 页标题 24sp / 32sp 行高；卡片标题 16sp / 24sp；正文 14–16sp；辅助信息 12sp |
| 间距 | 页边距 24dp；卡片 16–20dp；列表间隔 8–16dp |
| 形状 | 内容 18–24dp；输入区 28dp；状态胶囊 |
| 图标 | Material Outlined；图标动作保留文字语义；触控 48dp |
| 主题 | 跟随系统明暗；系统状态栏同步；Markdown 代码与链接跟随主题 |

- 对话：清晰的 Mika 标识、轻量用户气泡、统一输入容器，保留发送/附件/草稿和错误处理。
- 项目：白色进度卡片、轻量百分比、全宽搜索及独立状态筛选。进度继续使用服务端统计。
- 设置：工作区卡片、运行与协作分组、紧凑原生资源行；保持上一轮无 Multica 网页出口的决策。
- 复用入口：`android/core-ui`，供 app、feature-chat、feature-workspace 使用。
- 本轮不引入新后台操作或网页替代流程；上一轮未提交的原生体验变更一并保留。

## 验证

- 构建、Lint、35 项 JVM 测试通过。证据位于 `iterations/v2/evidence/design-refresh/`。
- `design-tabs-loop/`：项目进度、状态修改、搜索筛选、55 条分页、资源详情和 Tab 切换通过。
- `design-chat-loop/`：两轮合成收发、附件、任务过程、草稿/冷启动、重连、分页和错误恢复通过。
- `design-visual-loop/`：浅色、深色、1.3 倍字体及键盘画面已采集并检查。设置和项目布局清晰，放大字号仍可使用。
- 视觉检查发现输入框与键盘间距偏大；已按 [Android 官方 Insets 规则](https://developer.android.com/develop/ui/compose/system/insets-ui)消费 Scaffold 已提供的 padding，修正重复预留空间。修正后构建和测试通过。
- USB 重连后，`design-keyboard-loop/` 真机复验通过：键盘上方多余留白消除，输入区无重叠；一次合成收发及三 Tab 切换通过。初次异常截图保留用于对照。
- 最终真实服务 APK 已安装至 Pixel 6 Pro；Mika、原生设置及 Runtimes / Agents / Squads 导航检查通过，当前进程无 AndroidRuntime FATAL。证据为 `design-refresh/live-smoke.json`、`process.json`。
- 测试包和本次 ADB 端口转发已移除，手机前台保留真实服务版本。
- 测试已恢复手机原有 `night=auto`、`font_scale=1.0`。本轮真实工作区无发送/状态写入。
- 代码保留在 `codex/native-experience`，本轮未提交、推送或发布。
