# Evidence: DeepSeek iOS 调研素材

- Change: `20260912-ios-deepseek-chat-alignment`
- 采集日期：2026-09-12
- 用途：支撑 `research.md` 与 `spec.md` 中的每一条可验证断言。**原始素材按来源分目录，
  不做二次编辑**；结论与取舍写在 `research.md`。

## 1. 一手截图（主要证据）

用户提供的 App Store 官方截图在仓库根的 `ds/`（`cn1..cn5.png`、`us1..us5.png`，
1290×2796 @3x，中文区与美区各 5 张）。**本目录不复制这 10 个文件**（约 25 MB），
需要时可从下列官方直链重新下载，或直接使用根目录的 `ds/`：

| 主题 | 中文区 | 美区 |
| --- | --- | --- |
| 品牌 hero | `ds/cn1.png` | `ds/us1.png` |
| 空态 + 附件面板 | `ds/cn2.png` | `ds/us2.png` |
| 思考中（`正在思考`） | `ds/cn3.png` | `ds/us3.png` |
| 思考完成（`已思考（用时 90 秒）`） | `ds/cn4.png` | `ds/us4.png` |
| 文件附件（`三体.txt`） | `ds/cn5.png` | `ds/us5.png` |

官方直链获取方式：`https://itunes.apple.com/lookup?id=6737597349&country=cn`（或 `us`）
返回的 `screenshotUrls` / `ipadScreenshotUrls` 数组；把末尾的 `/320x480bb.jpg`
替换为 `/1290x2796bb.png` 即可得到高清原图。

### ⚠️ 商店截图会滞后于真机（本次已撞到一次）

`research/empty-state-20260910-bianews.jpg`（960×1965，40KB，已归档）是一张
**2026-09-10 的真机实拍**（鞭牛士/BiaNews 新闻配图，原始 URL 见下），它证明：

- **当前空态主文案是「想从哪里开始？」**，不是商店截图里的
  「下午好，有什么可以帮到你？」——**商店截图是滞后的营销物料**。
- 实拍图里 `智能搜索` 处于激活态、`深度思考` 处于未激活态，是 chip 两态的真机证据。
- 其余结构（左上 `≡`、右上 `⊕`、输入卡 placeholder、两个 chip、无 Tab Bar）与商店截图一致。

原始 URL：`https://inews.gtimg.com/om_bt/OzgOgUSYK9V-gxiTeX78U_Jkfr_YQz9kmrg54AQ7cqq1oAA/641`
（来自 `https://news.qq.com/rain/a/20260910A06Q3Y00`）。本次由规划会话独立下载并复核。

**纪律**：控件结构与颜色用商店截图基本安全；**逐字文案一律按「营销物料级」置信度对待**，
真机截图到位后复核。

### `ds/` 目录的变动说明

除用户提供的 10 张外，`ds/` 里另有 `wiki2025.jpg`、`wiki2025_conv.png` 两个文件，
是本次调研的子代理为做「2025 R1 时代 vs 2026 现状」对照而下载的 2025 年真机截图
（**Android/鸿蒙版**，非 iOS）。如需保持你原来的 `ds/` 干净，可自行删除；相关结论已
写入 `research.md §2.2`，不依赖这两个文件的留存。

**复现取色的方法**：`research.md §3` 的所有色值来自对 `ds/us3.png`、`ds/cn4.png`、
`ds/cn5.png` 屏幕区域的定点取样（取 12×12 像素块的中位数，避免抗锯齿干扰），
以及裁切放大后的目视确认。关键结论（`#FFFFFF` 背景、`#EDF3FE` 气泡、
`#0F0F0F` 正文、`#7D7F85` 过程块、chevron 方向、问候语与 chip 文案）都已用两种
方法交叉验证过。

## 2. `research/` — 第三方/子代理调研产出（原始，未编辑）

| 文件 | 内容 | 在本 change 中的使用 |
| --- | --- | --- |
| `deepseek-ios-interaction-research.md` | 948 行交互行为调研：14 节 + 38 行证据表 + 29 项真机验证清单 | `research.md §9.8` 的来源；其三处结论被一手截图推翻，已在 §9.8 记录 |
| `deepseek-ios-ui-research.md` | 消息呈现 / 思考块 / 视觉的像素级测量 | `research.md §3` 的几何与排版数据来源；其 chevron 方向与过程块颜色的说法被实测推翻 |
| `appstore-reviews.json` | 450 条 Apple 官方 RSS 评论（星级/版本/日期/正文） | 「次数上限是最大差评源」等社区结论的原始语料 |
| `appstore-helpful.json` | 200 条「最有帮助」评论 | 同上 |
| `appstore_reviews.txt` | 评论语料的文本摘录 | 便于快速检索 |
| `deepseek-ios-research.md` | 官方 FAQ（站点 JS bundle 原文）与版本记录：历史侧边栏、长按菜单、删除不可恢复、分享对象 | `research.md §9.1–9.3` 的来源 |
| `deepseek-app-primary-source-report.md` | App Store / 官方 FAQ / 隐私政策的一手事实清单、版本历史 | `research.md §1`、`§9.5` |
| `deepseek-app-review-research.md` | 评论语料的主题聚类（配额、引用、分享、历史管理） | `research.md §9.6` |
| `deepseek-app-interaction-research.md` | 网页端变更检测、停止/继续、打断并发送 | `research.md §9.4`、`§9.8` |
| `deepseek-design-tokens.css` | DeepSeek **官网** CSS 构建产物里的设计 token（浅色 + 深色） | `research.md §3` 的品牌蓝与深色候选；**Web 值，不能直接当 App 规格** |
| `ios-ai-chat-interaction-baseline.md` | ChatGPT / Claude / Kimi / Gemini iOS 的历史与消息操作基线（官方文档引用） | `research.md §9.7` |
| `deepseek-ios-chat-ui-report.md` | 706 行 UI 结构报告（屏幕清单、导航骨架、逐屏布局） | `research.md §2`、`§9.1` 的交叉印证 |
| `deepseek-app-ui-research.md` | UI 与视觉的二次整理（573 行） | 与 `deepseek-ios-ui-research.md` 互为印证；冲突时以一手截图为准 |
| `deepseek-ios-design-research.md` | 设计语言与令牌整理（334 行） | `research.md §3` 的品牌蓝与深色候选 |
| `deepseek-ios-app-rendering-research.md` | 渲染层调研：Markdown / 公式 / 代码块 / 流式的呈现 | `spec.md §8` 的公式与富文本部分 |
| `deepseek-ios-version-timeline.json` | App Store **完整版本历史**（版本号 / 日期 / 官方 release notes 原文，结构化） | `research.md §1` 版本事实与 `§9.5` 模式历史的**一手来源**；「思考过程自动折叠」等断言的逐字依据 |
| `deepseek-ios-version-history-research.md` | 基于上述时间线整理的版本演进叙述（323 行） | `research.md §1`、`§2.6` 的版本对照 |
| `shots.txt` | 官方截图直链清单 | 重新下载截图 |

### 使用这些素材时的三条纪律

1. **一手截图 > 官方 FAQ > 官方版本记录 > 媒体转述 > 社区评论**。子代理报告属于
   「媒体转述 / 社区评论」层级，进入规范前用前两级复核。
2. 已经发现并记录了 **3 处**子代理结论与一手截图冲突的情况（见 `research.md §9.8`）：
   双 chip、计时器文案、chevron 方向。**遇到冲突以截图为准。**
3. `deepseek-design-tokens.css` 来自带 hash 的构建产物文件名，DeepSeek 重新部署即失效；
   引用时保留来源 URL 与哈希，并注明**这是 Web 而非 iOS** 的设计系统。

## 3. 尚未采集的证据（对应 `spec.md §14`）

- 真机深色模式截图（空态 / 对话 / 历史）——**阻塞深色令牌定稿**。
- 历史抽屉打开态截图（行结构、分组、置顶）。
- 回复的消息长按菜单截图。
- 生成中状态的截图（停止按钮形态、是否显示计时）。
- 断网 / 空态 / 错误态截图。
- 键盘行为录屏。

这些需要物理设备或用户提供素材；在补齐之前，`spec.md` 中相关项按候选方案实施并
标注为「未对齐风险」。
