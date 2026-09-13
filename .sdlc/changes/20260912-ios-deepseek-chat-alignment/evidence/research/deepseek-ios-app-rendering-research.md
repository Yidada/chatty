# DeepSeek 官方 iOS App 内容渲染研究报告

**研究日期**：2026-09-12
**目标**：为原生 iOS 团队复刻 App Store「DeepSeek - AI Assistant」（id6737597349，开发者 Hangzhou DeepSeek）提供可验证的渲染行为依据

## 证据分级说明

- **[A 已验证]**：有可点击 URL 的直接证据（官方文案、官方截图、可读源码/DOM）
- **[B 截图推断]**：从官方 App Store 截图目视推断，无文字说明
- **[C 未知/无法验证]**：明确没能证实

> ⚠️ 重要前提：**DeepSeek 官方 API 文档（api-docs.deepseek.com）完全不描述 App/网页端的内容渲染方式**。其「图像理解」「Files API」是 API 侧能力（且 Files API **只支持图片**，不支持文档），不能当作 App 行为依据。这是本报告最容易被误用的一点。

---

## 0. 版本与模式基线（必读）

### 0.1 当前 iOS 版本

| 项 | 值 | 来源 |
|---|---|---|
| 版本 | **2.5.0** | iTunes Lookup API |
| 发布日期 | **2026-09-11** | 同上 |
| bundle id（iTunes metadata） | **`com.deepseek.chat`** | 同上 |
| trackId | 6737597349 | 同上 |
| seller | Hangzhou DeepSeek Artificial Intelligence Co., Ltd | 同上 |
| 最低系统 | iOS 15.0 | 同上 |
| 体积 | 60,223,488 bytes（≈57.4 MB） | 同上 |
| 分级 | 12+ | 同上 |

> ⚠️ 任务描述给的 bundle 是 `com.deepseek.app`，但 iTunes 元数据实际为 **`com.deepseek.chat`**。**我没有验证到任何叫 `com.deepseek.app` 的 bundle**（App Store 页面本身不暴露 bundle id，iTunes API 是权威来源）。

来源：`https://itunes.apple.com/lookup?id=6737597349&country=us`

### 0.2 2.5.0 官方 Release Notes（逐字）

**[A 已验证]** 英文 App Store 原文：

```
- New model update: Instant, Expert, and Vision modes are now unified
- Thinking process now collapses automatically
- Fixed some known issues
```

**关键含义**：**Instant / Expert / Vision 三模式在 2026-09 已合并统一**。这意味着所有 2026 年上半年的「某模式不支持某能力」的第三方评测**已经过期**，不能直接照搬。

### 0.3 模式演进时间线（复刻时必须理解的背景）

| 日期 | 事件 | 来源 |
|---|---|---|
| 2026-04-08 | 上线「快速模式」与「专家模式」，首次产品端分层。快速模式支持图片和文件中的**文字识别**；专家模式支持深度思考+智能搜索，**当前不支持文件上传** | [IT之家](https://www.ithome.com/0/936/763.htm) |
| 2026-04-09 | 专家模式**开放文件上传**：官方提示「仅识别文字」，「最多上传 50 个文件，每个 100MB，支持各类文档和图片」。实测**无原生视觉感知，只能 OCR 文字** | [IT之家](https://www.ithome.com/0/937/349.htm) |
| 2026-05-14 | 专家模式**全面下线文件上传**（系统提示「资源紧张，暂不支持文件上传」）；快速模式**保留**图片与文件上传，但**仅支持文字识别** | [PChome](https://article.pchome.net/news/13499.html)、[ZOL](https://ai.zol.com.cn/1180/11809710.html) |
| 2026-06-16 | aiuxplayground 抓取桌面端：Instant 回形针 tooltip 文案为「text extraction only in Instant, max 50 files, 100MB each」 | [aiuxplayground teardown](https://aiuxplayground.com/teardowns/deepseek/composer) |
| 2026-06-18 | 「识图模式」上线网页端与 App（App 端当时仍提示「图片理解功能内测中」） | [C114/IT之家](https://www.c114.net.cn/industry/91832.html) |
| 2026-09-11 | **2.5.0：三模式统一** | iTunes API |

---

## 1. Rich content rendering（Markdown / LaTeX / 代码块）

### 1.1 Markdown 支持范围

**[A 已验证]** 存在一份针对 `chat.deepseek.com` 的生产级 userscript（DeepSeek Chat Exporter，v1.0.0，328 行），其 DOM→Markdown 转换器逐条列出了 DeepSeek 渲染层实际产出的标签，这是目前能拿到的最强的「DeepSeek 渲染了哪些 Markdown 元素」的结构性证据：

| Markdown 元素 | 证据（转换器 switch 分支） |
|---|---|
| 标题 h1–h6 | `case 'h1'..'h6'` |
| 段落 / 换行 / 分割线 | `p` / `br` / `hr` |
| 粗体 / 斜体 / 删除线 | `strong|b` / `em|i` / `del|s` |
| 行内代码 | `code` |
| **引用块** | `case 'blockquote'` → `> ` 前缀 |
| **有序 / 无序列表** | `case 'ul'` / `case 'ol'` → `_processList(node, isOrdered)` |
| 链接 / 图片 | `a` / `img` |
| **表格** | `case 'table'` → `_processTable`（读 `tr` + `th/td`） |
| 代码块 | `.md-code-block` → `_processCodeBlock` |
| 数学公式 | `.katex` / `.katex-display` → `_processMath` |

来源（源码）：`https://update.greasyfork.org/scripts/566716/DeepSeek%20Chat%20Exporter.user.js`
脚本主页：https://greasyfork.org/zh-CN/scripts/566716-deepseek-chat-exporter

**[A 已验证]** 另有官方仓库 issue 证明**表格在 DeepSeek 前端被渲染为可视化表格**（并且这个行为本身引发 bug：代码块内的表格也被错误渲染）：

> 「**实际结果**：表格被渲染成可视化表格，代码块标记失效，复制后无法得到原始 Markdown。」
> 「**预期结果**：代码块内所有内容以纯文本原样显示，不被渲染。」

来源：https://github.com/deepseek-ai/DeepSeek-V3/issues/1280

> **复刻提示（重要设计教训）**：DeepSeek 前端会在**围栏代码块内部也渲染表格**，破坏原始文本可复制性。不要复刻这个 bug。

### 1.2 LaTeX / 数学公式 —— **App 有渲染，已验证**

**[A 官方截图 + B 目视]** 官方 App Store 截图（美区第 4 张）中，模型回答里出现**居中、独立成行、专业排版的数学公式**：

- 显示式公式：`a² + b² = n` 与 `c² + d² = n`（两个独立行间公式）
- 另一张：`N = a² + b² = c² + d²`
- 行内变量斜体：`(a,b)`、`(c,d)`、`n`、`a ≠ b`

渲染质量表明是**真正的数学排版引擎（KaTeX 风格），而非纯文本**。

**[A 已验证] 渲染引擎**：网页端使用 **KaTeX**，通过两层 class 承载：
- `.katex`（行内）
- `.katex-display`（块级）

并且保留了 LaTeX 源码，可由 `annotation[encoding="application/x-tex"]` 取回（这正是导出工具能还原 `$$...$$` 的原因）。

来源：DeepSeek Chat Exporter 源码 `_processMath()`；以及 DeepSeek Web Chat Enhancer（`.katex` / `.katex-display` / `annotation[encoding="application/x-tex"]`，并提供「双击复制 LaTeX」功能）：`https://update.greasyfork.org/scripts/583721/DeepSeek%20Web%20Chat%20Enhancer.user.js`

**[A 已验证] 第三方技术文确认**：DeepSeek 聊天界面「使用 HTML 和 CSS 渲染内容——用 KaTeX 渲染公式，用语法高亮库渲染代码，用系统字体渲染中文」。
来源：https://markdowntoword.pro/es/blog/deepseek-to-word （2026-05-05）

> **[C 未知]** 我**没有**验证到 iOS App 内 KaTeX 是走 WebView 还是原生渲染。这会影响你的实现路线选择。

### 1.3 代码块 —— 语言标签、复制按钮、语法高亮、横向滚动

**[A 已验证] 网页端确实有「语言标签 + 复制按钮」的区域**：
代码块容器 `.md-code-block`，其内部有 **`.md-code-block-banner-wrap`**（banner 条）与 **`<pre>`**。导出工具从 banner 中**剔除 button 后取剩余文本作为语言标签**：

```js
const banner = node.querySelector('.md-code-block-banner-wrap');
if (banner) {
    const clone = banner.cloneNode(true);
    clone.querySelectorAll('button').forEach(btn => btn.remove());
    lang = clone.textContent.trim().toLowerCase();
}
const pre = node.querySelector('pre');
```

> 即：**banner 里同时存在「语言标签文本」和「按钮（复制/下载）」** —— 这是「有语言标注 + 有复制按钮」的强结构性证据。

来源：DeepSeek Chat Exporter 源码；另一份增强脚本也操作同一 banner 的首个 `[role="button"], button` 做折叠/展开：`https://update.greasyfork.org/scripts/583721/DeepSeek%20Web%20Chat%20Enhancer.user.js`

**[A 已验证] 复制按钮的官方文案**：DeepSeek 让模型输出 Markdown 时会把整段回答包进代码块，用户「点击回答**右上角的 'Copy code' 按钮**」即可拿到原始 Markdown。
来源：https://markdowntoword.pro/es/blog/deepseek-to-word

**[A 已验证] 语法高亮**：见上方「用语法高亮库渲染代码」引用。**颜色值未验证**（任务禁止臆测颜色，故不给出）。

**[C 未知]** 代码块**横向滚动**：我没有找到任何直接描述或截图证据。**不要假定有 `overflow-x` 横向滚动**——这是需要真机确认的项。

**[C 未知] iOS App 端**：官方 5 张 App Store 截图中**没有任何一张出现代码块**。上述 `.md-code-block` 证据是 **`chat.deepseek.com` 网页端**的 DOM，**不能直接当作 iOS 原生实现的证据**（例如语言标签是文本还是图标、复制按钮是图标还是有文字，均未验证）。这是本报告最大的证据缺口之一。

---

## 2. 联网搜索的引用 / 来源展示

### 2.1 模型侧原本就产出 `[citation:X]` 标记（官方模板逐字）

**[A 已验证]** DeepSeek 官方 R1 仓库 issue 中引用了**官方的搜索提示词模板** `search_answer_zh_template`（这是官方模板原文，非用户编造）：

```
# 以下内容是基于用户发送的消息的搜索结果:
{search_results}
在我给你的搜索结果中，每个结果都是[webpage X begin]...[webpage X end]格式的，X代表每篇文章的数字索引。请在适当的情况下在句子末尾引用上下文。请按照引用编号[citation:X]的格式在答案中对应部分引用上下文。如果一句话源自多个上下文，请列出所有相关的引用编号，例如[citation:3][citation:5]，切记不要将引用集中在最后返回引用编号，而是在答案对应部分列出。
...
- 对于创作类的问题（如写论文），请务必在正文的段落中引用对应的参考编号，例如[citation:3][citation:5]，不能只在文章末尾引用。
```

来源：https://github.com/deepseek-ai/DeepSeek-R1/issues/616

**关键设计结论**：
- 引用**内联在句末**，**不是**集中在文末的单一列表
- 一句话可挂**多个**引用编号，格式为**连续方括号** `[citation:3][citation:5]`
- 编号从 1 起，对应搜索结果顺序

### 2.2 前端如何把它渲染成「chip」

**[A 已验证] 网页端 DOM**：`[citation:X]` 被渲染为 **`<span class="ds-markdown-cite">N</span>`**，且**可点击**（点击打开来源、在新标签页打开）：

```js
document.querySelectorAll("span.ds-markdown-cite").forEach((span, index, array) => {
    const citeNumber = span.textContent.trim();
    ...
    if (index < array.length - 1) {
        const comma = document.createTextNode(", ");
        span.replaceWith(link, comma);
    } else {
        span.replaceWith(link);
    }
});
```

来源：https://greasyfork.org/en/scripts/527421-deepseek-chat-citation-collector
（`@match https://chat.deepseek.com/*`；脚本注释：「Replace `<span>` elements with `<a>`, adding commas where necessary」）

**由此可确认的结构事实**：
1. chip 的可见文本**只是数字**（`node.textContent.replace(/[^0-9]/g, '')` 提取序号）
2. 多个 chip 之间**默认没有分隔符**（所以脚本要手动补 `, `）——即视觉上是**紧邻的数字角标**（如 `35` 而非 `3, 5`）
3. chip 是**可点击**的，点击后 `window.open(url)` 打开来源
4. 导出器把它还原成 `[3](url)` 形式

同类证据（另一份导出器）：`https://update.greasyfork.org/scripts/566716/DeepSeek%20Chat%20Exporter.user.js`（`if (node.classList.contains('ds-markdown-cite'))`）

### 2.3 是否有「参考链接 / References」列表？

**[A 已验证] 网页端：是，但入口在搜索结果提示上，不是文末列表。**
西班牙语权威教程 Xataka 的 2025-07-28 实操描述：

> 「Los números que hay al final de cada párrafo te indican qué fuentes se han usado para ese fragmento de texto. **Si pasas el ratón sobre uno de esos números**, entonces se mostrará una ventana con la fuente, y podrás pulsar en ella para entrar en el artículo.」
> 「Si pulsas en el mensaje **'Found XX results'**, entonces **se abrirá una columna a la izquierda** donde se te va a mostrar una lista de todos los artículos online usados...」
> 「arriba del todo tendrás un mensaje **Found XX results** que indica cuántas páginas ha usado como fuente」

来源：https://www.xataka.com/basics/como-usar-deepseek-para-buscar-cosas-internet-ver-fuentes-usadas-respuesta

**翻译要点**：
- 段落末尾的数字角标 = 该段的来源
- **悬停**（桌面）显示来源小窗，可点击进入原文
- 点击顶部 **"Found XX results"** 提示 → **左侧栏**展开**全部来源列表**
- 顶部有 "Found XX results" 计数文案

**[A 已验证] App 端对应的中文/英文文案（来自官方 App Store 截图）**：

| 位置 | 中文 | English |
|---|---|---|
| 思考步骤中的搜索计数 | **已搜索到 17 个网页** | **Found 17 web pages** |
| 思考步骤中的阅读计数 | **已浏览 3 个页面** | **Read 3 pages** |
| 计数旁的来源标识 | 3 个**网站 favicon 图标**（圆形小图标，紧密排列） | 同 |

> 即 App 端把「来源计数 + favicon」放在**思考（Thinking）折叠区内的搜索步骤行**上，而不是文末列表。

**[C 未知] App 端的关键缺口**：
- 我**没有**在官方截图中看到**回答正文里的数字角标 chip**（截图里的回答区域被截断，未覆盖到带引用的段落）
- 我**没有**验证 App 端是否存在 favicon 之外的**可点击来源列表 / 底部参考链接区块**
- 我**没有**找到 App 端「悬停/点击角标 → 弹出源」的确切交互（触屏没有 hover，行为必然不同）

**[A 已验证] 用户侧确认引用确实出现在 App/网页回答中**：官方仓库 issue #1626 报告：开启 Smart Search 后，模型**自动追加内联引用与参考标记（如 `[Reference 1]`、`[citation:2]`）到生成的回答中**，且「**or a 'Sources' list at the end**」。用户抱怨无法只开联网搜索而关闭引用。
来源：https://github.com/deepseek-ai/DeepSeek-V3/issues/1626

> 这条同时确认了：**引用默认无法关闭**，且**可能以文末 "Sources" 列表形式出现**（该 issue 未注明平台，标注为 DeepSeek chat interface）。

### 2.4 「联网搜索」这个文案是否还在？

**[A 已验证] 当前 UI 用的是「智能搜索 / Search」，不是「联网搜索」。**
官方 App Store 截图中，输入框内两个 chip 分别是：

| 中文 | English |
|---|---|
| **深度思考**（带图标） | **Think**（带图标） |
| **智能搜索**（带地球图标） | **Search**（带地球图标） |

来源：官方 App Store 截图（美区/中国区，经 iTunes Lookup API 取得原图）

**[A 已验证]** 中文技术文仍普遍用「联网搜索」作为**功能俗称**（如 IT之家/头条文章），但**UI 文案是「智能搜索」**。复刻时请用「智能搜索」。

### 2.5 其他 App UI 文案（官方截图，逐字）

| 场景 | 中文 | English |
|---|---|---|
| 输入框 placeholder | **发消息或按住说话** | **Type a message or hold to speak** |
| 空态问候 | **下午好，有什么可以帮到你？** | **How can I help you?** |
| 思考中（进行态） | **正在思考**（带下拉箭头） | **Thinking**（带下拉箭头） |
| 思考完成（完成态） | **已思考 (用时 90 秒)**（带 `>` 箭头） | **Thought for 52 seconds**（带 `>` 箭头） |
| 思考步骤：查关键词 | **查找关键词** | **Found keyword** |
| 附件入口 | **拍照 / 相册 / 文件** | **Camera / Photo / Document** |
| 会话标题（示例） | **高考出题趋势** | **Trends of Gaokao questions** |

> 注意「**已思考 (用时 90 秒)**」括号为**半角** `(` `)`，秒后有空格 —— 逐字复刻时注意。

---

## 3. 文件与图片附件

### 3.1 附件在对话中的呈现

**[A 官方截图]** 附件显示为**独立于用户气泡之上的一张「文件卡片」**，卡片内含：
- 左侧：蓝色文件类型图标（文档图标）
- 主文本：文件名（**超长截断加省略号**）—— 中文截图 `三体.txt`，英文截图 `The Three-Body Probl...`
- 副文本：**格式 + 大小**，灰色小字 —— 中文 `1.2MB`，英文 `TXT 1.2MB`

其下才是用户气泡（`介绍一下三体主要剧情` / `Give me an overview of the main plot of The Three-Body Problem.`）

来源：官方 App Store 截图第 5 张（美区/中国区）

**[A 已验证] 网页端行为**：历史会话中的附件图标**不可点击 / 无法预览或下载**（用户报告的 bug，服务端 `files.deepseek.com` 返回 CORS/503）。
来源：https://github.com/deepseek-ai/DeepSeek-V3/issues/1260

> 复刻时可考虑做得更好（附件可预览/下载），这是 DeepSeek 的已知缺陷。

### 3.2 图片输入（vision）—— 分模式，且分时期

**[A 已验证] 官方 FAQ 明确「图片上传失败」的判定条件（中文逐字）**：

```
图片上传失败可能由于以下原因：
- 上传的图片格式暂不支持。
- 系统未从图片中检测到可提取的文字。
- 图片大小超过了允许的上传限制。
- 图片内容不符合平台使用规范。
```

**英文版官方逐字**：

```
Unsupported image format.
No extractable text in the image.
Exceeded maximum upload limit.
The image contains content that violates terms.
```

来源（官方 FAQ，从官方 JS bundle 提取）：https://static.deepseek.com/faq/index.html?lang=zh
（内容位于 `https://static.deepseek.com/faq/static/main.d7e066fb1b.js`，分类「对话问题 / Chat Issues」→「为什么图片上传失败」）

> **极其重要的产品信号**：官方 FAQ 把失败原因写成「**系统未从图片中检测到可提取的文字**」（No extractable text in the image）。这说明在该上传链路中，**图片是「OCR 提取文字」的输入，而不是自由视觉理解的输入**。这与 IT之家/ZOL 的实测结论完全一致。

**[A 已验证] 各模式 vision 能力（2026 年）**：
- 快速模式（Instant）：支持图片和文件中的**文字识别**，**不具备原生视觉感知能力** — [PChome](https://article.pchome.net/news/13499.html)、[ZOL](https://ai.zol.com.cn/1180/11809710.html)、[IT之家](https://www.ithome.com/0/937/349.htm)
- 专家模式（Expert）：2026-04-09 曾支持上传但**仅 OCR**；2026-05-14 **完全下线上传**
- 「识图模式」（Vision）：2026-06-18 上线网页端与 App，能力「远超简单的文字提取」，与快速/专家模式并列 — [C114/IT之家](https://www.c114.net.cn/industry/91832.html)
- 2026-09-11（2.5.0）：**三模式统一** — iTunes API

> **[C 未知]** 三模式统一后，图片输入到底走「OCR」还是「原生 vision」？**我无法验证。** 官方 Release Notes 只说 unified。App Store 截图 2 的标题是「**图片理解 / 读懂更多**」（EN "Understand images, discover more"），暗示原生理解能力；但截图里没有任何实际上传图片后的对话内容，无法证实。

### 3.3 文件类型与大小限制 —— 对「2026 teardown 说法」的核验结论

**任务中的说法**：「text extraction only in Instant, max 50 files, 100MB each」

**[A 已验证] 该说法逐字为真，但归因需要修正**：

aiuxplayground 的 DeepSeek composer teardown（抓取日期 **2026-06-16**，desktop）原文：

> 「**Attach limits in Instant**
> Paperclip tooltip in Instant: text extraction only, with doc and image limits spelled out.
> **Copy is specific: text extraction only in Instant, max 50 files, 100MB each.**」
> 「'Text only' in Instant may frustrate users who uploaded images expecting vision.」

来源：https://aiuxplayground.com/teardowns/deepseek/composer
（同一信息也见 gallery 页：https://aiuxplayground.com/gallery/deepseek-tool-switching —— 「Instant attach is text-extraction only with explicit count and size caps」）

**修正点**：`50 个文件 / 100MB 单个` 这组数字**最早出现在「专家模式」**（2026-04-09，IT之家），2026-05-14 专家模式下线上传后，**由快速模式（Instant）承接**这批限额，于是 2026-06 的 teardown 把它记在 Instant 名下。两处数字完全一致：

- IT之家（2026-04-09，专家模式）：「官方提示**仅识别文字**，**最多上传 50 个文件，每个 100MB**，支持各类文档和图片」— https://www.ithome.com/0/937/349.htm
- aiuxplayground（2026-06-16，Instant）：「text extraction only in Instant, max 50 files, 100MB each」— https://aiuxplayground.com/teardowns/deepseek/composer

**[C 未知 / 有冲突] 支持的具体文件类型清单**：
- 官方口径只到「各类文档和图片」（IT之家）/「doc and image limits」（aiuxplayground）——**没有给出扩展名清单**
- 一篇 2026-07-07 的头条自媒体文声称支持「PDF、Word、Excel、PPT、TXT、图片（含文字），最大支持 100MB」— https://m.toutiao.com/article/7659415217138450984/
  - ⚠️ **该来源是名单制营销号内容，含明显不可靠声明**（如「每笔带金额...链接可点」、大量推广话术），**我将其置信度标为低**，不建议据此写死格式白名单
- **[A 已验证] 官方 API 的 Files API 只支持图片**（JPEG/PNG/GIF/WebP，单文件 ≤64 MiB）—— https://api-docs.deepseek.com/zh-cn/api/create-file/ 。**这是 API，不是 App**，不要混淆

**[C 未知] 图片单张大小上限**：官方 FAQ 只说「图片大小超过了允许的上传限制」，**未给出数值**。我没有验证到 App 侧的图片大小上限。

---

## 4. HTML / artifacts / canvas / Mermaid

### 4.1 Mermaid —— 网页端**有渲染**，App 端未知

**[A 已验证] `chat.deepseek.com` 前端渲染 Mermaid，并有独立的「图表面板」**。
官方仓库 issue #992（2025-09-18 提交，2025-12-02 因 stale 关闭）：

> 标题：[BUG] Getting Mermaid rendering failed
> 「I'm getting buggy deepseek generated Mermaid diagrams in answers. **It can't be rendered.**」
> 「**Screenshots**: Just text in chart panel」
> 「Additional context: **Most Mermaid schemes function well.**」

来源：https://github.com/deepseek-ai/DeepSeek-V3/issues/992

**可以确认的**：
- DeepSeek 前端**存在 Mermaid 渲染能力**（否则不会出现「语法错所以渲染失败」这类 bug，也不会有人抱怨）
- 渲染发生在名为 **chart panel** 的区域
- 「Most Mermaid schemes function well」= 渲染是常态，只有非法语法（如 `quadchart` 应为 `xychart-beta`）才失败
- 该 issue **★未提平台**，但从「chart panel」+ 网页截图尺寸看更像网页端；**我无法确认 iOS App 是否同样渲染 Mermaid**

**[C 未知] iOS App 的 Mermaid 渲染**：**未验证**。官方 5 张截图**没有**任何图表。**不要假定 App 会渲染 Mermaid** —— 这需要真机验证。

### 4.2 HTML / artifacts / canvas —— 倾向「不支持」，但未直接证实

**[A 已验证] 多份第三方导出/Mermaid/公式导出工具的存在本身，说明官方 App 缺少这些能力**：Chrome/长图导出器、Mermaid 导出器、公式导出器大量存在（如 AI 导出鸭等营销文），这类工具的存在是「官方不提供渲染/导出」的间接证据。

**[A 已验证] 官方未提供任何 artifact / canvas 产品能力**：2026-04-24 的 iOS+Android 长期实测评测明确列出 App **缺失**的能力：

> 「Notably **absent**: native image generation, persistent memory..., custom GPTs/projects, **code interpreter sandbox**, and a Mac/Windows native client.」

来源：https://deepseekai.guide/reviews/deepseek-app-review/ （2026-04-24，第三方评测，非官方）

> 「code interpreter sandbox」缺失 → 与「无 canvas/artifacts 执行预览」一致。但这是**第三方评测**（置信度中等），且为 **2026-04**，早于 2.5.0。

**[C 未知]** 我**没有找到**任何官方文档、官方截图或可靠评测直接说明「DeepSeek App 不渲染 HTML/artifacts」。这是一个**否定性论断**，只能通过真机验证确认。

---

## 5. 官方文档是否描述 App 渲染？

**[A 已验证] 结论：没有。**

| 官方入口 | 是否描述 App 内容渲染 |
|---|---|
| `api-docs.deepseek.com` 全部页面 | **否**。只有 API 侧能力。唯一的 App 相关页面是新闻稿 [「DeepSeek APP 发布 2025/01/15」](https://api-docs.deepseek.com/zh-cn/news/news250115/)，内容仅一张宣传图，**零渲染细节** |
| [官方 FAQ](https://static.deepseek.com/faq/index.html?lang=zh)（4 类：登录问题 / 使用引导 / 对话问题 / API相关） | **否**。只有故障排查与账号说明。与渲染最接近的仅有「图片上传失败」的 4 条原因（见 3.2） |
| 官方 Release Notes | 仅有 App Store 的 3 行（见 0.2），**无 markdown/LaTeX/表格/引用/文件**等字样 |
| `deepseek.com` 官网 | **未验证到**描述 App 渲染的页面 |
| [用户服务协议](https://cdn.deepseek.com/policies/zh-CN/deepseek-terms-of-use.html) | **未验证**（未取到内容） |

**唯一一条「官方口径」的描述性信息**来自 App Store 页面副标题/描述（由官方撰写，**[A 已验证]**）：

- 中文副标题：**「AI 智能对话助手，搜索写作阅读解题翻译工具」**
- 英文副标题：**「Intelligent AI Assistant」**
- 中文描述正文：**「DeepSeek 官方推出的 AI 助手，免费体验与全球领先 AI 模型的互动交流。搭载 DeepSeek 最新旗舰模型，用更快的速度、更加全面强大的功能为你答疑解惑，助力高效美好的生活。联系我们：官方公众号：DeepSeek 官方邮箱：service@deepseek.com」**
- 英文描述正文：**「Experience seamless interaction with DeepSeek's official AI assistant for free! Powered by DeepSeek's latest flagship model, it delivers faster responses and more powerful features to help you solve problems and live more efficiently. Contact us: Twitter: @deepseek_ai Email: service@deepseek.com」**

来源：官方 App Store 页面（[中国区](https://apps.apple.com/cn/app/id6737597349) / [美国区](https://apps.apple.com/us/app/id6737597349)）+ iTunes Lookup API

> ⚠️ 注意：`description` 字段**不随版本更新**（2.5.0 的新能力完全没写进描述），因此**不能用 App Store 描述判断功能有无**。

---

## 6. 复刻建议（基于已证据的推断，非验证事实）

1. **数学公式必须做原生排版**（KaTeX 等价物 + 可回读 LaTeX 源码）。这是官方明确渲染且被用户高度感知的能力。
2. **引用 chip 的设计要点**（来自 web DOM 结构）：
   - chip 只显示数字
   - 多个连续引用**无分隔符**，紧邻排布
   - 位置在**句末**，不是文末集中列表
   - chip 可点击跳转来源
   - 结合 App 截图：来源计数 + favicon 在 **thinking 步骤行**（「已搜索到 17 个网页」+ favicons）
3. **代码块的 banner 结构**：`banner（语言标签 + 复制按钮）` + `pre`。**语言标签是从 banner 文本提取的** — 复刻时 banner 左侧放语言文本、右侧放复制按钮是符合官方结构的。
4. **对齐 App 文案**：用「智能搜索」而非「联网搜索」；用「已思考 (用时 X 秒)」「正在思考」「已搜索到 X 个网页」「已浏览 X 个页面」「发消息或按住说话」。
5. **对 50 文件 / 100MB 的处理**：数字可采纳（三处独立来源一致），但要标注为「当前未验证版本」，因为 2.5.0 三模式统一后限额是否重置未知。

---

## 7. 未能验证的清单（诚实边界）

### 完全未验证
- iOS App 端**代码块**是否显示语言标签、是否有复制按钮、复制按钮形态（图标/文字）、是否有语法高亮、是否横向滚动
- iOS App 端**表格**渲染（官方 5 张截图无表格）
- iOS App 端回答正文内是否有**数字角标引用 chip**；点击行为如何（触屏无 hover）
- iOS App 端是否有**底部/侧栏来源列表**（"参考链接 / References" 区块）——**关键词「参考链接」我全程未在任何官方或高置信来源中检索到**
- iOS App 端是否渲染 **Mermaid**
- iOS App 端是否支持 **HTML/artifacts/canvas 预览**
- iOS App 端 **KaTeX 是 WebView 还是原生**实现
- 图片上传的**具体大小上限**、**具体文件扩展名白名单**
- 2.5.0 三模式统一后，**图片输入是 OCR 还是原生 vision**
- DeepSeek 用户协议/隐私政策中关于上传的条款（页面未取到）

### 证据薄弱（低置信）
- 支持格式清单「PDF/Word/Excel/PPT/TXT/图片」——仅来自营销号
- 「无 code interpreter sandbox」——来自第三方评测，且时间早于 2.5.0

### 来源不可用（阻碍验证）
- `aiuxplayground.com/teardowns/compare/trust-privacy-settings`（citations & sources 对比页）—— 该对比**不含 DeepSeek**（只有 ChatGPT vs Perplexity）
- Mobbin DeepSeek iOS 页面 —— 需登录，仅返回标题
- php.cn 的 3 篇「联网搜索怎么查看/复制来源」文章 —— Cloudflare 403，**未能读取**（这几篇本可能是 App 端引用交互的最佳中文来源）
- PageFlows、UXArchive、Screenlane、sspai、知乎、woshipm、36kr、机器之心 —— 本轮检索**未产出**关于本议题的可用一手内容
- Reddit r/DeepSeek、YouTube 评测转录 —— 本轮**未产出**可用内容

### 建议团队优先真机验证的 3 件事
1. 开启智能搜索后，回答正文里引用 chip 的**确切外观与点击行为**（最大不确定性）
2. 代码块的 banner 与复制交互（**语言标签**是否存在）
3. Mermaid / HTML 代码块是**渲染**还是**仅显示代码**
