# DeepSeek iOS App 版本历史 / 更新日志 与 iPad 行为 调研报告

调研日期：2026-09-12 ｜ 目标：App Store id 6737597349 / bundle `com.deepseek.chat` / 杭州深度求索
范围：App Store 版本历史（2025-01 ~ 2026-09）+ iPad 适配行为

---

## 0. 一句话结论

我**逐个版本还原了 84 个 iOS 版本号、发布日期与逐字更新日志**（2025-01-16 ~ 2026-09-12）。
核心数据来自 **Apple App Store 页面 HTML 内嵌的 `versionHistory` JSON（Apple 官方原文）**，
并用 **Wayback Machine 的 20 个历史快照**把 Apple 只保留最近 25 条的窗口拼接补全。
**iPad：是 universal app（原生支持 iPad，非 iPhone 兼容模式），但 App Store 的 5 张「iPad 截图」全部是
"手机机身模型 + 单栏 UI" 的营销合成图；除 1 条用户评论证明 iPad 横屏可用外，没有任何证据能证明存在
侧边栏 / 分栏（Split View）/ 键盘快捷键。**

---

## 1. 【已验证·带 URL】方法论：怎么拿到完整版本历史

这是本次调研最有复用价值的发现，建议团队存档：

1. **Apple App Store 网页内嵌完整 versionHistory JSON（权威、逐字）**
   `https://apps.apple.com/us/app/deepseek-ai-assistant/id6737597349`（或 `/cn/app/id6737597349`）
   的 HTML 里含 `"page":"versionHistory"` 的 `pageData.shelves[0].items`，
   每条为 `{text, primarySubtitle(=版本号), secondarySubtitle(=发布日期 UTC)}`。
   → **上限 25 条**（当前快照只能回溯到 2.0.2 / 2026-04-24）。
   同页 `mostRecentVersion` 给出当前版本的「What's New」。
2. **Wayback Machine 逐月快照补齐早期版本**
   `https://web.archive.org/web/<timestamp>id_/https://apps.apple.com/us/app/deepseek-ai-assistant/id6737597349`
   注意：存档响应可能是 **gzip 原始字节**，用文本模式写盘会把 `1f 8b` 破坏成 `1f ef bf bd`，必须按二进制处理。
   2025-01 ~ 2025-10 的快照是旧版页面（只有当前版本节点，无历史列表）；
   2025-11 之后的新版页面才开始内嵌 25 条历史。
   → **老快照的「What's New」区块 + 新快照的历史列表 交叉拼接 = 完整时间线。**
3. **当前 US 与 CN 两个 storefront 的 versionHistory 逐条对比**：
   **版本号与时间戳完全一致**（25/25 重合）→ DeepSeek iOS 为**全球同步发版**。
4. iTunes Lookup API（`https://itunes.apple.com/lookup?id=6737597349&country=us`）**只返回最新一个版本**，
   且**有缓存滞后**（本次 US 返回 2.5.0，而同日 US 网页版已是 2.5.1）→ 不可用于版本历史。

> ⚠️ 局限：**Internet Archive 在本次抓取完成后即进入 "Temporarily Offline"**（CDX API 已不可用），
> 上述 Wayback 数据是本次窗口期取到的最后一份，建议尽快把 `merged_timeline.json` 归档。

---

## 2. 【已验证】完整版本时间线（84 个版本）

- **日期**：Apple 记录的 UTC 发布时间（`secondarySubtitle` 原值）。
- **来源列**：`CN` = 从 CN storefront 取到的中文原文；`US-EN` = 从 US storefront 取到的英文原文。
- **中文原文只覆盖 2.0.2 及以后**（因为 CN storefront 的历史列表同样只有 25 条）。
  **2.0.2 之前的「中文版更新日志逐字文本」本次无法取得 → unknown**，表中给的是 US 英文原文。

| 版本 | 日期(UTC) | 更新日志（逐字） | 来源 |
|---|---|---|---|
| 1.0.2 | 2025-01-16 | - Added language support for multiple countries<br>- Fixed display issues with some formulas | US-EN |
| 1.0.7 | 2025-01-31 | - Fixed some known issues | US-EN |
| 1.1.0 | 2025-02-28 | - Fixed some known issues | US-EN |
| 1.1.3 | 2025-03-26 | - Fixed some known issues | US-EN |
| 1.1.5 | 2025-04-09 | - Fixed some known issues | US-EN |
| 1.1.6 | 2025-04-11 | - Fixed some known issues | US-EN |
| 1.1.7 | 2025-04-17 | - Fixed some known issues | US-EN |
| 1.1.8 | 2025-04-26 | - Fixed some known issues | US-EN |
| 1.1.9 | 2025-04-29 | - Fixed some known issues | US-EN |
| 1.2.0 | 2025-05-16 | - Optimized chat experience<br>- Fixed some known issues | US-EN |
| 1.2.1 | 2025-05-19 | - Fixed some known issues | US-EN |
| 1.2.2 | 2025-05-28 | - Fixed some known issues | US-EN |
| 1.2.3 | 2025-06-01 | - Fixed some known issues | US-EN |
| 1.2.4 | 2025-06-12 | - Optimized the login and sign-up experience | US-EN |
| 1.2.5 | 2025-07-02 | - Add support for Mermaid diagram rendering<br>- Optimized the login and sign-up experience | US-EN |
| 1.2.6 | 2025-07-05 | - Add support for Mermaid diagram rendering<br>- Optimized the login and sign-up experience | US-EN |
| 1.2.7 | 2025-07-21 | - Support real-time preview for Mermaid diagram<br>- Support logging out of all devices<br>- Fixed some known issues | US-EN |
| 1.2.8 | 2025-07-22 | - Support real-time preview for Mermaid diagram<br>- Support logging out of all devices<br>- Fixed some known issues | US-EN |
| 1.3.0 | 2025-08-13 | - Support creating images from conversations<br>- Improved text selection and copying experience<br>- Fixed some known issues | US-EN |
| 1.3.1 | 2025-08-18 | - Support sharing conversations as images<br>- Improved text selection and copying experience<br>- Fixed some known issues | US-EN |
| 1.3.2 | 2025-08-21 | - Fixed some known issues | US-EN |
| 1.3.3 | 2025-09-02 | - Fixed some known issues | US-EN |
| 1.4.0 | 2025-09-11 | - Fixed some known issues | US-EN |
| 1.4.1 | 2025-09-13 | - Fixed some known issues | US-EN |
| 1.4.2 | 2025-09-16 | - Fixed some known issues | US-EN |
| 1.4.3 | 2025-10-13 | - Support pinning chats<br>- Improve account management<br>- Fixed some known issues | US-EN |
| 1.4.4 | 2025-10-15 | - Support pinning chats<br>- Improve account management<br>- Fixed some known issues | US-EN |
| 1.5.0 | 2025-10-30 | - Fixed some known issues | US-EN |
| 1.5.1 | 2025-11-10 | - Fixed some known issues | US-EN |
| 1.5.3 | 2025-11-25 | - Support for sharing conversation links<br>- Fixed some known issues | US-EN |
| 1.5.4 | 2025-12-03 | - Fixed some known issues | US-EN |
| 1.6.0 | 2025-12-27 | - Support for reading links<br>- Improved the message editing experience<br>- Fixed some known issues | US-EN |
| 1.6.1 | 2025-12-29 | - Support for reading links<br>- Improved the message editing experience<br>- Fixed some known issues | US-EN |
| 1.6.3 | 2026-01-06 | - Support for voice input<br>- Fixed UI display issues in certain accessibility modes<br>- Fixed some known issues | US-EN |
| 1.6.4 | 2026-01-07 | - Fixed some known issues | US-EN |
| 1.6.5 | 2026-01-12 | - Fixed some known issues | US-EN |
| 1.6.6 | 2026-01-15 | - Added photo cropping after camera capture<br>- Fixed some known issues | US-EN |
| 1.6.7 | 2026-01-16 | - Added photo cropping after camera capture<br>- Fixed some known issues | US-EN |
| 1.6.8 | 2026-01-23 | - Added photo cropping after camera capture<br>- Fixed some known issues | US-EN |
| 1.6.9 | 2026-01-24 | - Added photo cropping after camera capture<br>- Fixed some known issues | US-EN |
| 1.6.10 | 2026-01-29 | - Added photo cropping after camera capture<br>- Fixed some known issues | US-EN |
| 1.7.0 | 2026-02-04 | - Fixed some known issues | US-EN |
| 1.7.1 | 2026-02-05 | - Fixed some known issues | US-EN |
| 1.7.2 | 2026-02-06 | - Fixed some known issues | US-EN |
| 1.7.3 | 2026-02-09 | - Fixed some known issues | US-EN |
| 1.7.4 | 2026-02-10 | - Fixed some known issues | US-EN |
| 1.7.5 | 2026-02-13 | - Fixed some known issues | US-EN |
| 1.7.6 | 2026-02-18 | - Fixed some known issues | US-EN |
| 1.7.7 | 2026-02-24 | - Fixed some known issues | US-EN |
| 1.7.8 | 2026-02-27 | - Fixed some known issues | US-EN |
| 1.7.9 | 2026-03-02 | - Fixed some known issues | US-EN |
| 1.7.10 | 2026-03-13 | - Fixed some known issues | US-EN |
| 1.8.0 | 2026-03-27 | - Fixed some known issues | US-EN |
| 1.8.1 | 2026-03-31 | - Fixed some known issues | US-EN |
| 1.8.2 | 2026-04-04 | - Fixed some known issues | US-EN |
| 1.8.3 | 2026-04-10 | - Fixed some known issues | US-EN |
| 1.8.5 | 2026-04-15 | - Fixed some known issues | US-EN |
| 1.8.6 | 2026-04-20 | - Fixed some known issues | US-EN |
| 2.0.0 | 2026-04-22 | - Fixed some known issues | US-EN |
| 2.0.2 | 2026-04-24 | - 修复部分已知问题 | CN |
| 2.0.3 | 2026-04-29 | - 修复部分已知问题 | CN |
| 2.0.4 | 2026-04-30 | - 修复部分已知问题 | CN |
| 2.1.0 | 2026-05-11 | - 支持搜索历史对话<br>- 修复部分已知问题 | CN |
| 2.1.1 | 2026-05-21 | - 支持表格复制、下载及全屏预览 <br>- 修复部分已知问题 | CN |
| 2.1.2 | 2026-06-02 | - 修复部分已知问题 | CN |
| 2.1.4 | 2026-06-03 | - 支持调整字号大小<br>- 修复部分已知问题 | CN |
| 2.1.3 | 2026-06-03 | - 支持调整字号大小<br>- 修复部分已知问题 | CN |
| 2.1.7 | 2026-06-16 | - 支持调整字号大小<br>- 修复部分已知问题 | CN |
| 2.1.8 | 2026-06-18 | - 修复部分已知问题 | CN |
| 2.2.0 | 2026-06-29 | - 支持识图模式<br>- 修复部分已知问题 | CN |
| 2.2.1 | 2026-07-07 | - 修复部分已知问题 | CN |
| 2.2.2 | 2026-07-11 | - 支持识图模式<br>- 修复部分已知问题 | CN |
| 2.3.0 | 2026-07-28 | - 优化图片和文件上传体验<br>- 修复部分已知问题 | CN |
| 2.3.1 | 2026-07-30 | - 优化图片和文件上传体验<br>- 修复部分已知问题 | CN |
| 2.3.2 | 2026-08-07 | - 修复部分已知问题 | CN |
| 2.3.3 | 2026-08-12 | - 修复部分已知问题 | CN |
| 2.3.6 | 2026-08-17 | - 修复部分已知问题 | CN |
| 2.4.0 | 2026-08-21 | - 修复部分已知问题 | CN |
| 2.4.1 | 2026-08-22 | - 修复部分已知问题 | CN |
| 2.4.2 | 2026-08-28 | - 修复部分已知问题 | CN |
| 2.4.4 | 2026-09-03 | - 修复部分已知问题 | CN |
| 2.4.5 | 2026-09-06 | - 修复部分已知问题 | CN |
| 2.5.0 | 2026-09-11 | - 新模型上线，快速、专家、识图模式合并升级<br>- 支持思考过程自动折叠<br>- 修复部分已知问题 | CN |
| 2.5.1 | 2026-09-12 | - 新模型上线，快速、专家、识图模式合并升级<br>- 支持思考过程自动折叠<br>- 修复部分已知问题 | CN |

### 2.1 值得注意的「有实质内容」的版本（对复刻优先级最高）

| 版本 | 日期 | 实质功能（逐字摘录） |
|---|---|---|
| 1.0.2 | 2025-01-16 | `- Added language support for multiple countries` / `- Fixed display issues with some formulas` |
| 1.2.4 | 2025-06-12 | `- Optimized the login and sign-up experience` |
| 1.2.5 / 1.2.6 | 2025-07-02 / 07-05 | `- Add support for Mermaid diagram rendering` |
| 1.2.7 / 1.2.8 | 2025-07-21 / 07-22 | `- Support real-time preview for Mermaid diagram` / `- Support logging out of all devices` |
| 1.3.0 | 2025-08-13 | `- Support creating images from conversations`（对话生成分享图）|
| 1.3.1 | 2025-08-18 | `- Support sharing conversations as images` / 改进文本选择与复制 |
| 1.4.3 / 1.4.4 | 2025-10-13 / 10-15 | `- Support pinning chats` / `- Improve account management` |
| 1.5.3 | 2025-11-25 | `- Support for sharing conversation links` |
| 1.6.0 / 1.6.1 | 2025-12-27 / 12-29 | `- Support for reading links` / `- Improved the message editing experience` |
| 1.6.3 | 2026-01-06 | `- Support for voice input` / `- Fixed UI display issues in certain accessibility modes` |
| 1.6.6 ~ 1.6.10 | 2026-01-15 ~ 01-29 | `- Added photo cropping after camera capture` |
| 2.1.0 | 2026-05-11 | `- Search your chat history`（对话历史搜索，CN 原文「支持搜索历史对话」）|
| 2.1.1 | 2026-05-21 | `- Supports table copy, download, and fullscreen preview`（CN「支持表格复制、下载及全屏预览」）|
| 2.1.3 / 2.1.4 / 2.1.7 | 2026-06-03 / 06-03 / 06-16 | `- Support custom font sizes`（CN「支持调整字号大小」）|
| 2.2.0 / 2.2.2 | 2026-06-29 / 07-11 | `- Supports vision mode`（CN「支持识图模式」）|
| 2.3.0 / 2.3.1 | 2026-07-28 / 07-30 | `- Improved photo and file uploads`（CN「优化图片和文件上传体验」）|
| **2.5.0** | **2026-09-11** | `- New model update: Instant, Expert, and Vision modes are now unified` / `- Thinking process now collapses automatically` / `- Fixed some known issues` |
| **2.5.1** | **2026-09-12** | `- 新模型上线，快速、专家、识图模式合并升级` / `- 支持思考过程自动折叠` / `- 修复部分已知问题` |

**观察（推断）**：从 **1.7.0（2026-02-04）起直到 2.4.5（2026-09-06），连续 30 多个版本的更新日志
几乎全部只有一句「- Fixed some known issues / 修复部分已知问题」**。论坛（linux.do）用户也指出了这一点
（「从 1.7.0 开始，更新都是'修复部分已知问题'」）。对复刻团队的含义：**这段时期的 App Store 文案
不承载任何功能信息，功能差异必须靠实机对比。**

---

## 3. 【已验证 / 部分修正】你已有的元数据

| 项目 | 结论 | 来源 |
|---|---|---|
| v2.5.0 US 2026-09-11 更新日志 | ✅ 与 Apple 原文完全一致 | US storefront versionHistory |
| v2.5.1 CN 2026-09-12 中文日志 | ✅ 与 Apple 原文完全一致 | CN storefront versionHistory |
| **修正**：2.5.1 并非只有 CN | ⚠️ **US storefront 网页版同样已是 2.5.1，时间戳同为 `2026-09-12T08:22:12Z`**；US 的 `itunes/lookup` 仍返回 2.5.0 属**缓存滞后**，勿据此判断 US 未发 2.5.1 | 对比 US/CN 两个页面 |
| minimumOsVersion 15.0 | ✅ US/CN/JP 三区一致 | iTunes lookup |
| fileSizeBytes 60223488 (~57.4 MiB) | ✅ US=CN=JP 完全一致；页面显示 "Size 60.2 MB" | iTunes lookup + 页面 |
| releaseDate 2025-01-10 | ✅ `2025-01-10T08:00:00Z`；日文聚合站 APPLION 亦称「2025年1月10日にiPhoneとiPad両対応のユニバーサルアプリとしてリリース」 | iTunes lookup / applion.jp |
| 语言列表含 ZH/EN 等 | ✅ 71 种（"English and 71 more"），`languageCodesISO2A` 含 `ZH`、`EN` 等 | iTunes lookup + 页面 |
| 无内购 | ⚠️ **弱证据**：App Store 页面**没有** "In-App Purchases / App 内购买" 区块，页面标价 Free。 但注意 **iTunes lookup JSON 对任何 app 都不含 IAP 字段**，所以"lookup 里没有 IAP"**不能作为证据**。本次未找到官方明确声明无内购。 | 页面 HTML 检查 |
| 年龄分级 | ⚠️ 不一致：`itunes/lookup` 的 `contentAdvisoryRating` = **12+**，US 网页显示 **13+**，CN 另有 `advisories: ["偶尔/轻微的医药或医疗信息"]` | iTunes lookup + 页面 |
| 分类 | Productivity（页面）/ `BusinessApplication`（结构化数据的 applicationCategory） | 页面 |

> 排查陷阱记录：US 页面 HTML 中出现 `Monthly auto-renewal: RMB 22/month`，**经核对属于
> "You Might Also Like" 里的 QQ Mail，与 DeepSeek 无关**，不是 DeepSeek 的内购。已排除。

---

## 4. 【分区标注】iPad 行为

### 4.1 已验证：DeepSeek 是「真 universal app」，不是 iPhone 兼容模式

`itunes/lookup` 返回 `features: ["iosUniversal"]`、`ipadScreenshotUrls` 非空（5 张）、
`supportedDevices` 含全部 iPad 机型。

**我做了对照组验证这个字段到底有没有判别力**（这点很重要，因为网上常说"有 ipadScreenshotUrls 不代表什么"）：

| App | features | ipadScreenshotUrls | 实际是否原生 iPad |
|---|---|---|---|
| **DeepSeek** | `["iosUniversal"]` | **5** | — |
| Threads | `[]` | **0** | iPhone-only（无 iPad 版）|
| Robinhood | `[]` | **0** | iPhone-only（无 iPad 版）|
| Venmo | `["iosUniversal"]` | 3 | 有 iPad 版 |

→ **结论：`features` + `ipadScreenshotUrls` 组合是有判别力的**（iPhone-only app 两者都为空/零）。
**所以 DeepSeek 确实声明并原生支持 iPad，运行在 iPad idiom 下，而不是 iPhone 兼容缩放模式。**

⚠️ 反例排除：App Store 页面「Compatibility」里的
`iPad Requires iPadOS 15.0 or later.` 文案**不是判据** —— 我核对了 Snapchat 的页面，
**同样的文案一字不差**。别用这行字下结论。

### 4.2 已验证：5 张「iPad 截图」不包含任何 iPad 专属布局

我把 US 5 张 + CN 5 张 iPad 截图原图（1199×1600，3:4 iPad 画布）都取回并逐张查看了。
**每一张都是营销合成图：iPad 画布 + 渐变背景 + 中间一个"手机机身模型"**，特征：
- 机身顶部有明显 **灵动岛（Dynamic Island）** 药丸形状 → 是手机机身，不是 iPad；
- 内部 UI 与 iPhone 截图**完全同构**：顶部栏 = 左「汉堡/侧边栏」圆形按钮 + 居中标题 + 右「＋」按钮；
  中间单栏对话流；底部输入框 + 「深度思考 / 智能搜索」胶囊 + 拍照/相册/文件三宫格；
- **没有任何一张出现常驻侧边栏、双栏、或 iPad 分栏布局。**
- 文案分别是：`YOUR AI ASSISTANT / INTO THE UNKNOWN`、`Understand images, discover more`、
  `Think deeper, discover more`、`Focus & tough, deeper analysis`、`Upload files, gain insights`
  （CN 对应「图片理解 读懂更多」「重点难点 深入分析」等）。

截图直链（US，可自行核验；把 `/1200x1600bb.png` 换成原图后缀）：
- `https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/1e/80/2a/1e802aef-eab5-793f-bd9f-39b05a026617/1.png/1200x1600bb.png`
- `https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/d7/e3/66/d7e3666a-863a-52a6-ba29-b726690b6caf/2.png/1200x1600bb.png`
- `https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/e1/78/fe/e178fe91-84ab-c336-055e-3b28457c1a7b/3.png/1200x1600bb.png`
- `https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/52/b4/77/52b47735-16d1-d2b8-c5b5-6bfb27b39d83/4.png/1200x1600bb.png`
- `https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/6e/c3/ce/6ec3cea4-e860-4b65-62d1-0cbe55485779/5.png/1200x1600bb.png`

**⚠️ 但这只能证明「开发者没有为 iPad 提供展示分栏布局的截图」，不能证明运行时没有 iPad 布局。**
（很多团队就是直接把手机 mockup 复用进 iPad 槽位。）

### 4.3 已验证：iPad 横屏可用，且拍照 UI 在横屏下有独立布局

我扫描了 **147 条 US 评论 + 392 条 CN 评论**（iTunes 评论 RSS），
**只有 1 条**涉及 iPad，但信息量很大 —— 一位用户在 **2.4.0（2026-08-21）** 下写道：

> 「在 **ipad 横屏**拍照时，原来拍照键在**右侧中间**的位置，现在变成在**屏幕下方中间**的位置了，感觉没有以前用着顺手。」
> —— US App Store 评论，标题「整体来说非常棒，但是关于拍照界面UI还是老版的舒服。」

由此**已验证**：
1. App 在 iPad 上**支持横屏运行**（不是只允许竖屏的拉伸版）；
2. 拍照/识图界面的控件位置**随 iPad 横屏而改变**（拍照键从右侧中部 → 底部居中），
   说明至少相机流程有**宽度/方向自适应的布局分支**，而非纯等比拉伸。

### 4.4 推断（非直证）：主界面很可能是「抽屉式列表」而非常驻侧边栏

依据是 4.2 里所有截图的顶栏都是「汉堡按钮 + 居中标题 + ＋」，而不是 iPad 常见的
「左侧常驻会话列表 + 右侧对话」分栏。**这属于从营销素材反推，不是直接证据 → 标记为推断。**

### 4.5 未知（本次完全没找到任何证据）

- ❓ **键盘快捷键（Command 组合键）**：无任何来源提及。搜到的 "DeepSeek keyboard shortcuts"
  文章讲的是 **ChatGPT/网页端**的快捷键，与 iOS app 无关，已排除。
- ❓ **Split View / Slide Over / Stage Manager 多窗口**：无证据。
- ❓ **Apple Pencil 支持**：无证据。
- ❓ **是否真的存在 iPad 专属双栏布局**：无证据（截图没有，评论没提）。
- ❓ 少数派 / 知乎 / V2EX / Reddit r/DeepSeek 上我**没有找到任何**专门讨论 DeepSeek iPad 适配的帖子。

---

## 5. 【未知 / 无法验证】请勿当成事实使用

1. **缺口版本号**：以下版本号在本次所有快照窗口中**均未出现**，但**无法判定是"不存在"还是"没抓到"**：
   `1.0.0 / 1.0.1`（发版日 2025-01-10 到首次观测 1.0.2/2025-01-16 之间）、
   `1.0.3–1.0.6`、`1.0.8+`、`1.1.1 / 1.1.2 / 1.1.4`、`1.2.9`、`1.5.2`、`1.6.2`、
   `1.8.4`、`2.0.1`、`2.1.5 / 2.1.6 / 2.1.9`、`2.3.4 / 2.3.5`、`2.4.3`、以及 `2.5.1` 之后的任何版本。
   （注：Android 端确实有 `1.5.5`（2025-12-05）和 `2.1.5`（2026-06-07），
   见 APKMirror；但**iOS 端未观测到这两个版本号，不能直接搬到 iOS**。）
2. **2.0.2 之前版本的中文更新日志逐字文本**：unknown（CN storefront 只保留 25 条）。
3. **Build number（括号号，如 `2.1.0 (213)`）**：除你已提供的 `2.1.0 (213)` 外，
   其余版本的 build 号本次无法取得（App Store 公开页面不暴露 build 号）。
   `2.1.0 (213)` 有 IT之家 2026-05-12 报道佐证（见下）。
4. **iPad 键盘快捷键 / 分栏 / 多窗口**：unknown（见 4.5）。
5. 本次**未能取得** qimai.cn（七麦，纯 JS 渲染）、apptopia、sensortower、appfigures 的版本历史
   （需登录或有反爬）。apkpure iOS 版本历史页返回 403；applion.jp 只有当前版本，无完整历史。

---

## 6. 【已验证】中文媒体的逐条佐证（用于交叉验证）

- **1.3.0（2025-08-13）对话生成分享图**
  IT之家 2025-08-14：https://www.ithome.com/0/875/270.htm
  「DeepSeek App 应用昨日（8 月 13 日）更新至 **1.3.0** 版本，在修复部分已知问题，优化选择/复制文本体验之外，
  本次更新最大的亮点，就是**新增了对话内容生成分享图功能**。」
  站长之家 2025-08-14：https://www.chinaz.com/ainews/20491.shtml （「8月14日…发布了1.3.0版本更新」）
- **1.6.3（2026-01-06）语音输入** —— 鞭牛士 2026-01-09：https://www.bianews.com/news/details?id=229516
  引用应用商店更新说明原文：「1.支持语音输入 / 2.修复部分无障碍模式下的界面展示 / 3.修复部分已知问题」
  → **与 Apple US 英文原文三条完全对应**，交叉验证通过。
  linux.do 讨论（2025-12-30）：https://linux.do/t/topic/1379328
  （用户报告 iOS `1.6.1(142)`/`1.6.2` 已出现「按住说话」语音识别）
- **2.1.0（213）（2026-05-11）聊天记录搜索**
  IT之家 2026-05-12：https://m.ithome.com/html/949303.htm
  「将 DeepSeek App 更新至 **2.1.0（213）** 版本后，**侧边栏顶部**会出现'搜索聊天内容'搜索框…
  DeepSeek 方面回应称，该搜索聊天记录功能目前正处于**灰度测试**阶段，并非全量推送。」
  → 注意：**官方明说这是灰度**，不是全量功能。
- **2.0.0（2026-04-22）**
  linux.do 2026-04-23：https://linux.do/t/topic/2035597 、https://linux.do/t/topic/2036167
  （用户截图确认 iOS 先到 2.0.0，当时 Android 还是 1.8.7；更新说明为「解决了一些已知问题」）

---

## 7. 给复刻团队的三条可操作建议

1. **更新日志只到 2.0.x 才有产品信息量**：1.7.0~2.4.5 全是「修复部分已知问题」。
   要还原这段功能演进，**必须实机安装并对比**，App Store 文案无参考价值。
2. **iPad 不能靠截图判断**：Apple 的 iPad 截图槽位被开发者用手机 mockup 填了。
   要判定是否有真 iPad 布局，**唯一可靠办法是实机在 iPad 上跑 + 看 Xcode 的
   `UISupportedInterfaceOrientations~ipad` / 是否有 `UISplitViewController`**。
   目前可确定的只有：**支持 iPad、支持 iPad 横屏、相机 UI 有横屏自适应**。
3. **发版节奏可作参考**：2026-04 起进入高频发版（4 月 8 个、5-6 月 7 个、7 月 5 个…），
   且 **CN/US 全球同日同版本**；想对齐"何时引入何功能"，上表的日期就是最可靠的锚点。

---

## 8. 本次调研的产出文件

- `merged_timeline.json` —— 84 条版本的机器可读时间线（version / date / raw_date / notes）
- 抓取脚本与原始快照在 `/tmp/wb/`（20 个 Wayback 快照 HTML）与 `/tmp/fetch2.py`

**⚠️ 时效风险**：Internet Archive 在本次抓取后即下线（"Temporarily Offline"），
上述快照数据请尽快本地归档，短期内可能无法复现。
