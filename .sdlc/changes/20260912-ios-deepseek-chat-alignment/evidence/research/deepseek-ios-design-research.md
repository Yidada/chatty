# DeepSeek iOS App 设计系统 / 品牌色 调研报告

- 调研日期：2026-09-12
- 目标 App：App Store 名称 “DeepSeek - AI Assistant”（CN: “DeepSeek - AI 智能助手”），开发者 Hangzhou DeepSeek Artificial Intelligence Co., Ltd
- 说明：每条结论都标注 **[官方]** / **[第三方]** / **[无法验证]**，并给出 URL。所有 hex 均为实测或原文摘录，未做任何推测性编造。

---

## 0. 先说三个会影响后续工作的更正

| 项目 | 任务书里的说法 | 实测结果 | 来源 |
|---|---|---|---|
| Bundle ID | `com.deepseek.app` | **`com.deepseek.chat`**（US / CN / JP 三个区一致） | [Apple iTunes Lookup API](https://itunes.apple.com/lookup?id=6737597349&country=us) [官方] |
| 版本 / 最低系统 | — | US 2.5.0，CN/JP 2.5.1；最低 **iOS 15.0**；上架 2025-01-10；体积 60,223,488 B | 同上 [官方] |
| 品牌主色 | 广泛报道 #4D6BFE | **#4D6BFE 已在官方一手来源证实**；但**官方 Web 设计系统里作为按钮/强调色的 brand-primary 是 `#3964FE`**，“同一 token 名在不同产品/版本取值不同”，见 §1.3 与 §3.3 | §1、§3 |

---

## 1. 品牌色

### 1.1 已证实（一手 / 近一手来源）

| Token / 用途 | 值 | 来源 URL | 官方/第三方 | 置信度 |
|---|---|---|---|---|
| Logo（鲸鱼图形 + `deepseek` 字标）填充色 | **`#4D6BFE`** | https://github.com/deepseek-ai/DeepSeek-Coder-V2/blob/main/figures/logo.svg | 官方（DeepSeek 自有 GitHub 仓库） | 高 |
| 同上（Wikimedia 镜像，整份 SVG 只有 1 个 fill） | **`#4d6bfe`** | https://upload.wikimedia.org/wikipedia/commons/e/ec/DeepSeek_logo.svg · 说明页 https://commons.wikimedia.org/wiki/File:DeepSeek_logo.svg | 官方作品、第三方托管 | 高 |
| `--ds-color-brand`（light，deepseek.com 官网 CSS） | **`#4d6bfe`** | https://www.deepseek.com/_next/static/css/8200fbc59b0ac2c5.css（` :root{...}` 块） | 官方（官网 CSS 产物） | 高 |
| `--ds-color-brand`（dark） | `#6799fe` | 同上 | 官方 | 高 |
| `--ds-color-brand-deep`（light） | `#3a65c2` | 同上 | 官方 | 高 |
| `--ds-color-brand-medium-reverse`（light） | `#4176e6` | 同上 | 官方 | 高 |
| `--ds-color-brand-light-reverse` | `#73a3d2` | 同上 | 官方 | 高 |
| `--ds-color-text-link-blue` | `#234792` | 同上 | 官方 | 高 |
| `--ds-color-static-black` | `#0f0f0f` | 同上 | 官方 | 高 |
| `--ds-color-static-white` | `#fff` | 同上 | 官方 | 高 |
| `--ds-color-bg-hero-join` | `#2e609f` | 同上 | 官方 | 高 |

**验证方法**：直接抓取官方 SVG 源码，正则统计 `fill="…"` —— 该文件 8 条字母路径 + 1 条鲸鱼路径**全部为 `#4D6BFE`**，无第二种颜色；Wikimedia 版本 CSS 类 `.st0{fill:#4d6bfe}`，全文仅此一个 fill。官网 CSS 里 `--ds-color-brand:#4d6bfe` 出现在 `:root`（light）块。

> 注：官网 `_next/static/css/<hash>.css` 文件名带构建 hash，重新部署会变。抓取时文件为 `8200fbc59b0ac2c5.css`（56,583 B）。

### 1.2 Logo 图形描述（实测自官方 SVG／App Store 图标）

- **Logo 版式**：左侧**鲸鱼（whale / 虎鲸式）图形** + 右侧小写 **`deepseek` 字标**，整体单一扁平 `#4D6BFE`，无渐变、无描边。[官方] viewBox `0 0 195.0227 41.3595`，2 条 path。
- **鲸鱼造型**：身体卷曲成近圆形、背部有背鳍、尾部上扬分叉、腹部留白形成负形，几何化、圆头圆角（rounded，非尖锐）。Wikimedia Commons 分类即为 `Whales in logos` + `Plain blue SVG emblems`。[官方/第三方托管]
- **字标**：小写 `deepseek`，几何无衬线（geometric sans），字重偏 medium/bold，单色。[官方]
- **App 图标**（App Store 官方作品，无损 PNG 1024×1024，无 ICC profile → 按 sRGB 解读）：**白色圆角方底 + 仅鲸鱼图形（无字标）**，鲸鱼是**蓝色渐变/立体渲染**，实测跨度约 **`#5472FF`（中心最深处）→ `#5D7AFF`（最亮处）**。属于品牌蓝家族，但**不等于扁平 `#4D6BFE`**。[官方] 取图路径：`https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/7d/08/9e/7d089efd-8f84-34e4-2fe0-dd10d8f47ed5/AppIcon-0-0-1x_U007epad-0-1-0-sRGB-85-220.png/1024x1024bb.png`（把 `bb.jpg` 换成 `bb.png` 可得无损 PNG）

### 1.3 ⚠️ 关键辨析：#4D6BFE ≠ App 内强调蓝

官方站点里有**两套并存的蓝**，务必区分：

| 语境 | 值 | 来源 | 官方/第三方 |
|---|---|---|---|
| 品牌 / Logo / 官网营销 token `--ds-color-brand` | `#4D6BFE` | 官方 logo.svg、官网 CSS | 官方 |
| 官网 Web 设计系统语义 token `--dsw-alias-brand-primary`（light）→ `--dsw-static-deepseek-500` | **`#3964FE`** | https://www.deepseek.com/_next/static/css/8200fbc59b0ac2c5.css | 官方 |
| 官方 Harness 仓库 master 分支 `--dsw-static-deepseek-500` | **`rgb(65,118,230)` = `#4176E6`** | https://raw.githubusercontent.com/deepseek-ai/deepseek-harness/master/packages/client/ui-theme/src/styles/design-platform.css | 官方（另一产品/更新版本） |
| **App 实机截图内的强调蓝**（chip 图标/文字） | **`#3964FE`** | 官方 App Store 截图 lossless PNG（见 §3.3） | 官方截图 |

结论：**“DeepSeek 蓝 = #4D6BFE” 对 Logo/品牌资产成立**；但**UI 组件里的 primary 按钮/chip 强调色在官方设计系统里是 `#3964FE`**（Harness 新版本改为 `#4176E6`）。三者不可混用，建议 iOS 端按“Logo 用 #4D6BFE、组件强调色用 #3964FE”分工，并向设计负责人确认。

---

## 2. 设计系统 / UI Kit / 设计规范

### 2.1 已找到（官方，但是 Web 端）

**DeepSeek Web 设计系统 `--dsw-*`**，以 npm 包形式开源在官方仓库：

| 项 | 值 / URL | 官方/第三方 | 置信度 |
|---|---|---|---|
| 包名 | `@deepseek-ai/dsh-client-ui-theme` | 官方 | 高 |
| 文档 | https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/ui-theme/README.zh.md | 官方 | 高 |
| Token 权威源文件 | https://raw.githubusercontent.com/deepseek-ai/deepseek-harness/master/packages/client/ui-theme/src/styles/design-platform.css | 官方 | 高 |
| 样式规则文档 | https://raw.githubusercontent.com/deepseek-ai/deepseek-harness/master/docs/web-styling.zh.md | 官方 | 高 |
| 官方站点上部署的同名 token | https://www.deepseek.com/_next/static/css/8200fbc59b0ac2c5.css | 官方 | 高 |

该设计系统覆盖：`--dsw-static-*` 静态色阶、`--dsw-alias-*` 语义别名、排版、圆角、阴影/层级、动效、渐变、滚动条，以及**明/暗主题偏好**。主题 id：`light` / `dark` / `system`；暗色通过 `body[data-ds-dark-theme]` 生效；正文字号 12–17px（默认 14px）。

> 文档明确写了“**token 样式表是颜色值的唯一权威来源**”“功能组件使用 `--dsw-alias-*` 语义 token，不得写入颜色字面量”。这对复刻团队是最有参考价值的一份官方材料。

### 2.2 ⚠️ 但注意

- 这是 **DSH（DeepSeek Harness）Web 客户端**的设计系统，**不是 iOS App 的设计系统**。它可作为“官方设计语言”的强证据，但不能直接当作 iOS 的 spec。
- `--dsw-*` 同时出现在 **www.deepseek.com 官网 CSS** 中（含 `--dsw-specific-bubble`、`--dsw-specific-sidebar-fill`、`--dsw-alias-markdown-code-block`、`--dsw-specific-login-input` 等聊天界面 token），说明**官网与 Web 聊天端共用同一套设计系统**；但 **chat.deepseek.com 本身无法直接抓取验证**（见 §5）。

### 2.3 未找到（重要缺口）

用中英文分别搜索 `DeepSeek design system`、`DeepSeek UI kit Figma`、`DeepSeek brand guidelines`、`DeepSeek design tokens`、`DeepSeek 设计规范`、`DeepSeek 设计系统` —— **没有找到任何官方发布的**：

- ❌ 官方 Figma 文件 / Figma Community 官方库
- ❌ 官方公开的 brand guidelines / VI 手册 PDF
- ❌ 官方 design token 文档站（如 zeroheight / supernova）

能找到的都是第三方：Dribbble 的 “ChatGPT + DeepSeek UI Kit – Free Figma File”（https://dribbble.com/shots/25562319-ChatGPT-DeepSeek-UI-Kit-Free-Figma-File，[第三方]，未验证数值）、`Devin-AXIS/deepseek-design`（[第三方] DSH 插件，非官方）。

---

## 3. iOS App 配色与排版

### 3.1 方法与可信度说明

所有 App 配色均为我从 **Apple 官方 App Store 截图**（US/CN 两区共 10 张：5 张 iPhone + 5 张 iPad）的**无损 PNG** 上采样得出。取图办法：把 iTunes API 返回的 `screenshotUrls` 中 `320x480bb.jpg` 替换为 `1284x2778bb.png.jpg`（iPad 为 `2048x2732bb.png.jpg`）即得无损 PNG。截图为 **未嵌入 ICC profile**，按惯例以 sRGB 解读。

**这套数据的价值**：截图中实测的灰阶与官方设计系统 token **逐一精确吻合**（见下），说明 App 确实沿用了同一套 `--dsw-*` 设计语言。这是我判断“App 与设计系统同源”的核心依据。

### 3.2 App 实测色（Light Mode）

| 用途 | 实测 hex | 与官方 token 的对应关系 | 来源 | 官方/第三方 | 置信度 |
|---|---|---|---|---|---|
| 页面背景 | **`#FFFFFF`** | `--dsw-static-neutral-bluish-00` / `--dsw-alias-bg-base`(light) | App Store 官方截图 | 官方截图 | 高 |
| 主要文字 | **`#0F0F0F`** | `--dsw-static-neutral-900` 且 `--ds-color-static-black` 完全一致 | 同上 | 官方截图 | 高 |
| 输入框 placeholder / 次级灰 | **`#A2A4A6`** | `--dsw-static-neutral-400` 完全一致 | 同上 | 官方截图 | 高 |
| 圆形图标按钮 / 卡片底色 | **`#F5F5F5`**（部分 `#F6F6F6`） | `--dsw-static-neutral-100` 完全一致 | 同上 | 官方截图 | 高 |
| 用户消息气泡底色 / 品牌浅底 | **`#EDF3FE`** | `--dsw-static-deepseek-50` 完全一致 | 同上 | 官方截图 | 高 |
| 品牌强调色（chip 图标/文字、选中态） | **`#3964FE`** | `--dsw-static-deepseek-500`（官网部署值）一致 | 同上 | 官方截图 | 高 |
| App 内鲸鱼 logo | **`#426EFE`** | 无完全对应 token（介于 deepseek-450 `#5686FE` 与 500 之间偏亮） | 同上 | 官方截图 | 中（渲染/缩放可能有偏差） |
| 品牌浅蓝次级面（出现于 3/4/5 图） | **`#D3E2FF`** | `--dsw-static-deepseek-200` 一致 | 同上 | 官方截图 | 中高 |
| 发丝分隔线 / 描边 | 约 `#F0F0F0` / `#F3F3F3` | 非 token（半透明描边叠加结果） | 同上 | 官方截图 | 中 |
| App 图标底 | `#FFFFFF` | — | Apple 图标 PNG | 官方 | 高 |
| App 图标鲸鱼渐变 | `#5472FF` → `#5D7AFF` | 品牌蓝家族，非扁平 token | 同上 | 官方 | 中高 |

**观测到的界面结构（用于对齐信息架构）**：顶部左「更多/菜单」圆形按钮 + 中标题 + 右「新建对话」圆形按钮；空态为鲸鱼 logo + “How can I help you?”；底部为圆角胶囊 composer（placeholder “Type a message or hold to speak”），内含 `Think` / `Search` chip、`+` 附件、语音输入按钮；composer 下方为建议缩略图与 `Camera` / `Photo` / `Document` 三宫格卡片。

### 3.3 官方设计系统语义 token（Light / Dark 对照，[官方]）

来源：https://www.deepseek.com/_next/static/css/8200fbc59b0ac2c5.css （`body` 与 `body[data-ds-dark-theme]` 两块）。**这是 Web 值，不是 iOS 实测值**，但 App 实测灰阶与之吻合，可作为暗色模式的**推断依据**。

| Token | Light | Dark |
|---|---|---|
| `--dsw-alias-brand-primary` | `#3964FE` (deepseek-500) | `#5686FE` (deepseek-450) |
| `--dsw-alias-brand-text` | `#3964FE` | `#679EFE` (deepseek-400) |
| `--dsw-alias-button-primary-fill` | `var(--dsw-alias-brand-primary)` | 同左 |
| `--dsw-alias-bg-base` | `#FFFFFF` | `#151517` |
| `--dsw-alias-bg-layer-1` | `#FFFFFF` | `#232324` |
| `--dsw-alias-bg-layer-2` | `#FFFFFF` | `#2C2C2E` |
| `--dsw-alias-bg-layer-3` | `#FFFFFF` | `#353638` |
| `--dsw-alias-bg-overlay` | `#E9ECF2` | `#43454A` |
| `--dsw-alias-label-primary` | `#0F1115` | `#F9FAFB` |
| `--dsw-alias-label-secondary` | `#61666B` | `#CFD3D6` |
| `--dsw-alias-label-tertiary` | `#81858C` | `#ADB2B8` |
| `--dsw-alias-label-caption` | `#ADB2B8` | `#81858C` |
| `--dsw-alias-border-l1` | `rgba(0,0,0,.04)` | `rgba(255,255,255,.06)` |
| `--dsw-alias-border-l2` | `rgba(0,0,0,.1)` | `rgba(255,255,255,.12)` |
| `--dsw-alias-border-l3` | `rgba(0,0,0,.12)` | `rgba(255,255,255,.16)` |
| `--dsw-alias-border-l4` | `rgba(0,0,0,.16)` | `rgba(255,255,255,.2)` |
| `--dsw-alias-interactive-bg-hover` | `rgba(38,49,72,.06)` | `rgba(255,255,255,.08)` |
| `--dsw-alias-interactive-bg-active` | `rgba(38,49,72,.1)` | `rgba(255,255,255,.14)` |
| `--dsw-alias-bg-skeleton` | `rgba(0,0,0,.04)` | `rgba(255,255,255,.08)` |
| `--dsw-specific-bubble` | `#EDF3FE` (deepseek-50) | `#2C2C2E` |
| `--dsw-specific-bubble-highlight` | `#D3E2FF` (deepseek-200) | `#43454A` |
| `--dsw-specific-sidebar-fill` | `#F9FAFB` | `#1B1B1C` |
| `--dsw-specific-sidebar-nav-item-hover` | `#F1F3F5` | `#2C2C2E` |
| `--dsw-specific-sidebar-nav-item-active` | `#EBEEF2` | `#43454A` |
| `--dsw-specific-input-major` | `#FFFFFF` | `#2C2C2E` |
| `--dsw-specific-login-input` | `#F9FAFB` | `#1B1B1C` |
| `--dsw-specific-selector` | `#F1F3F5` | `#43454A` |
| `--dsw-specific-tip` | `#F5F6F7` | `#353638` |
| `--dsw-alias-markdown-code-block` | `#F9FAFB` | `#1B1B1C` |
| `--dsw-alias-markdown-inline-code` | `#EBEEF2` | `#2C2C2E` |
| `--dsw-alias-state-error-primary` | `#EC1313` | `#F25A5A` |
| `--dsw-alias-state-success-primary` | `#22C55E` | `#22C55E` |
| `--dsw-alias-state-warn-primary` | `#F59E0B` | `#F59E0B` |

### 3.4 官方色阶（[官方]，来源同上 + Harness design-platform.css）

**DeepSeek 蓝阶 `--dsw-static-deepseek-*`**

| Step | 官网部署值 | Harness master 值 |
|---|---|---|
| 50 | `#EDF3FE` | `rgb(237,243,254)` = `#EDF3FE` |
| 100 | `#E4EDFD` | `rgb(228,237,253)` = `#E4EDFD` |
| 200 | `#D3E2FF` | `rgb(211,226,255)` = `#D3E2FF` |
| 300 | `#B7C8FE` | `rgb(183,200,254)` = `#B7C8FE` |
| 400 | `#679EFE` | `rgb(103,158,254)` = `#679EFE` |
| 450 | `#5686FE` | `rgb(86,134,254)` = `#5686FE` |
| 500 | `#3964FE` | `rgb(65,118,230)` = **`#4176E6`** ⚠️ 版本差异 |
| 600 | `#4868B2` | `rgb(72,104,178)` = `#4868B2` |
| 700 | `#2F4C8F` (delete 用) | `rgb(47,76,143)` |
| 800 | `#34415B` | `rgb(52,65,91)` |
| 900 | `#283142` | `rgb(40,49,66)` |

**中性偏蓝阶 `--dsw-static-neutral-bluish-*`（light 端 → dark 端）**：[官方]
`00 #FFFFFF` · `50 #F9FAFB` · `60 #F5F6F7` · `75 #F1F3F5` · `100 #EBEEF2` · `150 #E9ECF2` · `200 #E1E5EE` · `300 #CFD3D6` · `400 #ADB2B8` · `500 #979DA6` · `600 #81858C` · `700 #61666B` · `750 #43454A` · `800 #353638` · `850 #2C2C2E` · `875 #232324` · `900 #1B1B1C` · `950 #151517` · `1000 #0F1115`

**中性阶 `--dsw-static-neutral-*`**：[官方]
`00 #FFFFFF` · `50 #FAFAFA` · `100 #F5F5F5` · `150 #EDEDED` · `200 #E5E5E5` · `250 #DCDCDC` · `300 #D4D4D4` · `400 #A2A4A6` · `500 #7F8287` · `550 #65676B` · `600 #545557` · `700 #3C3C3D` · `800 #292929` · `850 #212123` · `900 #0F0F0F` · `1000 #000000`

### 3.5 排版（[官方 Web 设计系统值] — 非 iOS 实测）

来源：Harness `design-platform.css` 与 `gradient-shadow-text.css`。

| Token | 值 |
|---|---|
| `--dsw-font-family` | `-apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', …`（**系统字体栈** → iOS 上即 SF Pro + PingFang SC） |
| `--ds-font-body`（官网营销） | `"DM Sans", system-ui, -apple-system, …, "Noto Sans SC","PingFang SC", sans-serif` |
| `--ds-font-mono` / 代码 | `"Fragment Mono","Roboto Mono",ui-monospace,monospace` |
| `--dsw-font-base-16` | 400 · 16px / 24px |
| `--dsw-font-base-strong-16` | 500 · 16px / 24px |
| `--dsw-font-m-18` | 500 · 16px / 28px（token 名 18，字号实为 16） |
| `--dsw-font-l-20` | 500 · 20px / 28px |
| `--dsw-font-s-14` | 400 · 14px / 22px |
| `--dsw-font-s-strong-14` | 500 · 14px / 22px |
| `--dsw-font-xs-13` | 400 · 13px / 20px |
| `--dsw-font-xs-strong-13` | 500 · 13px / 20px |
| `--dsw-font-markdown-base` | 400 · `{正文号}`默认 14px / 24px |
| `--dsw-font-markdown-base-strong` | 600（Markdown 加粗） |
| `--dsw-font-markdown-code-block` | 400 · 11px / 19px |

**正文字号可调 12–17px，默认 14px**；会话正文与标题联动，表格/流内行低一档。此机制是 **Web 端**的，**iOS 是否支持 Dynamic Type 未验证**（见 §4）。

### 3.6 圆角 / 间距 / 阴影（[官方]）

| 类别 | Token | 值 |
|---|---|---|
| 圆角 | `--ds-radius-pill` | `100px` |
| 圆角 | `--ds-radius-card` | `24px` |
| 圆角 | `--ds-radius-panel` | `16px` |
| 圆角 | `--ds-radius-media` | `12px` |
| 圆角 | `--ds-radius-input` | `10px` |
| 圆角 | `--ds-radius-sm` | `8px` |
| 圆角（组件） | `--dsl-button-border-radius` | `8px` / `10px` / `4096px`(胶囊) / `50%` |
| 圆角（组件） | `--dsl-toast-border-radius` | `12px` |
| 圆角 | `--dsl-a-border-radius` | `6px` |
| 间距 | `--ds-space-1…13` | `4, 8, 12, 16, 24, 32, 40, 56, 80, 120, 160, 200, 240` px |
| 阴影 | `--dsw-shadow-lv1` | `0 2px 4px 0 rgba(0,0,0,.05)` |
| 阴影 | `--dsw-shadow-lv2` | `0 4px 12px 0 rgba(0,0,0,.02), 0 2px 8px 0 rgba(0,0,0,.04)` |
| 阴影 | `--dsw-elevation-stroke` | `0 0 0 0.5px var(--dsw-elevation-stroke-color)`（发丝描边） |
| 阴影（官网卡片） | `--ds-shadow-card` | `0 0 0 1px #f1f5f9, 0 2px 4px rgba(0,0,0,.05), 0 12px 24px rgba(0,0,0,.05)` / dark: `hsla(0,0%,100%,.12) 0 1px 0 0 inset` |
| 模糊 | `--ds-blur-glass` | `12px` |
| 形状 | `--dsw-corner-shape` | `superellipse(1.5)`（连续圆角 / squircle，`@supports` 内生效；圆形与胶囊须配对 `corner-shape: round`） |

> **发丝线规范**：官方样式规则要求中性 `--dsw-alias-border-*` 平面边框/分割线一律 **0.5px**；dashed 与状态色 border 保持 1px。这对 iOS 端 1px/@3x 处理有直接参考意义。

### 3.7 图标风格（观测，非官方声明）

从官方截图观测：**描边式（outline）、圆角端点、线宽均匀**的极简图标（`+`、麦克风、相机、图片、文档、搜索、chevron、菜单），chip 为「小图形 + 文字」胶囊。视觉上高度接近 **SF Symbols**，且顶部圆形按钮、composer 胶囊、sheet/确认按钮等交互范式符合 iOS 习惯 —— **但没有任何官方材料确认使用 SF Symbols**，故此项为 **[无法验证]/[推断]**。

---

## 4. HIG / SF Symbols / Dynamic Type / 深色模式与主题设置

| 问题 | 结论 | 证据 | 判定 |
|---|---|---|---|
| App 有主题设置吗？ | **有**。路径：左上角「更多」图标 → 账户头像 → 【应用】栏 →【颜色主题】 | https://m.xinhuaedu.cn/gl/3172sxde.html（2026-06-11）· https://app.ali213.net/gl/1612921.html（2025-04-16） | **[第三方教程]** 中 |
| 有哪几个选项？ | 第三方教程明确写：可选 **浅色 / 深色** 两项，选后点【确认】 | 同上（原文：“目前DeepSeek可以修改的颜色是**浅色和深色**”） | **[第三方]** 中 |
| 有「跟随系统」选项吗？ | **未能证实**。两份教程都只提到浅色/深色，均未提「跟随系统」。也无法确认是 iOS 还是 Android 界面 | 同上 | **[无法验证]** |
| 官方 App Store 是否提及深色模式/主题？ | **没有**。US/CN/JP 三区 App 描述与 release notes 均无 dark/theme/深色/主题 字样 | [iTunes API](https://itunes.apple.com/lookup?id=6737597349&country=cn) | 已核实为“无” |
| **App 深色模式具体配色** | **无法验证**。官方 10 张截图（US/CN × iPhone/iPad）**全部为浅色 UI**，无一张深色界面 | 官方 App Store 截图 | **[无法验证]** |
| 是否遵循 Apple HIG？ | 只能从截图观测：使用系统状态栏、圆角卡片、胶囊输入框、圆形工具栏按钮、sheet 式确认，观感符合 HIG —— 但**无官方声明** | 官方截图 | **[推断]** |
| 是否用 SF Symbols？ | 无官方声明；图标形态接近但未证实 | — | **[无法验证]** |
| 是否支持 Dynamic Type？ | 无官方声明。设计系统确有 12–17px 字号调节机制，但那是 **Web 端**的；iOS 端未证实 | Harness README（Web） | **[无法验证]** |
| 最低系统 | iOS 15.0 | iTunes API | **[官方]** 高 |

⚠️ **常见误读警告**：`deepseek-harness` 的 Web 客户端**确实**支持 `light / dark / system` 三态 + 12–17px 字号，但那是 **DeepSeek Harness Web GUI**，**不是 iOS App**。不要在报告里把它当成 iOS 的行为。

---

## 5. chat.deepseek.com 的 CSS / design token

**结论：无法验证（被 WAF 拦截）。**

| 尝试 | 结果 |
|---|---|
| `web_fetch https://chat.deepseek.com/` | **HTTP 403**（CloudFront: “Request blocked”） |
| `curl` + 浏览器 UA | **HTTP 202**，正文为 **AWS WAF 挑战页**（`window.awsWafCookieDomainList = ['deepseek.com','www.deepseek.com','chat.deepseek.com',…]`），无任何 CSS |
| 搜索 GitHub 上 chat.deepseek.com 的 CSS 提取 | 未找到可信的 token 提取仓库/代码 |

**可用的间接证据（推断）**：`www.deepseek.com` 的 CSS 产物里**打包了完整的 `--dsw-*` 聊天界面 token**（`--dsw-specific-bubble`、`--dsw-specific-sidebar-fill`、`--dsw-alias-markdown-code-block`、`--dsw-specific-login-input`、`--dsw-alias-toast-bg` 等），说明 DeepSeek 的 Web 端共用同一套设计系统。**因此可以合理推断 chat.deepseek.com 也使用 §3.4–§3.6 的 token**，但**我未能直接证实**，请按 [推断] 使用。

第三方项目（均非官方，仅供参考，未验证其数值准确性）：
- `NullCipherr/matugen-stylus` — DeepSeek-8Bit UserStyle（https://github.com/NullCipherr/matugen-stylus）
- Greasyfork “DeepSeek-Refined”（https://greasyfork.org/en/scripts/585012-deepseek-refined）

---

## 6. 开源复刻 / Clone 项目的实际数值（全部 [第三方]，仅供参考）

| 仓库 | 关键数值 | 是否与官方一致 | 置信度 |
|---|---|---|---|
| [clzwqoii/deepseek-chat-clone](https://github.com/clzwqoii/deepseek-chat-clone)（自称 “pixel-perfect”） | `src/app/globals.css` 是**原样 shadcn/ui 默认 token**：`:root{--background:0 0% 100%; --foreground:0 0% 3.9%; --card:0 0% 100%; --primary:0 0% 9%; --border:0 0% 89.8%; --radius:0.5rem}`；`.dark{--background:240 10% 3.9%; --primary:0 0% 98%; …}`；滚动条 `#27272a` / `#52525b` / `#71717a` | ❌ **完全不含 DeepSeek 品牌色**（`--primary` 是近黑，非蓝）；**不要把它的值当 DeepSeek 规范** | 高（我已读全文） |
| [GrowWithMehran/DeepSeek-Chat-Clone](https://github.com/GrowWithMehran/DeepSeek-Chat-Clone) | `style.css` `:root{--primary:#2d6df6; --primary-light:#e8f0fe; --text-primary:#1a1a1a; --text-secondary:#666; --bg-color:#ffffff; --sidebar-bg:#f8f9fa; --border-color:#e5e7eb; --chat-bg:#f9fafb; --user-message-bg:#f0f4ff; --ai-message-bg:#ffffff; --shadow:0 1px 3px rgba(0,0,0,.1)}` | ❌ `#2d6df6` ≠ 官方 `#4D6BFE`，属**作者自拟近似** | 高（已读原文） |
| [elyse502/deepseek-clone](https://github.com/elyse502/deepseek-clone) | `app/globals.css`：`@theme{--color-primary:#4d6bfe}`；`pre{border-radius:10px}` | ✅ **主色与官方一致**（`#4d6bfe`）；圆角 10px 与 `--ds-radius-input` 巧合一致 | 高（已读原文） |
| [fakingai/deepseek-clone](https://github.com/fakingai/deepseek-clone) · [NishantRajiitkgp/deepseek-clone](https://github.com/NishantRajiitkgp/deepseek-clone) · [Kanokpol-Natekuakul/deepseek_clone](https://github.com/Kanokpol-Natekuakul/deepseek_clone) | 未逐个核对 CSS | 未知 | 低 |

**总结**：clone 生态里**只有极少数用到正确的 `#4D6BFE`**，多数用 shadcn 默认色或自拟蓝（如 `#2d6df6`）。**它们全部是第三方近似，不能作为官方规范引用**；对 iOS 复刻而言，§2.1 的官方 `--dsw-*` token 比任何 clone 都可靠。

---

## 7. 结论与给 iOS 团队的建议取值

**可直接采用（官方一手证据充分）**
- 品牌 / Logo 主色：`#4D6BFE`（官方 logo.svg + 官网 `--ds-color-brand`）
- 组件强调蓝（primary button / chip / toggle 选中）：`#3964FE`（官方设计系统 `deepseek-500`，且与官方 App 截图实测一致）
- 中性色阶与语义别名：直接用 §3.4 的官方 `--dsw-static-*` 与 §3.3 的 `--dsw-alias-*`
- 圆角 / 间距 / 阴影：§3.6 官方 token 原值
- 字体：系统字体栈（iOS → SF Pro + PingFang SC）
- 发丝线：0.5px
- 明暗两套语义别名齐备（暗色值同样来自官方 CSS）

**需谨慎（有版本分歧）**
- `deepseek-500` 在官网部署是 `#3964FE`、在 Harness master 是 `#4176E6`。建议以**官网部署值 `#3964FE`** 为准（因为与 App 截图实测吻合），并向设计负责人确认。

**明确无法验证（不要当成事实写进 spec）**
1. **iOS App 的深色模式配色**（官方截图全是浅色）
2. 主题设置是否含「**跟随系统**」（第三方教程只说浅色/深色）
3. 是否使用 **SF Symbols**、是否支持 **Dynamic Type**、是否严格遵循 HIG
4. **chat.deepseek.com 的真实 CSS/token**（AWS WAF 拦截）
5. 是否存在官方 **Figma / brand guidelines / 公开设计规范**
6. App 内鲸鱼 logo 到底是 `#426EFE` 还是 `#4D6BFE`（截图实测 `#426EFE`，与官网上扁平 logo 不完全一致，疑为渲染差异）

---

## 8. 来源清单

**官方一手**
- 官方 Logo SVG：https://github.com/deepseek-ai/DeepSeek-Coder-V2/blob/main/figures/logo.svg
- Wikimedia Logo 镜像：https://upload.wikimedia.org/wikipedia/commons/e/ec/DeepSeek_logo.svg
- 官网设计系统 + 品牌 token CSS：https://www.deepseek.com/_next/static/css/8200fbc59b0ac2c5.css
- 官网组件 token CSS：https://www.deepseek.com/_next/static/css/826310b8bcf73c16.css
- 官方设计系统包文档：https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/ui-theme/README.zh.md
- 官方 token 源文件：https://raw.githubusercontent.com/deepseek-ai/deepseek-harness/master/packages/client/ui-theme/src/styles/design-platform.css
- 官方 Web 样式规则：https://raw.githubusercontent.com/deepseek-ai/deepseek-harness/master/docs/web-styling.zh.md
- App Store 元数据：https://itunes.apple.com/lookup?id=6737597349&country=us （`cn` / `jp` 同）
- 官方 App 图标（无损 PNG）：`…/AppIcon-0-0-1x_U007epad-0-1-0-sRGB-85-220.png/1024x1024bb.png`

**第三方**
- 主题设置教程：https://m.xinhuaedu.cn/gl/3172sxde.html · https://app.ali213.net/gl/1612921.html
- Brandfetch：https://brandfetch.com/deep-seek.ai （**403，未能读取，未采信**）
- UIColours：https://uicolours.com/brands/deepseek （第三方整理：`#4D6BFE` / `#4166D5` / `#292a2d` / `#f9fbff`）
- Clone：见 §6

**尝试但失败**
- https://chat.deepseek.com/ → 403 / AWS WAF 202
- https://www.hardreset.info/devices/apps/apps-deepseek/change-colour-scheme/ → Cloudflare 403（含 r.jina.ai 代理亦被拦）
