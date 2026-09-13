# DeepSeek 官方 iOS App 产品调研报告

- 调研对象：App Store 名称「DeepSeek - AI Assistant」/「DeepSeek - AI 智能助手」，id6737597349，bundleId `com.deepseek.chat`，开发者 杭州深度求索人工智能基础技术研究有限公司
- 调研日期：2026-09-12
- 证据分级：**【已验证】**= 有 URL 可查；**【截图推断】**= 从 App Store 官方截图读出，属于推断；**【未知】**= 无法验证

---

## 0. 最关键的元数据（全部【已验证】）

来源：Apple 官方 iTunes Lookup API（比网页更权威，且带 releaseNotes 原文）
- https://itunes.apple.com/lookup?id=6737597349&country=us
- https://itunes.apple.com/lookup?id=6737597349&country=cn

| 字段 | 美区 (us) | 中区 (cn) |
| --- | --- | --- |
| trackName | DeepSeek - AI Assistant | DeepSeek - AI 智能助手 |
| 副标题 | Intelligent AI Assistant | AI 智能对话助手，搜索写作阅读解题翻译工具 |
| version | 2.5.0 | 2.5.1 |
| currentVersionReleaseDate | 2026-09-11T02:20:46Z | 2026-09-12T08:22:12Z |
| releaseDate（首个版本） | 2025-01-10T08:00:00Z | 同 |
| minimumOsVersion | 15.0 | 15.0 |
| fileSizeBytes | 60223488（页面上显示 **60.2 MB**） | 同 |
| features | `["iosUniversal"]` | 同 |
| appPlatforms（网页 JSON） | `["phone","pad"]` | 同 |
| genres | Productivity | 效率 |
| price | Free / 免费 | 同 |
| **hasInAppPurchases** | **false** | **false** |
| hasExternalPurchases | false | false |
| trackContentRating | 12+ | 12+ |
| 网页显示年龄分级 | **13+**（App 内控制 / In-App Controls） | **13+** |
| averageUserRating | 4.0（11,408 条评分） | 3.9（86,475 条评分） |
| advisories | Infrequent/Mild Medical/Treatment Information | 偶尔/轻微的医药或医疗信息 |

**⚠️ 版本号 / 年龄分级两处口径差异（必须注意）**
1. `trackContentRating` 是 12+，但 App Store 网页「信息」栏渲染成 **13+**。以页面展示为准是 13+。
2. 美区当前版本 2.5.0，中区 2.5.1；中区 2.5.1 于 2026-09-12 08:22Z 发布，美区当时仍显示 2.5.0（2026-09-11）——同一次发版在不同 storefront 的审核/上线时间不同步。

**语言（【已验证】）**
- 美区页面：`English and 71 more`
- 中区页面：`简体中文和另外71种`
- API `languageCodesISO2A` 共 71 项（含 `ZH` 两次，分别对应简/繁），列表包含 EN、JA、KO、FR、DE、ES、PT、RU、AR、HI、TH、VI、ID、TR 等。
- 美区页面语言明细可见（节选）：... Simplified Chinese, Singhalese, Slovak, Slovenian, Spanish, Swahili, Swedish, Tamil, Telugu, Thai, Traditional Chinese, Turkish, Ukrainian, Urdu, Vietnamese, Zulu

**兼容性原文（【已验证】，中区页面）**
> 设备需装有 iOS 15.0 或更高版本。
> iPhone 设备需装有 iOS 15.0 或更高版本。
> iPad 设备需装有 iPadOS 15.0 或更高版本。
> iPod touch 设备需装有 iOS 15.0 或更高版本。

**支持设备（【已验证】）**
`supportedDevices` 极长，从 `iPhone5s` 一直到 `iPhone18Pro/iPhone18ProMax/iPhoneDuo`、`iPadPro13M5`、`iPadAir13M4`、`iPadMiniA17Pro` 等，即全程 iPhone + iPad + iPod touch 通用（Universal）。注意：`iPhoneDuo` 出现在列表中，说明 2026 年折叠屏 iPhone 也在兼容范围。

**App 描述原文（全部内容，【已验证】）**
- 美区：
  > Experience seamless interaction with DeepSeek's official AI assistant for free!
  > Powered by DeepSeek's latest flagship model, it delivers faster responses and more powerful features to help you solve problems and live more efficiently.
  > Contact us:
  > Twitter: @deepseek_ai
  > Email: service@deepseek.com
- 中区：
  > DeepSeek 官方推出的 AI 助手，免费体验与全球领先 AI 模型的互动交流。
  > 搭载 DeepSeek 最新旗舰模型，用更快的速度、更加全面强大的功能为你答疑解惑，助力高效美好的生活。
  > 联系我们：
  > 官方公众号：DeepSeek
  > 官方邮箱：service@deepseek.com

**「App 内购买」栏（【已验证】）**
- 中区 App Store 页面「信息」栏中，DeepSeek 条目为 `hasInAppPurchases: false, hasExternalPurchases: false`；页面副标题处**没有**出现「App 内购买」标签（该标签只出现在同页推荐位的 Kimi / 千问 / 讯飞星火 上）。
- 结论：**DeepSeek iOS 无内购，完全免费**。

---

## 1. 屏幕清单与导航外壳

### 1.1 可以确定的骨架（【已验证】）
官方 FAQ（`static.deepseek.com/faq`，本次直接抓取其前端 JS bundle 读出的原始文案）明确把 App 侧的历史列表称为 **「历史对话侧边栏」**，并说明可**下拉刷新**：

> APP 端：下拉刷新历史对话侧边栏，并重新进入目标对话。
> 如果是多端同步问题：网页端可尝试刷新页面，APP 端可下拉刷新历史对话侧边栏。

来源（官方站点）：https://static.deepseek.com/faq/index.html?lang=zh
同一份内容的可读镜像（含抓取时间 2026-08-05）：https://github.com/thevibeworks/deepseek-docs/blob/main/content/zh-cn/faq/category-2.md

→ **结论（【已验证】+【截图推断】）**：历史对话**不是** tab bar 里的一级页面，而是**侧边栏（sidebar）/ 抽屉**。iPhone 上以覆盖式抽屉呈现，由左上角图标唤出；iPad 上官方截图仍使用同一个左上角菜单图标（见 1.2）。

### 1.2 App Store 官方截图读出的界面（【截图推断】）
来源：iTunes Lookup 返回的 `screenshotUrls` / `ipadScreenshotUrls`（已下载原图逐张查看）。iPad 版截图直链示例：
- https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/1e/80/2a/1e802aef-eab5-793f-bd9f-39b05a026617/1.png/1200x1200bb.jpg
- https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/d7/e3/66/d7e3666a-863a-52a6-ba29-b726690b6caf/2.png/1200x1200bb.jpg
- https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/e1/78/fe/e178fe91-84ab-c336-055e-3b28457c1a7b/3.png/1200x1200bb.jpg
- https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/52/b4/77/52b47735-16d1-d2b8-c5b5-6bfb27b39d83/4.png/1200x1200bb.jpg
- https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/6e/c3/ce/6ec3cea4-e860-4b65-62d1-0cbe55485779/5.png/1200x1200bb.jpg

**新对话 / 欢迎页（App 截图 2，英文版；中文版截图 2 同构图）**
- 顶部左：**两条横线的菜单图标**（≡）——即历史对话抽屉入口
- 顶部中：**空白**（新对话页无标题）
- 顶部右：**⊕ 图标**（新对话 / 新建）
- 页面中央：**蓝白 DeepSeek 鲸鱼 logo**
- logo 下文案：英文 `How can I help you?`；中文 `午后好，有什么可以帮到你？`（**中文文案含时段问候，会随时段变化**——截图里是「午后好」，其他时段文案【未知】）
- 输入框 placeholder：英文 `Type a message or hold to speak`；中文 `发消息或按住说话`
- 输入框内部左下两个 pill 开关：英文 `Think` / `Search`；中文 `深度思考` / `智能搜索`（中文版这两个 pill 在输入框**下方**一排）
- 输入框右侧两个圆形按钮：`⊕`（附件）和 `)))`（语音）
- 输入框下方：缩略图横滑列表（截图里是 5 张图 + 1 个文档卡片）
- 再下方三个方形快捷入口：英文 `Camera` / `Photo` / `Document`；中文 `拍照` / `相册` / `文件`

**对话页（App 截图 3/4/5）**
- 顶部左：`≡` 菜单；顶部中：**会话标题**（截图示例英文 `Trends of Gaokao questions`、`Smallest Integer as Two Squares`、`The Three-Body Problem`；中文 `高考出题趋势`、`最小可两方式平方和的正整数`、`三体剧情介绍`）；顶部右：`⊕`
- 用户气泡右对齐；助手回答左对齐
- 思考过程折叠行：英文 `Thinking ⌄`、`Thought for 52 seconds ›`；中文 `正在思考 ⌄`、`已思考（用时 90 秒）›`
- 联网搜索状态行：英文 `Found 17 web pages` / `Read 3 pages` / `Found keyword`；中文 `已搜索到 17 个网页` / `已浏览 3 个页面` / `查找关键词`
- 附件卡片：文件名 + 大小（中文截图 `三体.txt` `1.2MB`）
- 表格支持复制/下载/全屏预览（版本记录佐证，见第 5 节）

### 1.3 设置 / 账号页（【已验证】，官方 FAQ 原文）
官方 FAQ 直接给出路径字符串：
- 「设置」→「账号管理」：变更手机号、解绑/换绑微信号、登出所有设备、注销账号
- 「系统设置」→「账号管理」→「登出所有设备」 （FAQ 另一处用了「系统设置」这个措辞，**同一份 FAQ 内不一致**）
- 「设置」→「数据管理」→「导出所有历史对话」（**仅网页端**）
- 原话：「若未找到注销入口，请将 APP 升级至最新版本。」「若找不到相关入口，请尝试更新 APP 版本。」

→ 可确认设置页至少含 **账号管理**、**数据管理**两个二级分组。**设置页的完整条目清单【未知】**。

### 1.4 模式 / 功能开关的当前状态（【已验证】）
- **2026-09-10 起「快速 / 专家 / 识图」三个模式被合并，不再有独立的「专家模式」选择器**。
  - 搜狐/界面新闻：https://roll.sohu.com/a/1074177693_313745 （「9月10日，DeepSeek的界面已将快速、专家、识图模式进行合并，不再单独设立专家模式」）
  - 财联社/东方财富：https://finance.eastmoney.com/a/202609103870382076.html
  - 新浪微博 ZEALER：https://www.sina.cn/news/detail/5341565488726224.html （`#DeepSeek不再需要手动切换模式#`、`#DeepSeek专家模式下线#`）
  - 什么值得买深度复盘：https://post.smzdm.com/p/a70nwd9g/ （「原来『快速』『专家』『识图』三个模式按钮没了，只剩一个对话框」）
- 该文同时给出：官方称模型换成 **V4.1 Flash**；V4 Pro 于 **2026-09-14 12:00** 下线并路由到 V4.1 Flash。
- App Store 2.5.0/2.5.1 版本记录中英双语完全对应这一点：「New model update: Instant, Expert, and Vision modes are now unified」/「新模型上线，快速、专家、识图模式合并升级」。
- **当前仅剩的输入区功能开关**：`Think / 深度思考`、`Search / 智能搜索`（官方截图 + 2.5.x 记录）。

模式历史（【已验证】）：
- 专家模式 **2026-04-08** 上线（快速=日常即时响应；专家=复杂问题，支持深度思考和智能搜索）
- **2026-06-18** 网页及 App 端新增「识图模式」
- 2026-09-10 三者合并
来源：https://roll.sohu.com/a/1074177693_313745

---

## 2. 对话历史管理

### 2.1 行交互：**长按**，不是左滑（【已验证】）
官方 FAQ 原文（逐字）：

> **重命名对话标题**：您可以方便地为对话重新命名以便查找：
> - 网页端：在历史对话列表中，点击目标对话旁的「…」菜单，选择「重命名」。
> - APP 端：在历史对话列表中，**长按**目标对话，选择「重命名」。

> **置顶历史对话**：将重要对话置顶，可使其显示在列表顶部：
> - 网页端：… 点击目标对话旁的「…」菜单，选择「置顶」。
> - APP 端：在历史对话列表中，**长按**目标对话，选择「置顶」。

> **删除历史对话**：如需删除对话，请按以下方式操作：
> - 网页端：…「…」菜单，选择「删除」。
> - APP 端：在历史对话列表中，**长按**目标对话，选择「删除」。
> 请注意：已删除的对话无法恢复，请您谨慎操作。

> **分享历史对话**：您可以将对话以链接或图片的形式分享出去：
> - 网页端：在历史对话列表中，点击「…」菜单并选择「分享」，或者直接点击回复内容下方的「分享」按钮，或者页面右上角的「分享」按钮。
> - APP 端：**长按模型的回复内容**选择「分享」，或直接点击回复内容下方的「分享」按钮。
> 若未能找到上述入口，建议您将 APP 更新至最新版本。

来源：https://static.deepseek.com/faq/index.html?lang=zh（本次从站点 JS bundle 中直接读出的原始字符串）；镜像 https://github.com/thevibeworks/deepseek-docs/blob/main/content/zh-cn/faq/category-2.md

**关键结论（对复刻至关重要）**
- 移动端历史行**没有**左滑（swipe）操作 —— 官方文档只描述长按。
- App 端历史列表**没有**「…」三点菜单（三点菜单只属于网页端）。
- **分享入口不在历史列表里**：App 端分享的对象是**模型回复内容**（长按回复 或 回复下方「分享」按钮），不是会话。
- 「已删除的对话无法恢复」是官方明确的不可撤销语义。
- **左滑手势是否存在【未知】**：官方文档未提及，我也未找到任何截图/视频证据。不要默认有左滑。

### 2.2 搜索聊天记录（【已验证】，2026-05 灰测）
官方 App Store 版本记录把搜索功能挂在 **2.1.1（美区 5 月 21 日 / 中区 5 月 21 日）**：
- 美区：`- Search your chat history`
- 中区：`- 支持搜索历史对话`

但媒体实测报的是 **2.1.0（213）** 就已有入口，官方回应为灰度测试。两者不矛盾：2.1.0 是灰度包（`213` 是 build 号），2.1.1 是全量 store 版本。

【已验证】报道要点：
- IT之家 2026-05-12：更新至 **2.1.0（213）** 后，**侧边栏顶部会出现「搜索聊天内容」搜索框**，输入关键词后页面显示包含该词的多条历史聊天记录，**点击任意一条即可定位至具体聊天位置**；网页版为左上角「放大镜」按钮。官方回应：`该搜索聊天记录功能目前正处于灰度测试阶段，并非全量推送`。
  - https://m.ithome.com/html/949303.htm
- 站长之家/快科技 2026-05-12：同一措辞，并给出官方原话「目前该功能尚处于灰度测试阶段，并非面向所有用户推送。若当前版本未被灰度覆盖，用户可以检查应用是否为最新版本。」
  - https://www.chinaz.com/2026/0512/1751701.shtml
- 中关村在线 2026-05-12：同样描述「侧边栏顶部新增『搜索聊天内容』输入框」。
  - https://ai.zol.com.cn/1180/11801575.html
- 雷科技 2026-05-12（额外给出模糊搜索/主题匹配的说法）：
  - https://www.leikeji.com/article/76686
- 太平洋科技 2026-05-12：同样描述，原文含「DeepSeek APP 更新至 2.1.0(213) 版本后，侧边栏顶部…」
  - https://news.pconline.com.cn/2148/21485471.html

**可确认的 UI 文案**：`搜索聊天内容`（App 端搜索框）
**搜索结果的视觉样式 / 是否有分组 / 是否高亮关键词【未知】**（所有来源只描述行为，未给出截图级细节）。

### 2.3 分组、多选、批量删除
- **按日期分组**：Xataka 2025-01-27 的教程写「在这个历史里最上面能看到今天的对话，往下滚动可以看到前几天/更早的对话」（原文西语：`arriba del todo verás las de hoy, y según vas bajando podrás ver los chats de días anteriores`），并且说**移动端同样可以通过展开侧栏完成这些操作**。该文配图是网页面板，且发布于 2025-01，**是否等于当前 2026 年 App 的日期分组，无法确认**。
  - https://www.xataka.com/basics/historial-deepseek-como-ver-borrar-todo-que-le-has-preguntado-a-inteligencia-artificial
- **具体的分组标题文案**（如「今天 / 昨天 / 7 天内 / 更早」）**【未知】**——未找到任何来源给出 App 端的分组字符串。
- **多选 / 批量删除**：**【未知】**。官方 FAQ 只描述单条长按删除；我也未找到任何多选模式的证据。
- **重命名**：存在，长按 → 重命名（见 2.1）。
- **置顶**：存在，长按 → 置顶，效果是「显示在列表顶部」（官方原文）。
- **文件夹 / 项目分组**：**【未知 / 用户诉求而非现有功能】**。2026-05 灰测报道中网友评论在催更「把历史记录支持关键词搜索和目录分组，把对话按『项目』分个文件夹」（https://www.leikeji.com/article/76686）。说明当时**没有**文件夹功能；2026-05 之后是否新增【未知】。
- **导出**：仅网页端「设置」→「数据管理」→「导出所有历史对话」，导出文件包含账号信息及全部历史对话，下载链接有效期 7 天。**App 端不支持导出**（官方 FAQ 只写网页端）。

### 2.4 分支（对复刻很重要，容易被忽略）
官方 FAQ（【已验证】）：
> 检查内容是否位于对话分支中：**点击对话（提问或回答）下方的数字箭头，可切换查看不同分支**。

→ App 端消息下方有**数字箭头**用于切换分支。这是官方文档明确的功能点。

### 2.5 其他官方确认的细节（【已验证】）
- 「部分手机机型可能不适配滚动截屏。我们推荐您使用『对话分享』功能来保存或分享长内容。」→ 说明对话分享支持**长图导出**，而且是官方推荐的截长图替代方案。
- 分享形态：「以链接或图片的形式分享」→ 链接 + 图片两种。
- 图片上传失败原因（官方列举）：格式不支持 / 未检测到可提取文字 / 超出大小限制 / 内容不符合规范。

---

## 3. iPad 行为

### 3.1 已确认的事实
- 【已验证】App Store 明确标注 **iPhone、iPad、iPod touch**，`features: ["iosUniversal"]`，`appPlatforms: ["phone","pad"]`。
- 【已验证】存在 `ipadScreenshotUrls`（5 张 iPad 专属截图）。
- 【已验证】iPad 需 iPadOS 15.0 或更高版本（与 iPhone 同一最低版本）。

### 3.2 关键推断（【截图推断】，强烈建议以此为依据做决策）
我下载并逐张查看了 5 张 iPad 专属截图。**5 张全部是 900×1200（3:4）画布，App UI 被渲染在一个居中的、圆角白色手机外框里，外框顶部有 `9:41` 假状态栏（含信号/Wi-Fi/电池图标）。** 而且每一张的 App chrome 都是：
- 左上角 `≡`（两条横线的菜单图标，即抽屉入口）
- 右上角 `⊕`
- 顶部中间是会话标题

如果 iPad 版本采用原生 iPadOS 布局（NavigationSplitView / 常驻 sidebar），App Store 截图几乎不会用手机外框 + 假 9:41 状态栏来做版式。再叠加 1.1 中官方 FAQ 把该结构称为「侧边栏」并说可以「下拉刷新」，最合理的解读是：

> **iPad 版是同一套 Universal App 布局，历史对话仍然是覆盖式抽屉/侧边栏，通过左上角菜单图标唤出；没有证据表明存在常驻 iPad 侧栏或三栏布局。**

**但我无法验证**：iPad 横屏时该侧边栏是否变成常驻（类似 `UISplitViewController` 的 `.sidebar` 行为）。App Store 截图全部是竖屏手机外框，**没有**横屏 iPad 截图。

### 3.3 Split View / Slide Over / 键盘快捷键
- **Split View / Slide Over：【未知】**。没有任何来源（官方或其他）提到。
- **键盘快捷键：【未知】**。搜索结果里出现的 "DeepSeek Keyboard Shortcut Commands Complete List" 是 `deepseek.com.pk`（**非官方域名**，第三方 SEO 站），且内容是通用/网页端快捷键，不能作为 App 端证据。**没有任何官方或可信来源证明 iOS App 支持硬件键盘快捷键。**
- **多任务 / Stage Manager：【未知】**。
- **Apple Pencil / 手写：【未知】**。

**对复刻团队的建议**：把 iPad 当作「同一套 Universal 布局 + 自适应宽度」来规划，不要默认需要实现 iPadOS 常驻 sidebar 或快捷键，除非后续能拿到真机验证。

---

## 4. 版本历史（App Store 官方「版本历史记录」，【已验证】）

来源：App Store 网页「版本历史记录」区块
- 美区 https://apps.apple.com/us/app/deepseek-ai-assistant/id6737597349
- 中区 https://apps.apple.com/cn/app/id6737597349

> ⚠️ 注意：`https://apps.apple.com/us/app/deepseek-ai-assistant/id6737597349?see-all=reviews` 只返回**评分与评论**，不返回版本历史。版本历史需要抓取主 listing 页的「版本历史记录」区块。
> ⚠️ 评论页会显示为该 App 做过本地化评论聚合，`?see-all=reviews&platform=ipad` 返回的仍是同一批评分（并非只有 iPad 用户）。

相对时间以 2026-09-12 抓取时刻换算：

| 版本 | 日期（美区页面） | Release Notes（美区原文） | Release Notes（中区原文） |
| --- | --- | --- | --- |
| 2.5.1 | 5h ago ≈ 2026-09-12 | （同 2.5.0 文案） | - 新模型上线，快速、专家、识图模式合并升级<br>- 支持思考过程自动折叠<br>- 修复部分已知问题 |
| 2.5.0 | 1d ago ≈ 2026-09-11 | - New model update: Instant, Expert, and Vision modes are now unified<br>- Thinking process now collapses automatically<br>- Fixed some known issues | - 新模型上线，快速、专家、识图模式合并升级<br>- 支持思考过程自动折叠<br>- 修复部分已知问题 |
| 2.4.5 | 5d ago ≈ 2026-09-07 | - Fixed some known issues | - 修复部分已知问题 |
| 2.4.4 | Sep 3 / 9月3日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.4.2 | Aug 28 / 8月28日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.4.1 | Aug 22 / 8月22日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.4.0 | Aug 21 / 8月21日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.3.6 | Aug 17 / 8月17日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.3.3 | Aug 12 / 8月12日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.3.2 | Aug 7 / 8月7日 | - Improved photo and file uploads<br>- Fixed some known issues | - 优化图片和文件上传体验<br>- 修复部分已知问题 |
| 2.3.1 | Jul 30 / 7月30日 | - Improved photo and file uploads<br>- Fixed some known issues | - 优化图片和文件上传体验<br>- 修复部分已知问题 |
| 2.3.0 | Jul 28 / 7月28日 | - Supports vision mode<br>- Fixed some known issues | - 支持识图模式<br>- 修复部分已知问题 |
| 2.2.2 | Jul 11 / 7月11日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.2.1 | Jul 7 / 7月7日 | - Supports vision mode<br>- Fixed some known issues | - 支持识图模式<br>- 修复部分已知问题 |
| 2.2.0 | Jun 29 / 6月29日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.1.8 | Jun 18 / 6月18日 | - Support custom font sizes<br>- Fix some known issues | - 支持调整字号大小<br>- 修复部分已知问题 |
| 2.1.7 | Jun 16 / 6月16日 | - Support custom font sizes<br>- Fix some known issues | - 支持调整字号大小<br>- 修复部分已知问题 |
| 2.1.4 | Jun 3 / 6月3日 | - Support custom font sizes<br>- Fix some known issues | - 支持调整字号大小<br>- 修复部分已知问题 |
| 2.1.3 | Jun 3 / 6月3日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.1.2 | Jun 2 / 6月2日 | - Supports table copy, download, and fullscreen preview<br>- Fixed some known issues | - 支持表格复制、下载及全屏预览<br>- 修复部分已知问题 |
| **2.1.1** | May 21 / 5月21日 | **- Search your chat history**<br>- Fixed some known issues | **- 支持搜索历史对话**<br>- 修复部分已知问题 |
| 2.1.0 | May 11 / 5月11日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.0.4 | Apr 30 / 4月30日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.0.3 | Apr 29 / 4月29日 | - Fixed some known issues | - 修复部分已知问题 |
| 2.0.2 | Apr 24 / 4月24日 | - Fixed some known issues | - 修复部分已知问题 |

**「更多」之后被截断的早期版本（2.0.1 及以前，含 2025-01-10 首发版）的 release notes【未知】** —— App Store 页面折叠在「更多」按钮后，未渲染。

**从版本历史能反推的产品时间线（【已验证】）**
- **2026-05-11 / 2026-05-21**：聊天历史搜索（2.1.1 全量）
- **2026-06-02**：表格复制、下载、全屏预览
- **2026-06-16 ~ 06-18**：自定义字号
- **2026-07-07（2.2.1）/ 2026-07-28（2.3.0）**：识图模式（两次上线，2.2.1 与 2.3.0 都写了 Supports vision mode，属于灰度→全量或回滚后重发）
- **2026-07-30 / 08-07**：图片与文件上传体验优化
- **2026-09-10 前后**：三模式合并 + 思考过程自动折叠（2.5.0/2.5.1）
- 整体节奏：**2026 年 4 月至今发了 24+ 个版本，绝大多数 release notes 只有「修复部分已知问题」**，功能型更新稀疏。**没有出现任何一条提到历史记录多选、文件夹、iPad 专属布局、键盘快捷键的 release note。**

**Android 侧的版本记录（【未验证】）**：本次未从可信来源取得，`apkpure`/`apkmirror` 的镜像未纳入。

---

## 5. 评论 / 用户反馈（可作为需求侧证据）

来源：https://apps.apple.com/us/app/deepseek-ai-assistant/id6737597349?see-all=reviews&platform=ipad

- 2026-04-28 用户 `Andrea rose.`：「…it's annoying that there's no chat search because I couldn't find one of my old chats… it be cool if you could give it a search button like chat gpt has.」→ **印证 2026-04 时确实没有搜索**，与 2.1.1（5 月）上线的版本记录一致。
- 2026-08-17 用户 `Kog249`：上传图片到已存在的 vision 会话时，输入框上方出现**黄色警告文案** `Your message will be sent to a new chat`。→ **这是可用的 UI 文案证据**，说明存在「发送到新对话」的提示条。
- 2026-08-18 / 2026-07-25 多位用户：编辑消息**最多 6 次**的限制（`we can only edit a message a limited number of times`、`the restriction on editing the requests and regeneration to only six`）。→ 说明存在**编辑/重新生成次数上限=6** 的机制。
- 2026-04-28 用户 `FartVera`：`clean and user-friendly interface — no clutter`（主观评价，无结构信息）。

---

## 6. 设计参考库的可用性

- **Mobbin【部分可用 / 基本被登录墙挡住】**
  - DeepSeek 在 Mobbin 有独立 app 页面，但未登录只能看到 app logo，看不到屏幕列表：
    https://mobbin.com/apps/deepseek-ios-c153d8a4-75e0-4a65-9faa-09234e2bec18
  - 单个 screen 页面标题可见（`DeepSeek iOS Screen`），但保存/复制按钮全部指向 `/signup/modal`，页面内只有一张 `bytescale` 的加密图：
    https://mobbin.com/explore/screens/9477b791-0533-4ba8-96da-b6aff89b41b7
  - **可确认的一条 flow 归属**：该 screen 被归入 flow **`Deleting & Deactivating Account`**
    （页面内链接：`https://mobbin.com/explore/mobile/flows/deleting-deactivating-account`）
    → 即 Mobbin 已收录 DeepSeek iOS 的「删除/注销账号」流程，**若要拿 Mobbin 的逐屏截图，需要登录账号**。
- **PageFlows / UXArchive：【未知】** —— 未检索到 DeepSeek 条目。
- **关键限制**：本次未能获得 Mobbin 登录态，无法取得其屏幕清单。这对「屏幕清单」这一项的完整性是主要缺口。

---

## 7. 明确无法验证的清单（务必不要凭空补全）

| 待验证项 | 状态 |
| --- | --- |
| 历史列表**左滑**手势（swipe to delete/pin） | 【未知】官方文档只写长按；无证据表明存在 |
| 历史列表**多选 / 批量删除** | 【未知】无任何证据 |
| 历史列表**日期分组标题的具体文案** | 【未知】（有「按日期从新到旧排列」的描述，但来自 2025-01 的网页版教程） |
| 历史列表**行的完整视觉结构**（高度、是否显示更新时间、是否有置顶分区标题） | 【未知】无截图 |
| 历史列表**是否显示每条会话的预览摘要** | 【未知】 |
| **设置页完整条目清单**（除「账号管理」「数据管理」外还有什么） | 【未知】 |
| **是否有独立账号/个人资料页**（含头像、昵称） | 【未知】官方只有「账号管理」路径证据 |
| **iPad 横屏是否常驻侧栏 / Split View / 键盘快捷键** | 【未知】无任何来源 |
| **搜索结果的展示样式与分组** | 【未知】 |
| **新对话页问候语的其他时段文案**（除「午后好，有什么可以帮到你？」） | 【未知】 |
| **2.0.1 及更早版本的 release notes**（含 2025-01-10 首发版） | 【未知】被「更多」折叠 |
| **浅色/深色模式是否都支持、是否跟随系统** | 【未知】 |
| **App 图标以外的品牌色值 / 字体** | 【未知】不要从截图取色当规范 |
| **Mobbin / PageFlows 上的 DeepSeek 逐屏清单** | 【受限】Mobbin 需登录 |

---

## 8. 对复刻的直接结论（一句话版）

**导航外壳**：单列 `NavigationStack` + 覆盖式历史抽屉（左上角 `≡` 唤出），抽屉顶部是搜索框，抽屉内是长按弹出上下文菜单（重命名 / 置顶 / 删除）的历史会话列表，会话行**无左滑、无三点菜单、无多选**；分享入口不在列表，而在助手回复上。会话页顶部左 `≡` / 中标题 / 右 `⊕`。输入区是胶囊输入框 + `深度思考`/`智能搜索` 两个 pill + `⊕` 附件 + 语音，输入框下方是图片缩略图与 `拍照`/`相册`/`文件` 三个快捷入口。**iPad 走同一套 Universal 布局，没有证据需要独立 iPad 侧栏。**
