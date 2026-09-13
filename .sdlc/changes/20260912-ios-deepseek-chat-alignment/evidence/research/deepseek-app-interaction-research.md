# DeepSeek 官方 App / Web App 交互行为（状态机与边界情况）社区证据报告

调研日期：2026-09-12 ｜ 方法：web_search + web_fetch + HN Algolia API + GitHub Issues API + Reddit RSS + App Store 评论 RSS
**重要限制**：Reddit 的 JSON/HTML 端点在本环境被 403/429 拦截，仅 `.rss` 搜索与部分帖子 RSS 可用；知乎（Cloudflare）、linux.do 搜索 API、sspai 搜索 API 亦被拦截。**无法引用原文者一律标注“unverified”。**

---

## 0. 核心结论（TL;DR）

1. **输入框在生成中是可用的、且支持“打断并发送”**——2026-08-10 的网页变更检测显示“生成状态改为消息级追踪，支持按消息停止/继续生成……生成中可先输入，"打断并发送"与并行流默认开启”。**发送按钮不是被 stop 替换，而是新增消息级停止/继续能力。**
2. **“停止生成”是明确按钮**；点停后**可以“继续”**，且存在“停止后继续 → 再次进入死循环”的 bug（#1587）。
3. **重新生成/编辑消息在 2026-05-29 起被限流**：普通对话重新生成约 3–6 次、专家模式约 3 次、编辑约 6 次触顶（媒体转述，非逐字官方文案）。**编辑/重新生成已从无限变为有配额**，是当前最大 UX 争议。
4. **深度思考块：官方默认“思考中展开、思考结束后自动折叠”**；该行为直到 **2026-09-12 的 2.5.1 版才写进更新日志**（“支持思考过程自动折叠”）。此前社区靠油猴脚本自行实现，说明长期缺失。
5. **联网搜索的引用是内联数字标记 + 文末来源列表**，且**无法关闭**（#1626）。点按行为未取得证据 = unverified。
6. **iOS 端问题集中**：消息滑动动画导致晕眩、输入框下方按钮布局、键盘回车/换行、复制粘贴表格格式错乱。
7. **长对话**：自动滚动争抢阅读位置、无限重复需手动暂停、历史整段消失、幽灵标题。

---

## 1. 生成中的输入状态机

- **证据（强）**：linux.do 的“DeepSeek 页面变更检测”帖，2026-08-10，对 chat.deepseek.com 前端包 diff 的总结：
  > “变化：生成状态改为消息级追踪，支持按消息停止/继续生成。影响：生成中可先输入，"打断并发送"与并行流默认开启。”
  > “风险：发送/停止逻辑重构，建议回归多流并发与隐私模式场景。”
  - 该帖给出可比对的 Commit ID（`a610cb2 → 04c4137`）与 JS 资源哈希，属于可复核的一手观测。
  - URL: https://linux.do/t/topic/2730962
- **推论（中）**：因此 2026-08 起输入框**不被禁用、不排队**，而是“打断并发送”（interrupt-and-send）语义；`userStorage` 持久化新增“置顶会话折叠状态”。
- **更早的形态（unverified）**：无法取得 2026-08 之前“输入框是否禁用/发送键变停止键”的逐字社区描述。

## 2. 停止 / 继续生成

- **#1587（2026-08-17，中文，逐字）**：
  > “模型在生成回答过程中陷入"无限思考"状态（具体表现为开始重复输出相同或高度相似的内容）。手动点击"停止生成"按钮 可以暂停思考，点继续还是会继续”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1587
  - 说明：存在 **停止生成** 与 **继续** 两个动作；停止后继续会恢复生成，但会把已进入的死循环一并恢复。
- **#1550（2026-08-07，中文，逐字）**：
  > “必须由用户手动点击“暂停”按钮才能中断” / “所有回答均中断在逻辑未完成之处，显然是用户手动点击"停止生成"按钮所致”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1550
  - 触发条件：多轮长对话（约 10+ 轮）后模型失去 EOS 预测能力，无限重复短句。

## 3. 重新生成 / 编辑重发 / 继续生成

- **限流事实（媒体，二手转述）**：钛媒体 2026-05-30：
  > “5月29日下午，不少网友发现，DeepSeek重新生成、修改有次数限制了。连续修改或重新生成几次后，页面会提示达到上限。有网友反馈，在普通对话中，重新生成3到6次后就会达到上限；而在专家模式下，可能只有3次机会。修改输入次数上限一般是6次。”
  - URL: https://m.tmtpost.com/8008353.html
  - 注意：以上为**媒体转述的用户反馈**，“页面会提示达到上限”的**确切文案未取得 = unverified**。
- **#1375（2026-05-30，逐字）**：
  > “The new regeneration and edit-ing limit makes the use of deepseek more clanky… I hope this feature gets scrapped, if not have limits increased (30 or more for regeneration and edit respectively).”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1375
- **#1372（2026-05-29，逐字）**：
  > “today's update with the message editing limit has made my game practically impossible… Strictly limiting edits kills the entire collaborative creative process.”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1372
- **#1445（2026-06-21，逐字）**：
  > “This version contains 6 edition and generation limits. I can't edit or regenerate after reached those limits. … you limit to 6 times”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1445
- **“重新生成”弹窗选项的变化（逐字，#1381，2026-05-31）**：
  > “Regenerate popup has redundant/search options – "Search the web" works even when main toggle is OFF, but can't be used twice in a row (it swaps to "skip search").”
  > “Once enabled, you cannot switch back to fast mode without starting a new chat.”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1381
- **风格选项被移除（逐字，#1635，2026-09-10）**：
  > “when clicking "Regenerate", the previous options to choose between "Concise" and "Detailed" response styles have disappeared — now there's only a single default option.”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1635
- **无“继续生成”入口的旁证（unverified 归属）**：continuedev/continue #4007 标题为 “DeepSeek-R1 model has no "continue generating" option”，但这是**第三方 Continue 插件**的问题，不能直接当作官方 App 结论。

## 4. 深度思考（thinking）块渲染

- **官方更新日志（强证据，App Store 2.5.1，2026-09-12）**：
  > “- 新模型上线，快速、专家、识图模式合并升级
  >  - 支持思考过程自动折叠
  >  - 修复部分已知问题”
  - URL: https://itunes.apple.com/lookup?id=6737597349&country=cn （version 2.5.1，currentVersionReleaseDate 2026-09-12T08:22:12Z）
  - **结论：思考过程“自动折叠”是 2026-09-12 才正式具备的能力**，即此前思考块要么一直展开、要么不折叠。
- **用户此前诉求（逐字，Greasy Fork 脚本评论，2026-06-03）**：
  > “就是模型还在思考（推理）过程中的时候不折叠，等最后出答案的时候折叠思考部分？主要是如果推理过程很长（比如专家模式或者复杂问题）的时候，没输出答案时折叠了思考过程就看不到进度了，如果能让用户实时观察到模型的推理过程，并在推理结束输出答案的时候将其折叠，那舒适度就很高了。”
  - URL: https://greasyfork.org/zh-CN/scripts/580006-deepseek%E9%BB%98%E8%AE%A4%E6%8A%98%E5%8F%A0%E6%80%9D%E8%80%83/discussions/330825
  - 该油猴脚本（2026-05-27 创建）描述：“将Deepseek的思考过程默认折叠收起，支持两种模式：始终折叠和思考结束后折叠（可配置延迟时间）”——反证官方默认**不**在流式期间折叠。
- **App Store 1 星（逐字）**：
  > “把思考模式变回最初的样子 :: 现在的深度思考的思考过程跟屎一样”
  - URL: 同 App Store RSS（`research/appstore_reviews.txt`）
- **计时器（elapsed-seconds timer）**：**未取得任何证据 = unverified**。无法确认是否有秒级计时。

## 5. 联网搜索 / 引用展示

- **#1626（2026-09-04，逐字，最具体）**：
  > “When the "Smart Search" (Web Search) feature is enabled, the DeepSeek AI model automatically appends inline citations and reference markers (e.g., `[Reference 1]`, `[citation:2]`, etc.) to the generated response… Notice that despite the explicit instruction, the output contains inline numerical references like `[Reference 1]` or a "Sources" list at the end. … There is no standalone setting to keep Web Search active while disabling the automatic citation behavior.”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1626
  - **结论：内联数字标记 + 文末 Sources 列表，且不可关闭。** 开关名为 “Smart Search”（智能搜索）。
- **开关不可靠（逐字，#1381）**：
  > “Search toggle is unreliable – When ON, DeepSeek often ignores it and "vibes" instead of searching. Users end up regenerating multiple times hoping search will trigger.”
- **未勾选也会联网（逐字，#892，2025-06-08）**：
  > “**此时没有勾选网页端的联网搜索** 但V3主动搜索了50个网页”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/892
- **点击引用 chip 会发生什么（是否打开侧栏/新标签/预览）**：**未取得任何证据 = unverified。**

## 6. 错误文案 / 超时 / 断网 / 重试

- **可逐字引用的英文文案（Reddit 帖标题，r/DeepSeek，2026-05-19）**：
  > “"Server is busy. Try again later, or use Instant mode."”
  - URL: https://www.reddit.com/r/DeepSeek/comments/1th89w3/server_is_busy_try_again_later_or_use_instant_mode/
  - 帖子正文/回复因 Reddit 403/429 未能抓取 → 正文内容 unverified；标题逐字来自 Reddit RSS 搜索返回。
- **中文“服务器繁忙”系列文案**：多篇二手文章与搜索摘要提到 “服务器繁忙，请稍后再试”“繁忙请稍后重试”，但**未能抓到官方 UI 的逐字截图或引用 = unverified**（例如 https://cloud.baidu.com/article/3716979 仅为 SEO 文章）。
- **重试是否复制消息（duplicate）**：**未取得证据 = unverified。**
- **流式静默挂起（逐字，#1608，2026-08-26，API 侧但反映同一后端）**：
  > “intermittently stops sending chunks mid-generation without closing the connection — typically mid-`reasoning_content` (thinking) — with no terminal `finish_reason` chunk and no `[DONE]`. The stream simply goes silent and stays open indefinitely.”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1608
- **内容被替换为拒答（逐字，Reddit 评论，2026-04-21）**：
  > “yeah, it often completes the query but replaces it when it ends” / “Do you mean the "sorry, this is out of my scope, let's talk about something else"?”
  - URL: https://www.reddit.com/r/DeepSeek/comments/1sqvv0c/ （帖：Better DeepSeek 扩展）
  - HN 亦有同类观测（2025-01-26）：“The web UI was printing a good and long response, and then somewhere towards the end the answer disappeared and changed to "Sorry, that's beyond my current scope. Let's talk about something else."” https://news.ycombinator.com/item?id=42829483
  > **注意：该评论推测“real-time self-censorship”，属用户主观归因，非官方确认。**

## 7. 历史记录丢失 / 同步

- **旧标签页覆盖新历史（逐字，#1624，2026-09-03）**：
  > “从停留在旧进度的标签页继续发送消息，会导致另一个标签页中较新的会话内容消失，表现为旧进度覆盖了新历史。**刷新页面后，两个标签页都会统一回到 B 的会话进度**；A 原先在第 3 条之后新增的内容仍然全部缺失，刷新无法恢复。”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1624
- **长对话整段消失（逐字，DeepSeek-R1 #805，2026-02-25）**：
  > “Approximately 2-3 hours into the conversation, when I tried to scroll up to review previous messages, the entire chat history had disappeared. This is not a case of session expiration warning - the history simply vanished without any notification.”
  - URL: https://github.com/deepseek-ai/DeepSeek-R1/issues/805
- **幽灵标题（逐字，DeepSeek-R1 #844，2026-05-18）**：
  > “User deletes a chat on DeepSeek web. Chat disappears from the list. User restarts the browser… The deleted chat title comes back (usually named "DeepSeek" or "New Chat"). … The cycle repeats indefinitely.”
  - URL: https://github.com/deepseek-ai/DeepSeek-R1/issues/844

## 8. 长对话性能 / 滚动 / 内存

- **自动滚动与阅读争抢（逐字，#1302，2026-05-13）**：
  > “As the AI generates a response, the screen auto‑scrolls to follow the new text, pushing previously generated content upward. This prevents the user from reading earlier parts of the reasoning or answer while generation is still in progress. The constant "push‑up" effect is distracting and removes control from the user.”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1302
- **滚动动画导致晕眩（App Store 3 星，逐字）**：
  > “最近更新的屏幕自动缓慢向下拉动的视觉效果不如从前。先加速后减速的效果使我看着感到晕眩，不如从前一行一行匀速打出字的视觉效果。”
  - URL: App Store 中国区评论（见 `research/appstore_reviews.txt`）
- **无限重复需手动暂停**：见 #1550 / #1587。
- **消息虚拟化 / 内存 / 崩溃**：**未取得可引用证据 = unverified。** 无逐字社区描述。

## 9. iOS 端特有问题

- **消息动画（英文，逐字）**：
  > “And the "Gradual" sliding of the message or whatever” — 1 星，《It says the same thing.》
  - URL: App Store 美国区评论
- **输入框下方按钮（逐字）**：
  > “下面两个按钮很影响交互体验，为啥放在输入框下面，没有一个ai把按钮放在输入框下的”
  - URL: App Store 中国区评论
- **键盘换行/回车（逐字，#1249，2026-04-25）**：
  > “The first issue is on my iPhone 15 Pro Max, and its related to the keyboard. This problem was not there before the new update. I am unable to add a line break and move to the next line. Also, when there is a submit button, the keyboard should not show the submit/enter key like in other AI apps such as Gemini, Claude, or ChatGPT.”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1249
- **复制/粘贴格式（逐字）**：
  > “但粘贴复制的时候格式总是乱，特别是表格。”
  - URL: App Store 中国区评论
- **文本选择（无法选中/选中困难）**：**未取得 iOS 官方 App 的逐字证据 = unverified。** 唯一相关线索是第三方读屏论坛 bbs.tatans.cn 的讨论（“长按去选择文本里选择呗！”“这个不好用”），指向 App 内文本选择的可用性抱怨，但**未明确平台版本**，仅作弱线索：https://bbs.tatans.cn/topic/134306
- **无障碍回归（逐字标题，#1602，2026-08-24）**：
  > “new version of the deepseek apk don't work with my screen reader talkback please fix it”
  - URL: https://github.com/deepseek-ai/DeepSeek-V3/issues/1602

## 10. 模式合并（2026-09-10）引发的状态机变化

- **事实（逐字，DoNews，2026-09-10 19:09:38）**：
  > “9月10日，DeepSeek的界面已将快速、专家、识图模式进行合并，不再单独设立专家模式。据了解，DeepSeek专家模式于今年4月8日上线。快速模式适合日常对话，即时响应；专家模式擅长复杂问题，支持深度思考和智能搜索。6月18日，DeepSeek网页及App端均新增了“识图模式”。”
  - URL: https://www.donews.com/news/detail/8/6705426.html
- **用户反应（逐字）**：
  > “Please bring back the ability to choose the mode yourself (Expert, Quick, Recognition); it’s very inconvenient without them.”（US 1 星）
  > “新界面真的好丑 还我专家模式”（CN 1 星）
  > **#1231（2026-04-20）**：“After uploading a file in the DeepSeek chat interface, the toggle/slider to switch between "Instant" and "Expert" mode becomes inaccessible… The only way to change the mode is to remove the uploaded file, switch modes, and then re-upload the file.” https://github.com/deepseek-ai/DeepSeek-V3/issues/1231
  - 说明：合并**取消了一个可选状态维度**，把“专家/深度思考”从用户可控变为自动路由；#1381 早在此前就请求“可在同一会话内切换、不要锁死”。

---

## 11. 证据表（claim | verbatim quote | URL | date | confidence）

| Claim | Verbatim quote | URL | Date | Conf |
|---|---|---|---|---|
| 生成中可输入，且有“打断并发送”；生成状态改为消息级、可按消息停止/继续 | “生成状态改为消息级追踪，支持按消息停止/继续生成。影响：生成中可先输入，"打断并发送"与并行流默认开启。” | https://linux.do/t/topic/2730962 | 2026-08-10 | 高（前端 diff 观测） |
| 发送/停止逻辑刚重构，存在回归风险 | “风险：发送/停止逻辑重构，建议回归多流并发与隐私模式场景。” | 同上 | 2026-08-10 | 高 |
| 存在“停止生成”按钮，且停止后可“继续” | “手动点击"停止生成"按钮 可以暂停思考，点继续还是会继续” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1587 | 2026-08-17 | 高 |
| 长对话无限重复，必须手动暂停 | “必须由用户手动点击“暂停”按钮才能中断” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1550 | 2026-08-07 | 高 |
| 重新生成/编辑自 2026-05-29 起限次（普通 3–6 次、专家约 3 次、编辑约 6 次） | “5月29日下午…连续修改或重新生成几次后，页面会提示达到上限。有网友反馈，在普通对话中，重新生成3到6次后就会达到上限；而在专家模式下，可能只有3次机会。修改输入次数上限一般是6次。” | https://m.tmtpost.com/8008353.html | 2026-05-30 | 中（媒体转述用户反馈） |
| 编辑/重新生成达到 6 次上限后无法操作 | “This version contains 6 edition and generation limits. I can't edit or regenerate after reached those limits.” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1445 | 2026-06-21 | 高 |
| 编辑限次直接破坏创作型用法 | “today's update with the message editing limit has made my game practically impossible” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1372 | 2026-05-29 | 高 |
| 重新生成弹窗有 search 选项且状态互换、易混淆 | “Regenerate popup has redundant/search options – "Search the web" works even when main toggle is OFF, but can't be used twice in a row (it swaps to "skip search").” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1381 | 2026-05-31 | 高 |
| 专家模式一旦开启无法切回快速模式 | “Once enabled, you cannot switch back to fast mode without starting a new chat.” | 同上 | 2026-05-31 | 高 |
| 重新生成的 Concise/Detailed 风格选项被移除 | “the previous options to choose between "Concise" and "Detailed" response styles have disappeared — now there's only a single default option.” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1635 | 2026-09-10 | 高 |
| 思考过程“自动折叠”为 2026-09-12 新增能力 | “- 支持思考过程自动折叠” | https://itunes.apple.com/lookup?id=6737597349&country=cn | 2026-09-12 | 高（官方 release notes） |
| 此前思考中折叠会导致看不到进度 | “如果推理过程很长…没输出答案时折叠了思考过程就看不到进度了” | https://greasyfork.org/zh-CN/scripts/580006-…/discussions/330825 | 2026-06-03 | 高 |
| 联网搜索引用为内联数字标记 + 文末 Sources，且不可关闭 | “automatically appends inline citations and reference markers (e.g., `[Reference 1]`, `[citation:2]`, etc.)… a "Sources" list at the end… There is no standalone setting to keep Web Search active while disabling the automatic citation behavior.” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1626 | 2026-09-04 | 高 |
| 联网开关不可靠，开启后模型可能不搜 | “Search toggle is unreliable – When ON, DeepSeek often ignores it and "vibes" instead of searching.” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1381 | 2026-05-31 | 高 |
| 未勾选联网也可能主动搜索 | “**此时没有勾选网页端的联网搜索** 但V3主动搜索了50个网页” | https://github.com/deepseek-ai/DeepSeek-V3/issues/892 | 2025-06-08 | 高 |
| 英文错误文案 “Server is busy. Try again later, or use Instant mode.” | “"Server is busy. Try again later, or use Instant mode."” | https://www.reddit.com/r/DeepSeek/comments/1th89w3/ | 2026-05-19 | 中（仅帖标题逐字） |
| 流式生成中途静默挂起，无 finish_reason/[DONE] | “intermittently stops sending chunks mid-generation without closing the connection… no terminal `finish_reason` chunk and no `[DONE]`.” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1608 | 2026-08-26 | 高（API 侧） |
| 回答完成后被替换为拒答 | “yeah, it often completes the query but replaces it when it ends” | https://www.reddit.com/r/DeepSeek/comments/1sqvv0c/ | 2026-04-21 | 中 |
| 旧标签页发消息会覆盖另一标签页较新历史，刷新不可恢复 | “从停留在旧进度的标签页继续发送消息，会导致另一个标签页中较新的会话内容消失…刷新页面后…A 原先在第 3 条之后新增的内容仍然全部缺失” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1624 | 2026-09-03 | 高 |
| 长会话中历史整段无提示消失 | “Approximately 2-3 hours into the conversation… the entire chat history had disappeared… the history simply vanished without any notification.” | https://github.com/deepseek-ai/DeepSeek-R1/issues/805 | 2026-02-25 | 高 |
| 删除会话后幽灵标题无限复活 | “The deleted chat title comes back (usually named "DeepSeek" or "New Chat")… The cycle repeats indefinitely.” | https://github.com/deepseek-ai/DeepSeek-R1/issues/844 | 2026-05-18 | 高 |
| 生成时自动滚动抢走阅读控制权 | “the screen auto‑scrolls to follow the new text, pushing previously generated content upward… removes control from the user.” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1302 | 2026-05-13 | 高 |
| iOS 滑动动画致晕眩 | “最近更新的屏幕自动缓慢向下拉动的视觉效果不如从前。先加速后减速的效果使我看着感到晕眩” | App Store 中国区 | 2026-09（近期） | 中（无精确日期） |
| iOS 输入框下方按钮影响交互 | “下面两个按钮很影响交互体验，为啥放在输入框下面，没有一个ai把按钮放在输入框下的” | App Store 中国区 | 2026-09（近期） | 中 |
| iOS 无法换行、键盘错误展示回车键 | “I am unable to add a line break and move to the next line. Also, when there is a submit button, the keyboard should not show the submit/enter key” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1249 | 2026-04-25 | 高 |
| iOS 复制粘贴格式错乱（尤其表格） | “但粘贴复制的时候格式总是乱，特别是表格。” | App Store 中国区 | 2026-09（近期） | 中 |
| 上传文件后无法切换 Instant/Expert | “the toggle/slider to switch between "Instant" and "Expert" mode becomes inaccessible… The only way to change the mode is to remove the uploaded file, switch modes, and then re-upload the file.” | https://github.com/deepseek-ai/DeepSeek-V3/issues/1231 | 2026-04-20 | 高 |
| 2026-09-10 三模式合并、取消专家模式 | “9月10日，DeepSeek的界面已将快速、专家、识图模式进行合并，不再单独设立专家模式。” | https://www.donews.com/news/detail/8/6705426.html | 2026-09-10 | 高 |

---

## 12. 明确标注为 unverified 的项

1. 联网搜索**引用 chip 点按后的行为**（打开侧栏/浏览器/预览面板）——无任何可用证据。
2. 深度思考块是否有 **elapsed-seconds 计时器**——无证据。
3. “重新生成/修改达到上限”的**中文确切提示文案**——仅有“页面会提示达到上限”的转述。
4. 中文 “服务器繁忙，请稍后再试” 是否为**官方 UI 逐字文案**——仅有 SEO 文章间接提及。
5. 失败**重试是否会复制/重发消息**（duplicate message）——无证据。
6. **消息虚拟化、内存占用、崩溃率**——无逐字证据；仅有“无限重复”与“历史消失”间接反映长对话不稳。
7. **iOS 官方 App 文本选择/复制的具体 bug**——仅有第三方读屏论坛弱线索与粘贴格式抱怨。
8. HN 上针对 DeepSeek **官方 App/Web UI 交互**的系统讨论——Algolia 检索到的命中几乎全是隐私/安全/模型发布，**UX 行为讨论极稀薄**；唯一相关的 UI 观测是 2024-05-13（“If you ask DeepSeek chat, your question literally disappears from the UI a second after you hit the return key.”，https://news.ycombinator.com/item?id=40342735 ，2024-05-13）与 2025-01-26 的回答被替换事件（https://news.ycombinator.com/item?id=42829483）。
9. 知乎、sspai、豆瓣：**本次未能取得任何可逐字引用的内容**（知乎 Cloudflare 拦截、sspai 搜索 API 返回空、无豆瓣命中）。

---

## 13. 给下游实现者（若在复刻该交互）的可操作要点

- 状态机需支持 **per-message** 的 `generating / stopped / continued` 三态，而不是全局 `isGenerating`；停止后“继续”必须能重新接管同一条消息。
- 生成中**不能禁用输入框**；需要 `interrupt-and-send`（打断并发送）与并行流开关（该能力 2026-08-10 起在官方网页默认开启）。
- **必须提供“停止生成”按钮**，并保证停止操作幂等、可恢复；否则长对话无限重复会变成用户必须手动干预的常态（#1550/#1587）。
- 思考块：默认应在推理中保持可见（否则用户失去进度感），**推理结束后折叠**；若折叠，建议加可配置延迟。计时器可作差异化但官方有无未验证。
- 引用：内联数字 chip + 文末来源列表是当前官方形态；同时要意识到“无法关闭引用”已引发抱怨（#1626），可把“保留联网但关闭引用”做成设置项作为差异化。
- 会话持久化必须做**多标签页版本校验**（否则旧标签覆盖新历史，且刷新不可恢复，#1624）；删除操作要同步清理本地缓存（幽灵标题，#844）。
- 流式必须有**闲置看门狗**：官方后端存在中途静默挂起、不发 `finish_reason`/`[DONE]` 的情况（#1608）。

---

*原始评论快照：`research/appstore_reviews.txt`（App Store cn/us/gb 近 100 条，含逐字文本）。*
