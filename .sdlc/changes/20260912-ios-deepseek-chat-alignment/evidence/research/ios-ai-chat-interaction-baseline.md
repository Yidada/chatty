# 原生 iOS AI Chat App 交互行为基线（对标 DeepSeek iOS 交互质量线）

采集日期：**2026-09-12**。方法：优先官方帮助中心（help.openai.com / support.claude.com / support.google.com）、官方发行说明、App Store、社区帖子。
证据级别标注：📗 官方文档 · 🟡 用户报告 · 🔵 推断。帮助中心多数页面只渲染相对时间（"Updated: N days ago"），绝对日期仅发行说明明确给出；凡未给出绝对日期处均已注明"页面显示相对时间（观察于 2026-09-12）"。**未找到的限值一律明说"官方未标注"，不做补全。**

---

## 一、ChatGPT iOS（OpenAI）

### 1. New chat / session 模型
- 📗 **Sidebar/抽屉**：左上 hamburger 打开 sidebar，历史在 **Recents** 分组下。来源：[ChatGPT iOS App FAQ](https://help.openai.com/en/articles/7885016-chatgpt-ios-app-faq)，"Updated: 15 days ago"（观察于 2026-09-12）。引文："You can view all your past chats from the sidebar. Bring up the sidebar by clicking on the hamburger menu on the top left - your chats are shown as a list under the Recents section on the sidebar."
- 📗 **删除**：打开会话 → 三点 → Delete → 二次确认。同上：*"press the three-dot symbol and select Delete. After confirming the action, the selected conversation will be deleted."*
- 📗 **搜索**：iOS 在 sidebar 有 Search bar；web 为 ctrl/cmd+K。来源：[How do I search my chat history in ChatGPT?](https://help.openai.com/en/articles/10056348-finding-your-chats-projects-and-files-in-chatgpt)，"Updated: 14 days ago"（观察于 2026-09-12）。
- 📗 **归档语义（关键）**：*"Archived conversations are still searchable and will appear in search results, even though they won't be visible in the sidebar. You can also access these archived conversations through the Settings menu, where they're organized separately."* 同上。
- 📗 **Projects**：官方 [Projects in ChatGPT](https://help.openai.com/en/articles/10169521-projects-in-chatgpt)；发行说明 2026-08-14 记录 *"Change an existing project's memory setting ... Shared projects continue to use project-only memory and cannot be switched to default memory."* [ChatGPT Release Notes](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)。
- 🔵 **rename / pin**：iOS FAQ 未覆盖 rename 与 pin；本次未检索到官方 iOS 逐条说明 → **不声称**。归档/搜索/Projects 有官方依据。

### 2. Send lifecycle（stop / regenerate / edit / queue / 失败重试）
- 📗 **重试语义**：错误 "There was an error generating a response." 的对策是 *"May be a one-time error, click 'Regenerate' button."* 来源：[Troubleshooting ChatGPT Error Messages](https://help.openai.com/en/articles/7996703-troubleshooting-chatgpt-error-messages)，"Updated: 28 days ago"（观察于 2026-09-12）。
- 📗 **挂起处理**：页面有独立小节 *"Stuck on 'Thinking…/Generating…/Working…' or endless spinner"*；其中引文（原文在此处被页面截断，未补全）：*"If ChatGPT appears to hang indefinitely without completing the response, follow this sequence of troubleshooting steps: Wait 30–60 seconds to see if the response completes Click 'Sto…"* 同上。
- 📗 **带联网重生成**：*"To regenerate an existing response with web results, select the refresh control and choose Try again or Search the web, when available."* 来源：[Searching the web with ChatGPT](https://help.openai.com/en/articles/9237897-chatgpt-search)，"Updated: 22 days ago"（观察于 2026-09-12）。
- 📗 **代码可中断**：代码块 *"You can stop code that is still running."* 来源：[Working with writing blocks and code blocks](https://help.openai.com/en/articles/20001246-working-with-writing-blocks-and-code-blocks-in-chatgpt)，"Updated: last month"（观察于 2026-09-12）。
- 🟡 **编辑消息语义**：社区帖（2025-07-14 起）报告移动端"编辑"未替换原消息而是新增；帖内贴出 OpenAI 支持回复：*"When you edit a previous message in a conversation, ChatGPT creates a new branch based on that revision."* 用户并称 iOS/browser 有 "edit arrow box" 版本切换、Android 缺失。来源：[ChatGPT Mobile App cannot edit message](https://community.openai.com/t/chatgpt-mobile-app-cannot-edit-message/1315724)。
- 🟡 **生成中排队发消息**：官方文档未见 → 属未文档化能力；社区存在 feature request [Message queue while GPT is generating responses](https://community.openai.com/t/feature-request-message-queue-while-gpt-is-generating-responses/1155949)。🔵 推断：原生队列未被官方承诺。
- 📗 发行说明中 **"queue" 关键词命中 0 次**（对 6825453 全文检索）→ 官方未把消息队列作为产品能力描述。

### 3. Reasoning / Thinking 显示
- 📗 **档位与命名**：发行说明记录模型选择器重塑：*"Thinking Standard is now Medium, Thinking Extended is now High, and Thinking Heavy is now Extra High ... Thinking Light is no longer available."* 以及 *"Users have the ability to decide whether Instant auto-switches to Medium for higher reasoning when required."* [ChatGPT Release Notes](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)。
- 📗 **thinking time 可被服务端调整**：*"Jan 10, 2026: We lowered the Standard and Light thinking time as we observed users prefer faster responses."*；*"February 4, 2026: We're restoring the Extended thinking level for GPT-5.2 Thinking to its prior setting"*。同上。
- 🔵 **折叠 "Thinking" 块、耗时秒数、auto-collapse**：本次**未在官方帮助页/发行说明检索到**对折叠 UI、时长显示、自动折叠的明文描述 → **不声称具体行为**，建议以真机截图验证。

### 4. Web search 引用渲染 / 点击
- 📗 引文（完整）：*"Responses that use web search may include citations. Select a citation to open its source. On desktop web, you can also point to a citation to preview it. Select Sources, when available, to view cited sources and other relevant links. If a response includes images, select an image to view its source. On iOS and Android, relevant results may also include a map."* [Searching the web with ChatGPT](https://help.openai.com/en/articles/9237897-chatgpt-search)，"Updated: 22 days ago"。
- 📗 手动触发搜索路径：*"Select View all tools. Select Search."* 或输入 `/` 选择 Search。同上。

### 5. 附件 / 语音 / 图像理解（iOS）
- 📗 **文件限制**（[File Uploads FAQ](https://help.openai.com/en/articles/8555545-file-uploads-faq)，"Updated: 17 hours ago"，观察于 2026-09-12）：
  - *"All files uploaded to a GPT or a ChatGPT conversation have a hard limit of 512MB per file."*
  - *"All text and document files ... are capped at 2M tokens per file. This limitation does not apply to spreadsheets."*
  - *"For CSV files or spreadsheets, the file size cannot exceed approximately 50MB"*
  - *"For images, there's a limit of 20MB per image."*
  - *"Each end-user is capped at 25GB. Each organization is capped at 100GB."*
  - *"Users can upload up to 80 files every 3 hours. Free users are limited to 3 file uploads per day."*
  - *"Up to 10 files per GPT for the lifetime of that GPT."*
- 📗 **语音/转写隐私**：*"We send audio clips from our speech-to-text feature to our servers ... we don't retain voice clips beyond what's necessary to complete the transcription."* [iOS FAQ](https://help.openai.com/en/articles/7885016-chatgpt-ios-app-faq)。
- 📗 **Voice 的文件与 Projects**：发行说明载 *"GPT-Live in ChatGPT Voice now supports file uploads and Projects."* [Release Notes](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)。
- 🔵 **图片张数上限**：官方只给"20MB per image"，未给出单条消息图片**张数**上限 → **官方未标注**。

### 6. Backgrounding / 离线 / 跨端
- 📗 **iOS Live Activity**：*"Content from a Live voice conversation can now appear on your iPhone's Lock Screen and, on iPhones with Dynamic Island, in the Dynamic Island."*；*"To continue a Voice conversation outside ChatGPT, turn on Background conversations in Settings → Voice."* [Release Notes](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)。
- 📗 **导出只能在 web**：*"You can export your data from ChatGPT web."* [iOS FAQ](https://help.openai.com/en/articles/7885016-chatgpt-ios-app-faq)。
- 🔵 **草稿持久化 / 后台恢复生成 / "长答案完成"推送**：本次未检索到官方明文 → **不声称**。（发行说明中 "push notification" 唯一命中属于家长控制通知，非长答案完成推送。）

### 7. 长会话性能
- 📗 **官方性能设计（最有价值的一条）**：*"To keep the system fast and reliable, we only keep a compact list of your most recent conversations in the fast-loading sidebar. Older chats are trimmed from that quick cache to save space and avoid slowdowns. Nothing is deleted: if you need an older chat, searching or opening a conversation forces a full fetch from the source and will show it (and can refresh the cached list)."* [10056348](https://help.openai.com/en/articles/10056348-finding-your-chats-projects-and-files-in-chatgpt)。
- 🟡 长对话卡顿抱怨（web 为主）：[Web UI Unresponsive in long chats that include code](https://community.openai.com/t/web-ui-unresponsive-in-long-chats-the-include-code/1391189)。

### 8. 文本选择 / 复制 / 分享
- 📗 writing/code block 操作面：*"Copy the text." / "Open the block in a full-screen editing view." / "Share a read-only link for supported code blocks, when sharing is available."* [20001246](https://help.openai.com/en/articles/20001246-working-with-writing-blocks-and-code-blocks-in-chatgpt)。
- 🟡 "一键复制整段回答"缺失的旁证：存在第三方 App/教程专门解决"整段复制 ChatGPT 对话"，如 [ChatCopy 教程](https://note.com/pikopikopanda/n/na6446d87f233)。弱证据，仅作参考。

---

## 二、Claude iOS（Anthropic）

### 1. New chat / session 模型
- 📗 **iOS 删除/重命名**：*"Open your chat list. Touch and hold the conversation. Tap 'Rename' or 'Delete.'"*；也可在当前会话 *"tap the '⋯' button in the top right corner, tap 'Delete,' then confirm."* 来源：[Delete or rename a conversation](https://support.claude.com/en/articles/8230524-delete-or-rename-a-conversation)。
- 📗 **批量删除**（web）：Chats and tasks → ⋮ → Select → 复选/Select all → Delete。同上。
- 📗 **Projects**：*"Projects allow you to create self-contained workspaces with their own chat histories and knowledge bases."*；*"Free users can create a maximum of five projects."* 来源：[What are projects?](https://support.claude.com/en/articles/9517075-what-are-projects)。
- 📗 **跨会话检索**：Claude 用 RAG 检索历史会话，*"These searches use Retrieval-Augmented Generation (RAG) and will appear as tool calls during your conversations."*；范围限 *"All chats outside of projects. Individual project conversations"*；incognito 用 ghost icon。来源：[Use Claude's chat search and memory](https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context)。
- 🔵 **pin/archive**：本次未检索到官方 iOS 说明 → 不声称。

### 2. Send lifecycle
- 📗 官方发行说明记录 **回答完成后通知**：*"Get notified when Claude needs you: Turn on notifications and Claude will ping you when it needs your permission or when a task is complete. Now you can switch to other work while Claude handles things in the background."* 语境为 Claude in Chrome / 后台任务；日期锚点为同段落下的 **September 29, 2025**。来源：[Claude Release Notes](https://support.claude.com/en/articles/12138966-release-notes)。
- 🔵 **stop / regenerate / edit-and-resend / continue 的具体按钮**：本次**未检索到 Claude 帮助中心对这些按钮的明文文档** → 不声称。建议真机核对（这与 ChatGPT 有明确 "Regenerate" 文案形成对比）。
- 🟡 社区 issue 反映移动端"思考不显示"等一致性缺陷：[claude-code#83925](https://github.com/anthropics/claude-code/issues/83925)（属 Claude Code/remote 语境，非纯 iOS chat，谨慎使用）。

### 3. Extended thinking 显示（官方文档最完整的一家）
- 📗 [Change the model, effort, and thinking settings](https://support.claude.com/en/articles/8664678-change-the-model-effort-and-thinking-settings)。原文：
  - *"When thinking is enabled, you'll see: A 'Thinking' indicator with a timer showing how long Claude has been processing. An expandable 'Thinking' section above Claude's response."*
  - *"Click the 'Thinking' section to view Claude's thought process summary and problem-solving approach."*
  - 档位：Low / Medium / High / **Extra high (xhigh)** / **Max**；*"Thinking and effort are separate settings"*。
  - *"Thinking cannot be turned off in Claude when using Claude Fable 5.1 or Claude Opus 5."*
- 📗 旧 "使用扩展思考" 文章 (10574485) 现 **301 重定向**到 8664678 → 官方已合并到统一设置页。
- 📗 发行说明 2026-03-25：*"Interactive apps in Claude for iOS and Android — The Claude mobile app can now connect to fully interactive apps. Pull up live charts, sketch diagrams, and build shareable assets, all rendered visually right in your conversation."* [Release Notes](https://support.claude.com/en/articles/12138966-release-notes)。

### 4. 引用
- 🔵 本次未检索到 Claude 帮助中心关于 inline citations / sources 面板的专门文档 → **不声称**（Kimi/ChatGPT 均有官方描述，Claude 未见）。

### 5. 附件 / 语音（iOS）
- 📗 [Upload files to Claude](https://support.claude.com/en/articles/8241126-upload-files-to-claude)：
  - 类型：PDF、DOCX、CSV、TXT、HTML、ODT、RTF、EPUB、JSON、XLSX*（*需开启 code execution）；图片 JPEG/PNG/GIF/WebP。
  - Chat 内：*"File size: 500MB per file / Number of files: Up to 20 files per chat / Image dimensions: Up to 8000x8000 pixels / Number of pages: PDFs are limited to 1000 pages"*。
  - Project 文件：*"File size: 30MB per file / Number of files: Unlimited, but total content must fit within Claude's context window"*。
  - PDF 视觉：*"Claude analyzes both text and visual elements ... in PDFs of 100 pages or fewer. For PDFs from 101 to 1000 pages, Claude processes text only."*
  - 入口（web）：*"Click the '+' button in the lower left corner of the chat box → Select 'Add files or photos'"*。
- 📗 **iOS 系统级动作**：Messages/Mail/Calendar/Maps/Reminders/Location 集成，Health 为 beta 且限美区 Pro/Max。来源：[Use Claude with iOS apps](https://support.claude.com/en/articles/11869619-use-claude-with-ios-apps)。
- 🔵 语音输入/dictation 的官方 iOS 说明：未检索到 → 不声称。

### 6. Backgrounding / 离线 / 跨端
- 📗 **云端继续跑**：发行说明 2026-07-07 *"Cowork runs your sessions remotely (in beta), so your sessions and files are saved to your Claude account and go where you go, on any device. Work continues when you close your laptop, and scheduled tasks run with no device online."* [Release Notes](https://support.claude.com/en/articles/12138966-release-notes)。
- 📗 **通知**：见 §2（*"Claude will ping you when it needs your permission or when a task is complete"*）。
- 🔵 草稿持久化 / 普通 chat 的"回答完成推送"：官方未明文 → 不声称。

### 7. 长会话性能
- 🔵 本次未检索到官方或高可信用户来源 → **不声称**。

### 8. 选择 / 复制 / 分享
- 📗 **分享链接（快照语义，明确）**：*"anyone with the link can view the chat snapshot. The chat snapshot includes all messages that were sent prior to sharing the chat ... All messages sent after sharing a chat will remain private by default."*；*"If you share a chat that contains an attached file, the file itself is not included in the shared snapshot"*；MCP 原始数据隐藏；Settings → Privacy 可管理/撤销。来源：[Share and unshare chats](https://support.claude.com/en/articles/10593882-share-and-unshare-chats)。
- 🔵 逐条消息 "copy" 按钮：未见官方专文，但分享/编辑块机制已文档化。

---

## 三、对比项（可选）：Gemini / Kimi / 豆包 iOS

- 📗 **Gemini iOS regenerate 语义（官方，且与 ChatGPT 差异明显）**：*"Important: You can regenerate only the most recent response in a chat."*；移动端路径 *"Below the response, tap More > Other drafts. Swipe to the end of the drafts. ... tap Regenerate."*；web 端有 *"arrows to switch between versions"*。平台参数 `co=GENIE.Platform%3DiOS`。来源：[Regenerate or modify responses from Gemini Apps](https://support.google.com/gemini/answer/14262426?hl=en&co=GENIE.Platform%3DiOS)。
- 📗 **Kimi**：帮助中心含"对话超过 200,000 字？""无法发送消息 / 出现红圈？"等条目，说明超长对话有显式错误态文案；删除会话后分享链接失效。来源：[Kimi 聊天常见问题](https://www.kimi.ai/zh-hans/help/others/chat-issues)。
- 🔵 **豆包 iOS**：仅取得 App Store 页面 [豆包 App Store](https://apps.apple.com/cn/app/id6459478672)，**未找到**官方交互行为帮助文档 → 不声称。

---

## 四、证据表（claim | URL | 日期 | 置信度）

| # | 主张 | URL | 来源日期 | 置信度 |
|---|---|---|---|---|
| 1 | ChatGPT iOS 历史在 sidebar Recents；删除走三点+确认 | https://help.openai.com/en/articles/7885016-chatgpt-ios-app-faq | 页面"Updated: 15 days ago"（观察 2026-09-12） | 高（📗） |
| 2 | 归档会话可被搜索但不在 sidebar；Settings 内单独访问 | https://help.openai.com/en/articles/10056348-finding-your-chats-projects-and-files-in-chatgpt | "Updated: 14 days ago" | 高（📗） |
| 3 | sidebar 只缓存最近会话，旧对话 trim，搜索时全量拉取 | 同上 | 同上 | 高（📗） |
| 4 | 生成失败 → "click 'Regenerate' button" | https://help.openai.com/en/articles/7996703-troubleshooting-chatgpt-error-messages | "Updated: 28 days ago" | 高（📗） |
| 5 | 引用可点开来源；Sources 列表；iOS 结果可含地图 | https://help.openai.com/en/articles/9237897-chatgpt-search | "Updated: 22 days ago" | 高（📗） |
| 6 | ChatGPT 文件：512MB/文件、2M tokens、图片 20MB、80/3h | https://help.openai.com/en/articles/8555545-file-uploads-faq | "Updated: 17 hours ago" | 高（📗） |
| 7 | 语音转写不留存音频 | https://help.openai.com/en/articles/7885016-chatgpt-ios-app-faq | 同上 | 高（📗） |
| 8 | 编辑消息产生新分支（支持说法） | https://community.openai.com/t/chatgpt-mobile-app-cannot-edit-message/1315724 | 2025-07-14 起 | 中（🟡） |
| 9 | 生成中排队未被官方文档化 | https://community.openai.com/t/feature-request-message-queue-while-gpt-is-generating-responses/1155949 | 2024–2025 | 中（🟡/🔵） |
| 10 | thinking 档位重命名与 thinking time 调整 | https://help.openai.com/en/articles/6825453-chatgpt-release-notes | 2026-01-10 / 02-03 / 02-04 等 | 高（📗） |
| 11 | Claude "Thinking" 指示器含计时 + 可展开 Thinking 段 | https://support.claude.com/en/articles/8664678-change-the-model-effort-and-thinking-settings | 页面无绝对日期 | 高（📗） |
| 12 | Claude effort 档位 Low/Medium/High/xhigh/Max；Fable 5.1/Opus 5 不可关思考 | 同上 | 同上 | 高（📗） |
| 13 | Claude chat 文件 500MB / 20 个 / PDF 1000 页；Project 文件 30MB | https://support.claude.com/en/articles/8241126-upload-files-to-claude | 页面无绝对日期 | 高（📗） |
| 14 | Claude iOS 长按会话可 Rename/Delete | https://support.claude.com/en/articles/8230524-delete-or-rename-a-conversation | 页面无绝对日期 | 高（📗） |
| 15 | Claude 免费版最多 5 个 Projects | https://support.claude.com/en/articles/9517075-what-are-projects | 页面无绝对日期 | 高（📗） |
| 16 | Claude 跨会话检索走 RAG，表现为 tool call | https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context | 页面无绝对日期 | 高（📗） |
| 17 | Claude 分享为快照，附件不入快照 | https://support.claude.com/en/articles/10593882-share-and-unshare-chats | 页面无绝对日期 | 高（📗） |
| 18 | 通知：任务完成/需授权时 ping | https://support.claude.com/en/articles/12138966-release-notes | September 29, 2025 | 中高（📗，语境为 Chrome/Cowork） |
| 19 | Cowork 云端会话跨设备持续运行 | 同上 | 2026-07-07 | 高（📗） |
| 20 | Gemini iOS 仅能重生成最后一条；移动端走 More > Other drafts | https://support.google.com/gemini/answer/14262426?hl=en&co=GENIE.Platform%3DiOS | 页面无绝对日期 | 高（📗） |
| 21 | Kimi 超长对话有显式错误文案；删除会话令分享链接失效 | https://www.kimi.ai/zh-hans/help/others/chat-issues | 页面无绝对日期 | 中（📗，条目级） |

---

## 五、Patterns DeepSeek 缺失清单（相对上述基线）

按"可验证、可复刻"排序；每条给出对标依据编号（见表）。

1. **侧栏缓存/虚拟化策略**：官方明说 sidebar 只保留最近会话、旧对话按需全量拉取（#3）。DeepSeek iOS 若在长历史上一次性全量加载，属性能基线缺口。
2. **归档 ≠ 删除 且归档仍可搜索**（#2）。需要独立 archive 状态 + 搜索索引覆盖归档 + Settings 内归档入口。
3. **消息编辑 = 分支（branch）语义**（#8）：编辑用户消息应生成版本分支、可前后切换，而非追加新消息。
4. **失败态显式 retry 文案与按钮**（#4）："Regenerate" 必须是可见、可复述的失败恢复路径；挂起态需 30–60s 判定 + Stop。
5. **思考块形态**（#11）：折叠段位于回答上方、含计时指示器、可展开查看摘要 —— 这是官方文档级要求，不只是视觉。
6. **重生成前可切换检索策略**（#5 与 #20 对照）：ChatGPT 支持 "Try again / Search the web"；Gemini 支持 drafts 版本切换 + 仅最后一条可重生成。DeepSeek 需要明确版本/策略切换模型。
7. **引用可点开 + Sources 汇总面板**（#5）。点击引用必须能打开来源；列表内可见多源。
8. **附件限制需要文档化的硬数字**（#6/#13）：单文件体积、单会话数量、图片像素/体积、PDF 页数 —— 竞品全部公开，DeepSeek 若未公开即处于"不可预期"劣势。
9. **分享为快照并明示边界**（#17）：分享链接 = 分享时刻的快照；附件与工具原始数据不入快照；可撤销、可审计。
10. **跨设备会话接力 / 后台继续**（#19）：闭屏后任务在云端继续，并在需要用户时推送（#18）。
11. **一键复制/分享整段回答**（#8 ChatGPT 侧仅弱证据）：至少提供逐条 copy 与整段 copy 两条路径，避免依赖第三方工具。
12. **可中断的代码执行**（#4 ChatGPT "stop running code"）—— 若 DeepSeek 支持代码运行，需有 stop。

**明确未证实、不可当作基线要求的项**（避免团队误抄）：
- ChatGPT iOS 的 "Thinking" 自动折叠/耗时秒数的具体 UI：官方未文档化（🔵）。
- ChatGPT/Claude 在"普通长答案完成"时发送 push：官方未文档化（🔵）。
- Claude 的 citations 面板形态：官方未文档化（🔵）。
- 豆包 iOS 的交互规范：未找到官方文档（🔵）。
- ChatGPT 单条消息图片张数上限：官方只给 20MB/张，张数未标注。
