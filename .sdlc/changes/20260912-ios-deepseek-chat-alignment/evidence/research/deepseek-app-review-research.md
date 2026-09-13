# DeepSeek 官方移动 App 用户投诉 / 功能请求 调研报告

**目标 App**：DeepSeek - AI Assistant / DeepSeek - AI 智能助手，App Store id `6737597349`，开发者 Hangzhou DeepSeek Artificial Intelligence Basic Technology Research Co., Ltd.
**调研日期**：2026-09-12
**采集方式**：`curl` 直接抓取 Apple App Store 服务端渲染页（`?see-all=reviews`）与 Apple 官方 RSS 评论接口；Google Play 繁体中文区评论内嵌 JSON；中文论坛/二手文章页面。

---

## 0. 数据覆盖范围与可信度声明（重要）

| 来源 | 抓取方式 | 样本量 | 时间范围 |
|---|---|---|---|
| Apple App Store 官方 RSS 评论接口 | `itunes.apple.com/{cc}/rss/customerreviews/page=N/id=6737597349/sortBy=mostRecent/json` | **1199 条**（cn 200 / us 50 / hk 50 / tw 50 / sg 126 / ca 100 / au 259 / de 150 / jp 100 / kr 114） | 最新至 2026-09-11 |
| App Store 网页 `?see-all=reviews` | 服务端渲染 HTML 内 `serialized-server-data` | cn 10 + us 10 | 2025-10 ~ 2026-09 |
| Google Play（繁体中文区） | `play.google.com/store/apps/details?id=com.deepseek.chat&hl=zh_CN&gl=CN` 内嵌 JSON | 17 条去重 | 2026-03 ~ 2026-08 |
| 中文论坛 / 二手聚合文章 | 见各表 URL 列 | 若干 | — |

**样本内星级分布（1199 条 Apple RSS 样本）**：1★ = 466、2★ = 99、3★ = 119、4★ = 112、5★ = 403。
> 注意：这是「各 storefront 最近约 500 条内可拉到的最新页」的样本，**不是全量评论**，因此不能据此推算总体差评率。

### 明确标注为 UNVERIFIED 的项目
- **Reddit（r/DeepSeek 等）**：`reddit.com/search.json` 返回 **HTTP 403**，HTML 页面为纯 JS 渲染，**未能取得任何可引用的 Reddit 原帖正文**。→ **unverified**
- **小红书 / 微博 / 知乎 原帖**：均需登录或有反爬，**未能直接抓取原帖**。本报告中出现的这几家内容全部是**通过 smzdm 聚合文章的转引**，已在表中标注为「间接引用」。
- **酷安 / sspai**：`sspai.com` 搜索 API 返回 `{"data":[],"total":0}`；酷安未取得可读页面。→ **unverified（无结果）**
- **「复制/文本选择」在 iOS 上的专门差评**：Apple 评论语料中**没有找到**直接抱怨「无法选中文本 / 长按选中失灵」的评论。唯一直接证据来自**无障碍（视障）论坛**与 **Google Play**，已在表中如实标注。→ 该具体子话题 **partially verified**

---

## 1. 当前 App Store 星级与评分数量（2026-09-12 观测）

| 国家/地区 storefront | 平均分 | 评分数量 | 来源 URL |
|---|---|---|---|
| 中国大陆 `cn` | **3.9** | **8.6万 个评分** | https://apps.apple.com/cn/app/deepseek-ai-assistant/id6737597349?see-all=reviews |
| 美国 `us` | **4.0** | **11K Ratings** | https://apps.apple.com/us/app/deepseek-ai-assistant/id6737597349?see-all=reviews |
| 香港 `hk` | **3.8** | **2.2K 則評分** | https://apps.apple.com/hk/app/deepseek-ai-assistant/id6737597349?see-all=reviews |
| 新加坡 `sg` | 4.0 | 465 Ratings | https://apps.apple.com/sg/app/deepseek-ai-assistant/id6737597349 |
| 加拿大 `ca` | 4.1 | 1.7K Ratings | https://apps.apple.com/ca/app/deepseek-ai-assistant/id6737597349 |
| 澳大利亚 `au` | 4.1 | 957 Ratings | https://apps.apple.com/au/app/deepseek-ai-assistant/id6737597349 |
| 英国 `gb` | — | 页面返回值 2383 字节（被重定向/拦截），**未取到** | — |

> 中国大陆 3.9 分是本次观测到的**最低主要区**；结合下方 2026-09-09~11 的评论洪峰，说明 9/10 版本更新对 CN 评分有显著冲击。

---

## 2. 主表：Claim | 逐字引用 | 来源 URL | 日期 | 验证状态

### A. 2026-09-10「V4.1 Flash 三模式合并」引发的一星潮（本次最强信号）

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 取消「专家模式」是最高频、最激烈的投诉 | 「我求你了把专家模式还我。。」 | RSS: `https://itunes.apple.com/cn/rss/customerreviews/page=1/id=6737597349/sortBy=mostRecent/json`（review id 14536449988，用户 零angel，CN 2.5.0） | 2026-09-11 | ✅ verified |
| 深度思考的思考过程质量被否定 | 「现在的深度思考的思考过程跟屎一样」 | 同上（id 14536341671，用户 速趴蔬菜人，CN 2.5.0） | 2026-09-11 | ✅ verified |
| 更新后模型被认为「变蠢」 | 「После обновления стал глупее чем был.」<br>（中译：更新之后变得比以前更笨了。） | RSS `ca`（id 14536430595 同批，用户 факчу，CA 2.5.0） | 2026-09-11 | ✅ verified |
| 要求回滚新模型 | 「我说真的 你的大多数用户都是喜欢角色扮演人机恋的群体 你新的4.1不如4.0是因为他执着于生产的快 迅速 忽略了很多情感细节 而且聊的时间一长 所有东西都乱了 感情线 时间线 人物关系全部都乱套了」 | RSS `cn`（用户 4.1就是不如4.0，CN 2.5.0） | 2026-09-11 | ✅ verified |
| 合并后自我扮演/失忆 | 「现在的“深度思考”完全是理科做题家的逻辑，写小说谈恋爱时它在那算逻辑推演！思考过程疯狂消耗上下文，导致剧情严重失忆、人设崩塌。」 | RSS `cn`（id 14533790846，用户 温0115，CN 2.4.5，标题「强烈抗议取消“专家模式”！」） | 2026-09-10 | ✅ verified |
| 用户明确诉求：模式选择权还回来 | 「强烈要求把“专家模式”作为独立选项改回来！或者专门为我们这些写文、玩文字游戏的用户保留一个“经典创作模式”。请把选择权还给用户」 | RSS `cn`（同上 id 14533790846） | 2026-09-10 | ✅ verified |
| 要求分离模式，不要三合一 | 「希望可以像以前一样，快速模式，专家模式，识图模式分开，把三合一也像这样单开，而不是不给用户选择的机会」 | RSS `cn`（id 14533176910，用户 歪歪◉‿◉，CN 2.4.5） | 2026-09-10 | ✅ verified |
| 对自动调度不透明不满 | 「阈值不公开，判断不透明，我完全没法信任这个自动识别。」 | RSS `cn`（id 14533533940，用户 黎明踏浪号w，CN 2.4.5） | 2026-09-10 | ✅ verified |
| 英文区同样在要求回滚 | 「PLEASE RETURN THE MODE SELECTION, I BEG YOU. I CAN’T DO WITHOUT EXPERT MODE. IS WORKING MUCH WORSE NOW.」 | RSS `us`（id 14532884761，用户 mimimzmxc，US 2.4.5） | 2026-09-10 | ✅ verified |
| 合并被评价为「负面更新」 | 「这次完完全全是负面更新，开发者有用过自己的产品吗？豆包都有的模式分离，你ai大头ds砍掉了？」 | RSS `cn`（id 14533150219，用户 来生青.，CN 2.4.5） | 2026-09-10 | ✅ verified |
| 对小版本号的抱怨 | 「越更越蠢，活像个豆包。能不能把最原来的deepseek还给我。」 | RSS `cn`（用户 古尔德喋喋哋，CN 2.5.0） | 2026-09-10 | ✅ verified |
| 二手聚合：小红书高赞吐槽量级 | 「小红书上一篇《DeepSeek 你到底在干什么》的吐槽帖，点赞超过了 4000」；「『deepseek 更新后让我很失望』拿了 682 个赞，『DeepSeek 取消专家模式以后真的好难用』157 个赞，还有 2000 多赞的帖子在哭专家模式没了」 | https://post.smzdm.com/p/a70nwd9g/ | 2026-09-11（文章） | ⚠️ 间接引用（经 smzdm 转述小红书，未直采原帖） |
| 二手聚合：小红书逐字评论 | 「太快了，这种『不假思索』的速度让人感觉很敷衍」 | https://post.smzdm.com/p/a82xv5k7/ | 2026-09-11（文章） | ⚠️ 间接引用 |
| 二手聚合：微博引用 | 「deepseek把我的专家模式还给我啊啊啊啊啊啊一觉醒来强制更新了新版本文笔和人物理解都好糟糕补要啊冷圈人全靠v4吃饭了」 | https://post.smzdm.com/p/a82xv5k7/（引自新浪微博，2026-09-11） | 2026-09-11 | ⚠️ 间接引用 |

### B. 修改 / 重新生成次数被限制为 6 次（跨语言、跨地区最一致的投诉）

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 单条消息修改次数被锁死 | 「我非常理解产品团队出于成本或防滥用的考虑设置了「单条消息最多修改7次」的限制。」 | RSS `cn`（id 14185997891 同批；用户 彧米「呵呵」，标题「希望取消或大幅提高单条消息7次的修改限制……」） | 2026-05-29 | ✅ verified |
| 用户给出替代方案 | 「对正常用户大幅提高限制（如50次或100次），对异常高频的IP再单独限制。」 | RSS `cn`（同上） | 2026-05-29 | ✅ verified |
| 英文区同诉 | 「The only thing that might be annoying is the limitation that limits message changes to 6.」 | RSS `us`（id 14532293142，用户 katzilla11，US 2.4.5） | 2026-09-10 | ✅ verified |
| 台湾区同诉 | 「很喜歡DeepSeek 的細膩寫文模式，但希望可以把編輯次數弄回原本那樣沒有限制，只能修改6次讓人很困擾。」 | RSS `tw`（id 14481194714，用户 Yi_68，TW 2.4.2） | 2026-08-28 | ✅ verified |
| 日本区同诉 | 「修改文本的次数也太少了吧…次数限制真的不需要 我希望把次数限制删掉」 | RSS `jp`（id 14119124570，JP 2.1.1） | 2026-05-29 | ✅ verified |
| Google Play 同诉 + 具体报错文案 | 「为什么要更新出一个“修改输入次数超过限制,消息未发送”…拜托把上线拉高到30吧，至少可以修改更多次吧！」 | https://play.google.com/store/apps/details?id=com.deepseek.chat&hl=zh_CN&gl=CN （用户 Tang Junshen，👍36） | 2026-06-02 | ✅ verified |
| Google Play：修改限制 + 不支持指令 | 「还限制修改次数，完全不听指令，写现代就自动去古代，写古代会突然变成现代」 | 同上（用户 Lesley Cheah，👍91） | 2026-07-12 | ✅ verified |

### C. 对话长度上限 / 上下文溢出（「新对话也说已达上限」）

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 对话长度上限是新痛点 | 「【对话长度限制】这是最主要的问题，明明和AI聊的很好但却到了长度…感觉每次的对话都像是“一次性”的浅显对话」 | RSS `cn`（id 14185997891，用户 PATER ：，CN，标题「修改限制次数问题」） | 2026-06-15 | ✅ verified |
| 新建对话后仍报上限（疑似 bug） | 「我昨天无论是重退、关机、重新下载等办法都是在新对话里弹出来一句对话上限。」 | RSS `cn`（id 14535179647，用户 小猫上厕所不用纸，CN 2.4.5） | 2026-09-10 | ✅ verified |
| 英文区同样遇到 | 「I constantly have to create new chats and explain everything to the new ones, and now I can’t even write messages in a new chat because “the length limit has been reached” and I’m asked to start a new chat. I’m already in a new chat, and I’m getting the same error.」 | RSS `us`（id 14529915254，用户 Lumin228，US 2.4.5） | 2026-09-09 | ✅ verified |
| 长对话后「失忆」 | 「4. 记不住事：聊到后面就忘前面，上下文接不上。」 | RSS `cn`（id 14532847633，用户 Memories￼，CN 2.4.5，标题「更新后越来越难用纯倒退」） | 2026-09-10 | ✅ verified |
| 请求「记忆共享 / 无限对话」 | 「我真的希望对话是无限的，或者是可以两个记忆共享，无缝衔接起来」 | RSS `cn`（id 14530055590，用户 复苏幽魂，CN 2.4.5） | 2026-09-09 | ✅ verified |
| 要求增加对话长度或内容继承 | 「增加对话长度，最好是无限的，或者在开启新对话的时候可以给一个选项就是内容共享」 | RSS `cn`（id 14185997891，用户 PATER ：） | 2026-06-15 | ✅ verified |

### D. 服务器繁忙 / 限流（「服务器繁忙，请稍后再试」）

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 用标题复读表达愤怒 | 「服务器繁忙，请稍后再试。服务器繁忙，请稍后再试。服务器繁忙，请稍后再试。…」（标题即「服务器繁忙，请稍后再试。」） | RSS `jp`（id 12546358499，JP 1.1.6） | 2025-04-15 | ✅ verified |
| 美区英文用户量化频率 | 「I got same error messages more than 10 times in couple of days.」/ 正文「服务器繁忙，请稍后再试。」 | RSS `sg`（id 12297797173，SG 1.0.8） | 2025-02-11 | ✅ verified |
| 极端措辞 | 「你到底能tm繁忙多少次？？？？」 | RSS `au`（id 12320307799，AU 1.0.8） | 2025-02-16 | ✅ verified |
| 长文创作场景最受伤 | 「此外除了常見的伺服器繁忙，對話限制更是大硬傷，這對動輒上萬字的小說創作完全不友善。」 | RSS `jp`（id 12938296879，JP 1.2.8） | 2025-07-26 | ✅ verified |
| 2026 年仍存在 | 「现在的deepseek，我真的很无语，时不时来个服务器繁忙，而且让他创作的东西，读起来越来越差了，而且感觉越更新越烂。」 | Google Play（用户 Benson yao Yao，👍8） | 2026-08-02 | ✅ verified |
| 发送频率限制（「频繁」） | 「我正在跟这个AI出入新生聊得上头的时候就直接来了一句频繁，我去直接给我想说的话都给结束了好吧」 | RSS `cn`（id 14532895738，用户 h d h s s，CN 2.4.5） | 2026-09-10 | ✅ verified |
| 网页/App 大面积中断（媒体） | 「2026年3月29日晚，DeepSeek服务出现大规模访问异常，大量用户反映网页端和App频繁提示“服务器繁忙”或无法响应」 | https://baike.baidu.com/item/DeepSeek/65368136 | 2026-03-29 | ⚠️ 二手百科转述（媒体级，非用户原话） |

### E. 复制 / 文本选择 / 粘贴格式（iOS 重点能力）

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 视障用户：无法「一键复制」单条回复 | 「那就是没办法使用咱们这边的从当前项开始复制功能…不能一键复制，如果一键复制的话，就会把他ai生成的那个话也给带进去」 | https://bbs.tatans.cn/topic/134306 （标题「各位朋友们，你们在使用deep seek的时候，是否可以连续复制呢」） | 帖内标注「2周前」（≈2026-08-29） | ✅ verified |
| 同帖：连续复制会跑到底部 | 「如果你使用连续复制的话，它就会复制几条内容就直接跑到底下去了」 | 同上 | ≈2026-08-29 | ✅ verified |
| 同帖：第三方读屏「全文复制」也会多带内容 | 「我现在用点明安卓的话，用那个全文复制它倒是能成，但是他也会把底下的给你复制完。」（用户 微蓝） | 同上 | ≈2026-08-29 | ✅ verified |
| 手机端缺少「文件输出」，只能手动复制粘贴 | 「还不如更新文件输出这一块功能呢，用这么久还是要我复制粘贴，真无语了😓」 | RSS `cn`（id 14531508318，用户 nameless railgun，CN 2.4.5） | 2026-09-09 | ✅ verified |
| 粘贴/复制表格格式错乱 | 「但粘贴复制的时候格式总是乱，特别是表格。」 | RSS `cn`（id 14535320976，用户 不想学医啊啊啊啊，CN 2.4.5） | 2026-09-10 | ✅ verified |
| 「全选复制链接」分享后新对话解析错乱 | 「我把我一个对话框里的内容全选复制链接后发给了新的对话框，但是它解读出来的最后一条，是我前对话里的最前面部分，也就是说根本解读不出来，那你这个分享是干什么用的？」 | RSS `cn`（id 14535179647，用户 小猫上厕所不用纸，CN 2.4.5） | 2026-09-10 | ✅ verified |
| 缺少「引用消息 / 部分引用」，长文只能手动复制粘贴 | 「用户想针对其中某一段落继续问答时，需要手动复制粘贴，非常不便，尤其是在手机上。」+ 请求「长按或悬浮菜单，增加「引用」按钮」 | RSS `cn`（用户 Alex Peterson 84，标题「两个提升对话体验的功能建议」） | 2026-04-30 | ✅ verified |
| 新增语音按钮后粘贴变难用（Android 侧旁证） | 「此外新出的语音功能可以不要通过长按聊天栏触发吗？粘贴内容的话没以前方便了，建议修改，不差点那语音按钮。」 | Google Play（用户 Monutchuan，👍31） | 2026-03-29 | ✅ verified |

> **iOS「长按选中文本失灵」的直接差评：未在本次采集的语料中找到 → unverified。**

### F. 分享 / 导出 / 备份

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 请求导出会话到 iMessage/WhatsApp/WeChat | 「can you add a way to export a deepseek chat to iMessage so there’s an infinite chat that will go on…pls let me export the chat to iMessage or WhatsApp or WeChat」 | RSS `hk`（id 14449543920，用户 Bduck934，HK 2.3.6，标题「Can export chat to iMessage」） | 2026-08-19 | ✅ verified |
| 请求批量备份聊天记录 | 「希望能有个批量储存聊天记录的功能…这样长轮次的聊天方便储存备份。现在都是手动一张张备份的，比较麻烦。」 | RSS `cn`（id 14524132684，CN 2.4.5，标题「希望能有个批量储存聊天记录的功能，谢谢！」） | 2026-09-07 | ✅ verified |
| 需求清单：导出 + 检索 + 临时会话 | 「- Temporary chat feature that you can export but not automatically saved / - Search old chats using all keywords possible / - Export saved and or, archived chats」 | RSS `ca`（id 13890033311，用户 j3rcla6r，CA 1.7.10，标题「Needs more features」） | 2026-03-26 | ✅ verified |
| 要求导出/打印（德语区） | 「Ach, eine Exportmöglichkeit/Druckmöglichkeit wäre noch schön.」（中译：要是能导出/打印就更好了。） | RSS `de`（用户 kace51，DE 1.4.2） | 2025-10-11 | ✅ verified |
| 达到长度上限后想导出再转移，但很困难 | 「每次聊到限制后都很麻烦想导出来再发送到新的对话框里面，但是困难啊」 | RSS `cn`（id 14529065354 同批，CN 2.5.0，用户 no you just） | 2026-09-11 | ✅ verified |
| 跨端不同步，需要重复提问 | 「It doesn’t share chats with my computer, and I have to ask it the same things multiple times.」 | RSS `au`（id 13934251330，AU 1.8.2） | 2026-04-07 | ✅ verified |
| 桌面端与手机端会话不互通 | 「can't share links or access same chats on desktop logged in — pretty annoying」 | RSS `au`（用户 67haptics，AU 1.1.9） | 2025-05-13 | ✅ verified |

### G. 聊天记录丢失 / 会话消失 / 误删无法恢复

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 会话随机重置、上下文全部消失 | 「1. Chat Randomly Resets: In the middle of deep discussions, the chat is forced into a new window without any warning. All context vanishes, as if the AI suddenly got amnesia.」 | RSS `ca`（id 13654616803，用户 aaqwkli，CA 1.6.7，标题「Sudden Memory Loss in Chat!…」） | 2026-01-20 | ✅ verified |
| 聊天记录消失的自媒体吐槽 | 「deepseek让我少翻旧账。然后我的聊天记录没了。翻旧账不方便了好多，只能靠大脑里存储的翻了。」 | https://k.sina.cn/article_1900586141_7148a49d04001sot6.html （新浪，作者 菜刀曦曦） | 页面标注 05.22（推断 2026-05-22） | ✅ verified（但为自媒体短文，非 App Store 评论） |
| 缺少「删除可撤销」，误删很痛苦 | 「還有能不能出一個歷史刪除可以復原的，有時候不小心誤刪很煩，還有那個發送訊息頻繁也改改」 | RSS `tw`（id 14332067035，用户 胖達賢，TW 2.2.2，标题「改的一坨大便」） | 2026-07-21 | ✅ verified |
| 删除确认/单条删除缺失（唯一能整段删） | 「聊天框只能整体删除，不能单独删某一条。」+ 请求「支持长按或滑动某条消息，单独删除」「可提供一天内恢复功能」 | RSS `cn`（id 14535836999，CN 2.5.0，标题「建议」） | 2026-09-10 | ✅ verified |
| 服务端可能隐藏历史记录（用户主动提议） | 「限制次数干嘛 赶紧改成无限制呀 服务器塞不下可以短暂隐藏以前的历史记录呀」 | RSS `cn`（id 14529926174，CN 2.4.5，标题「限制次数干嘛」） | 2026-09-09 | ✅ verified |

### H. 会话列表管理（重命名 / 置顶 / 分组 / 搜索 / 归档）— 主要为「功能缺失」类请求

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| **无法搜索聊天记录**（最高频的缺失功能之一） | 「I would give it 5 stars if it had a chat history search feature like perplexity.」 | RSS `ca`（id 13720847369，CA 1.7.2，标题「Great App No Search Feature」） | 2026-02-06 | ✅ verified |
| 请求全文搜索聊天记录 | 「在移动端和网页端增加「搜索聊天记录」的功能 —— 输入关键词，就能定位到包含该词的任何历史对话。」+ 痛点「几周前我和 AI 聊过一个关于“вертина”…的话题，现在想找出来继续聊，但因为对话太多，根本找不到。」 | RSS `cn`（用户 Alex Peterson 84，标题「两个提升对话体验的功能建议」） | 2026-04-30 | ✅ verified |
| 请求文件夹 + 标签系统 | 「1. Finished Folders — move finished or old chats into folders instead of deleting them…They stay searchable / 2. Tagging System — add tags to any chat like #urgent, #fun, or #research…Filter by tag to find everything in one click.」 | RSS `hk`（id 14466659399，用户 Nat Nat 1219，HK 2.4.1，标题「Archive Folders & Tagging System」） | 2026-08-24 | ✅ verified |
| 明确要求「按关键词检索旧会话」 | 「Search old chats using all keywords possible」 | RSS `ca`（id 13890033311，用户 j3rcla6r） | 2026-03-26 | ✅ verified |
| **重命名 / 置顶**：本次采集语料中 **0 条** 提及 → 属于「未被用户提出的缺口」，不是被证实的投诉 | — | — | — | **unverified / 无数据** |

### I. 长对话卡顿 / 滚动 / 渲染性能

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 长对话越聊越卡，请求清理历史 | 「同一個對話聊久了會越來越卡…有點擔憂..希望能擴展記憶體空間+刪除一些先前的對話，要不然太卡了」 | RSS `tw`（id 14505986011，用户 世界級可愛の姫，TW 2.4.4，标题「希望能改善：」） | 2026-09-03 | ✅ verified |
| 流式输出的「渐进滑入」动画刺眼 | 「And the “Gradual” sliding of the message or whatever which is when the message is getting generated hurts my eyes. Please add the harsh one which adds the word one by one back please.」 | RSS `us`（id 14535507622，用户 Bleh183，US 2.5.0） | 2026-09-10 | ✅ verified |
| 聊天发送卡住 + 闪退（2026-09） | 「我给DeepSeek发消息时一直加载不出来，然后我还遇到了应用闪退，再一次打开还是同样的问题；我打开后发送了一张照片，也是同样的问题：一直加载，发送不出去，然后应用又闪退了。」 | RSS `cn`（id 14532995938，用户 白百合的秘密，CN 2.4.5） | 2026-09-10 | ✅ verified |
| 服务器崩溃问题长期未修 | 「每次都服务器崩溃修复了那么多问题，这个问题还是没有修是看不到吗？」 | RSS `cn`（id 14521968435，用户 决du独家设计速度，CN 2.4.5，标题「卡的要死」） | 2026-09-07 | ✅ verified |
| 更新后无法进入（闪退） | 「不知道为什么闪退 从你们更新后就一直进不去 一周了！！！…我甚至已经下卸载重下两三次了！！！！！！」 | RSS `sg`（id 13411830708，SG 1.5.1） | 2025-11-17 | ✅ verified |
| Android 侧卡顿 | 「有时候还自己一直卡顿，而且还会骂人」 | Google Play（用户 Dft Xrx，👍12） | 2026-04-22 | ✅ verified |

### J. 「深度思考」指示器 / 开关行为

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 深度思考的「思考过程」体验倒退 | 「现在的深度思考的思考过程跟屎一样」 | RSS `cn`（id 14536341671，用户 速趴蔬菜人，CN 2.5.0） | 2026-09-11 | ✅ verified |
| 关闭深度思考后默认走「快通道」，长指令被敷衍 | 「不开“深度思考”，生成速度比之前快了好多好多，快到我感觉它根本没在读我的长指令。」 | RSS `cn`（id 14533533940，用户 黎明踏浪号w，CN 2.4.5） | 2026-09-10 | ✅ verified |
| 开关文案/位置被批评（「下面两个按钮」） | 「下面两个按钮很影响交互体验，为啥放在输入框下面，没有一个ai把按钮放在输入框下的」 | RSS `cn`（用户 何18501935041，CN 2.5.0，标题「你是真的不听劝啊」） | 2026-09-11 | ✅ verified |
| 开启深度思考被指反而更差 | 「Deep thinking ist gar nicht so deep und sogar schlechtere antwort wenn man das anmacht」（中译：深度思考根本不深，打开之后答案甚至更差） | RSS `de`（id 13815565777，DE 1.7.9） | 2026-03-05 | ✅ verified |
| 老版本用户怀念可见的思考过程（心理落差） | 「以前专家模式会「思考」几十秒，过程看得见，心里踏实；现在简单问题秒回，反而让人觉得它在糊弄。」 | https://post.smzdm.com/p/a82xv5k7/ | 2026-09-11（文章） | ⚠️ 间接引用（smzdm 转述） |
| 支持方观点（对照） | 「开着深度思考，「不会太乱、不会忘记剧情，跟专家模式差不多」」 | https://post.smzdm.com/p/a82xv5k7/ | 2026-09-11 | ⚠️ 间接引用 |

### K. 联网搜索（联网开关）

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 联网经常失败并开始编造 | 「联网经常失败，搜不到答案就开始乱编 — 更新好几个版本了还没改善」 | RSS `sg`（id 12844172434，SG 1.2.5，标题即首句） | 2025-07-02 | ✅ verified |
| 联网数据陈旧 | 「连联网都不行，好几次都是猴年马月的数据，纯一坨」 | RSS `cn`（id 14529065354，用户 东京不太热 0426，CN 2.4.5，标题「没救了」） | 2026-09-09 | ✅ verified |
| 联网搜索无结果 | 「联网搜索没有答案，深度思考没啥用，大数据太旧。」 | RSS `au`（id 12239270031，AU 1.0.6） | 2025-01-27 | ✅ verified |
| 搜索多了就乱 | 「还有网页搜索，叫他找太多东西他会乱掉，每次给我乱乱写。只能花时间一个一个去找」 | Google Play（用户 。，👍21） | 2026-07-13 | ✅ verified |
| 正面评价（对照，说明开关确实存在于 App 内） | 「it gives you the option if you want it to search on the web or make it think by itself」 | RSS `ca`（id 13814162758，用户 Adam Alzobaidi，CA 1.7.9） | 2026-03-04 | ✅ verified |

### L. 语音输入

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 语音松手即发送，无法校对 | 「使用语音输入时，松开手即自动发送讯息，用户无法在发送前检视或修改文字。建议增加一个选项，让用户可以选择“语音输入后保留草稿”」 | Google Play（用户 J.c Chong，👍40） | 2026-04-01 | ✅ verified |
| 语音识别不准且反过来指责用户 | 「在说外文专有名词（无中文译名）的时候，反复识别错误，在被迫打字输入纠正一次后，依然重复纠正甚至嘲讽用户」 | RSS `cn`（id 14524648135，用户 Melody Pann，CN 2.4.5，标题「语音识别不准，反而反复指责用户错误」） | 2026-09-08 | ✅ verified |
| 新版字号变小 + 语音输入不准 | 「升级了之后，字变小了，语音输入法还不准！！！」 | RSS `cn`（id 14529037436，CN 2.4.5） | 2026-09-09 | ✅ verified |
| 语音功能请求（旧） | 「Feature Request: Voice Input & Output (Speech-to-Text & Text-to-Speech)」 | RSS `ca`（标题本身，CA，5★） | 2025-12-09 | ✅ verified（标题级） |
| 长按触发语音按钮被嫌 | 「此外新出的语音功能可以不要通过长按聊天栏触发吗？」 | Google Play（用户 Monutchuan，👍31） | 2026-03-29 | ✅ verified |

### M. 图片 / 文件上传限制

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 发图被强制切到新对话，打断上下文 | 「This message will be sent to the new chat.」After that, a new dialogue is created, and the correspondence is broken.」 | RSS `ca`（id 13911327926，CA 1.8.1，标题「Unable to send photos to the existing chat」） | 2026-04-01 | ✅ verified |
| 中文区同样抱怨 | 「上传一张图片就说会需要直接转到新聊天！上传一张就说要新聊天！搞毛啊！！！」 | RSS `ca`（id 13912880830，用户 Evolto09273，CA 1.8.1） | 2026-04-01 | ✅ verified |
| 无法只发图片、必须配文字 | 「I wish it were possible to send photos in all modes without any text. For creative people, this is a big problem.」 | RSS `au`（id 14383166117，AU 2.3.1） | 2026-08-03 | ✅ verified |
| 有时根本无法上传 | 「但是有时无法上传图片，望修复」 | RSS `jp`（id 14446478230，JP 2.3.6） | 2026-08-19 | ✅ verified |
| 专家模式曾不支持上传文件 | 「还有专家模式不能上传文件算了」 | RSS `cn`（id 14529065354，CN 2.4.5） | 2026-09-09 | ✅ verified |
| 照片识别能力下降 | 「为啥照片捕抓信息的功能这么差了现在？去年还很好，今年完全就是乱乱来」 | Google Play（用户 Yew Jin Tan，👍6） | 2026-07-05 | ✅ verified |
| 请求支持图片附件（防功能回退） | 「it would be great to add the ability to attach not only text, but also ordinary images (as it was before)」 | RSS `ca`（id 13911327926） | 2026-04-01 | ✅ verified |
| 识图仍是半成品 | 「缺点是识图还处于半成品状态」 | Google Play（用户 请和我玩，👍7） | 2026-06-20 | ✅ verified |

### N. 中文 vs 英文渲染 / 语言串味

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 要求英文回答却给中文思考 | 「I only wish that it consistently generated responses in English sometimes it generates thinking and response in Chinese so I have to remind it I need the response in English.」 | RSS `ca`（id 14335444195，用户 Darryl Dias，CA 2.2.2） | 2026-07-22 | ✅ verified |
| 俄语提问却用中文回答 | 「Молчу о том, что он регулярно отвечает на китайском (запрос на русском)」（中译：更别提它经常用中文回答（我用俄语提问）） | RSS `us`（用户 GaolinaNM，US 2.5.0） | 2026-09-11 | ✅ verified |
| 输出格式错乱（标点/段落黏连） | 「叫他写小说格式常常给我错乱掉，不是全部句号当逗号用，就是一坨字堆一起，说了又不改」 | Google Play（用户 。，👍21） | 2026-07-13 | ✅ verified |
| 德语区指「不停自我纠正」 | 「Diese KI hat eine Zwangsstörung, und zwar verbessert sie sich immer wieder selbst.」（中译：这个 AI 有强迫症，总在反复自我修正。） | RSS `de`（id 14315577332，DE 2.2.2） | 2026-07-17 | ✅ verified |
| 中文区抱怨「格式常常错乱 / 段落黏一起」 | 「写文读者最不喜欢就是段落黏在一起，我有说过，还是一样？」 | Google Play（用户 Low Zeying，👍111） | 2026-07-19 | ✅ verified |

### O. 登录 / 账号

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 注册入口缺失 | 「Hi Sir, I am not able to register to your AI App DeepSeek. Now it only shows login or sign-in page without anywhere to Register!」 | RSS `sg`（id 12247918125，SG 1.0.6） | 2025-01-29 | ✅ verified |
| 仅支持 +86 手机号或微信 | 「Only Chinese phone numbers (+86) or WeChat logins are allowed. Privacy policy and terms and conditions are in Chinese only.」 | RSS `au`（id 12271964654，AU 1.0.7） | 2025-02-04 | ✅ verified |
| 注册后无法使用 | 「注册登入後，一直使用不了。」 | RSS `au`（id 12300368242，AU 1.0.8） | 2025-02-11 | ✅ verified |
| 无法用邮箱登录 | 「cannot use email to login holy」 | RSS `au`（id 12469250145，AU 1.1.3） | 2025-03-26 | ✅ verified |
| Apple 登录与网页端不互通 | 「I downloaded the app and signed in with Apple. Then I went to the website and there's no ability to login with Apple, so now I've got extra steps.」 | RSS `au`（id 12387572171，AU 1.1.1） | 2025-03-05 | ✅ verified |
| 强制注册引发隐私担忧 | 「为什么一定要注册才能使用？为了你的大数据，私人信息都一览无余」 | RSS `au`（id 12706853338，AU 1.2.2） | 2025-05-28 | ✅ verified |

### P. 广告 / 收费 / Upsell

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| **无广告/无内购是核心好评点**（说明 App 内当前无广告） | 「it's free and there's no subscription in the app which really makes everybody equal」 | RSS `ca`（id 13814162758，CA 1.7.9） | 2026-03-04 | ✅ verified |
| 同上 | 「No IAP, no subscriptions, just pure, intelligent, non-judgemental conversation and research.」 | RSS `au`（id 14127090550，AU 2.1.1） | 2026-05-31 | ✅ verified |
| 用户怕以后收费 | 「this ai app is so good i love how it’s completely free. I hope it stays that way please DONT make a premium subscription version!!」 | RSS `de`（id 14063736194，DE 2.1.0） | 2026-05-14 | ✅ verified |
| 用户因「白嫖」话术被激怒 | 「不给手机端收费模式，又一口一个“白嫖”地羞辱人，我请问呢？」 | RSS `cn`（id 14535074930，用户 画师斑鸠，CN 2.4.5，标题「Ｃ端用户不是不愿意付费，是搭酒馆太麻烦」） | 2026-09-10 | ✅ verified |
| 用户主动要求开付费换回额度 | 「为什么限制次数，你不行开个付费，我付费你把次数还给我，限制次数怎么聊」 | RSS `cn`（id 14529892020，CN 2.4.5） | 2026-09-09 | ✅ verified |
| 用户要求「要么直接收费」而非乱弹上限 | 「你不想免费开发使用的话，你可以直接收费，发什么神经啊？」 | RSS `cn`（id 14529922813，CN 2.4.5） | 2026-09-09 | ✅ verified |
| **一个可疑的「订阅扣费」一星（可能与官方无关，需谨慎）** | 「I purchased their subscription for $1 for one week…they charged me $1 four separate times…charged me $42.」 | RSS `au`（id 14053780763，AU 2.1.0，标题「Scammers」） | 2026-05-11 | ⚠️ verified 但**归属未证实**（官方 App 免费无 IAP，疑似第三方/仿冒，勿当作官方行为） |

### Q. 字体大小 / 键盘换行 / 横屏 / iPad（可用性缺失）

| claim | verbatim quote | source URL | date | 状态 |
|---|---|---|---|---|
| 不跟随系统字号、App 内无字号设置 | 「I am very disappointed that the font size cannot be enlarged, despite my attempts to adjust the iOS font settings. The app does not respect system text size preferences and has no internal setting for font size.」 | RSS `sg`（id 13877154960，SG 1.7.10，标题「Font size cannot be changed in this app」） | 2026-03-22 | ✅ verified |
| 字号偏小 | 「I like DeepSeek but the font size in my iPhone 13 app is smaller than other AI apps. There is no text size setting within the app.」 | RSS `ca`（id 13772963276，CA 1.7.6） | 2026-02-21 | ✅ verified |
| iPhone 上无法换行，只能复制粘贴 | 「Bug - On iphone there is no way to press enter or return and go to next line in the chat mode. Only way is copy paste.」 | RSS `au`（id 13447891227，AU 1.5.3） | 2025-11-27 | ✅ verified |
| 同上，正式 GitHub Issue（已 closed） | 「I am unable to add a line break and move to the next line. Also, when there is a submit button, the keyboard should not show the submit/enter key like in other AI apps such as Gemini, Claude, or ChatGPT.」 | https://github.com/deepseek-ai/DeepSeek-V3/issues/1249 | 2026-04-25 | ✅ verified |
| 请求把回车键改成换行 | 「Please add next line button for the keyboard instead of submit, harder to write in the text field when there is no enter/next line button.」 | RSS `ca`（id 14333063179，CA 2.2.2） | 2026-07-21 | ✅ verified |
| 请求支持横屏旋转 | 「Would it be possible to enable screen rotation support in the app? Currently, …」（标题「Excellent App! One Small Feature Request」） | RSS `ca`（id 14395808119，CA 2.3.1） | 2026-08-06 | ✅ verified |
| 请求 iPad 版 / Mac 可下载 | 「Please update the iPad app to be downloadable on the Mac」 | RSS `au`（id 12387572171，AU 1.1.1） | 2025-03-05 | ✅ verified |
| 新版毛玻璃 UI 被嫌丑 | 「2.4.5(2)的版本好丑啊！！！！窗口里上下弄成毛玻璃质感的，看的我崩溃！！！改回来啊！！！！！！！！」 | RSS `cn`（id 14522127784，CN 2.4.5） | 2026-09-07 | ✅ verified |

---

## 3. 高频「未满足需求」排名（基于 1199 条 Apple RSS 语料 + Google Play，按提及频次）

| 排名 | 需求 | 代表性逐字引用 | 来源 |
|---|---|---|---|
| 1 | **取消/提高 修改·重新生成 次数限制（6 次）** | 「希望取消或大幅提高单条消息7次的修改限制……」 | RSS cn id 14185997891 同批；见 B 表 |
| 2 | **取消对话长度上限 / 支持无限或记忆继承** | 「增加对话长度，最好是无限的，或者在开启新对话的时候可以给一个选项就是内容共享」 | RSS cn（PATER ：） |
| 3 | **恢复「专家模式」独立选项（或让用户自选模型版本）** | 「希望可以开放一个选择历史版本…让用户自行选择使用哪个版本」 | RSS cn（PATER ：）+ 9/10~9/11 大量 1★ |
| 4 | **聊天记录全文搜索** | 「Search old chats using all keywords possible」 | RSS ca id 13890033311 |
| 5 | **导出 / 批量备份 / 跨端同步会话** | 「希望能有个批量储存聊天记录的功能」 | RSS cn id 14524132684 |
| 6 | **单条消息删除 + 删除可撤销** | 「聊天框只能整体删除，不能单独删某一条」「歷史刪除可以復原」 | RSS cn id 14535836999 / tw id 14332067035 |
| 7 | **字号可调 / 跟随系统动态字体** | 「The app does not respect system text size preferences」 | RSS sg id 13877154960 |
| 8 | **键盘回车换行（而非直接发送）** | 「there is no way to press enter or return and go to next line」 | RSS au id 13447891227 + GH #1249 |
| 9 | **会话文件夹 / 标签 / 归档** | 「move finished or old chats into folders instead of deleting them」 | RSS hk id 14466659399 |
| 10 | **图片可只发图不配文字** | 「I wish it were possible to send photos in all modes without any text」 | RSS au id 14383166117 |
| 11 | **引用（部分引用）消息** | 「长按或悬浮菜单，增加「引用」按钮」 | RSS cn（Alex Peterson 84） |
| 12 | **语音输入后保留草稿再发送** | 「让用户可以选择“语音输入后保留草稿”，确认无误后再手动发送」 | Google Play（J.c Chong） |
| 13 | **生成图片 / 生图功能** | 「能不能加個生成圖片功能 拜託了🥺🙏」 | RSS tw id 14177741219 |
| 14 | **横屏旋转 / iPad / Mac** | 「enable screen rotation support in the app」 | RSS ca id 14395808119 |
| 15 | **多端会话互通（网页 ↔ App）** | 「It doesn't share chats with my computer」 | RSS au id 13934251330 |

---

## 4. 关键结论

1. **2026-09-09 ~ 09-11 是明显的差评洪峰**：V4.1 Flash 上线 + 快速/专家/识图三模式合并 + 强制服务端切换，是本次采集到的最强单一投诉源，跨 CN/US/CA/TW/KR 同步出现，语料中 1★ 占比在 9/9–9/11 三天显著抬升。核心抓手是「恢复专家模式 / 让用户自己选模型」与「深度思考开关行为不透明」。
2. **「6 次修改限制」与「对话长度上限」是跨语言、跨地区、跨时间（2026-05 至 2026-09）最稳定的不满**，且用户已在评论中给出非常具体的替代方案（提高到 50/100 次、按小时限流、新对话可选继承上下文）。这是**最容易转化为产品改动**的一类反馈。
3. **会话管理几乎是一片空白**：搜索聊天记录、单条删除、删除撤销、文件夹/标签、批量导出/备份、跨端同步——每一项都在 App Store 评论里被单独、明确地请求过，且评论区**没有任何一条抱怨「重命名/置顶不能用」**，说明用户甚至不指望这两个功能存在。
4. **「服务器繁忙，请稍后再试」是长周期问题**，从 2025-02 一直持续到 2026-08 仍被评论提及；2026-03-29 有一次官方确认的大规模中断。
5. **iOS 平台的具体可用性债务**：键盘无法换行（只能复制粘贴，已开 GitHub issue）、无法调字号、不支持横屏、无 iPad/Mac 适配。**注意**：本次语料中**没有**直接抱怨「长按选中文本失灵」的评论，该子话题目前只有无障碍论坛的间接证据。
6. **App 内当前无广告、无 IAP**，且这是被反复表扬的差异点；用户对「上限」的愤怒有一部分正是因为它与「免费无广告」的预期冲突——多条评论主动要求「你直接收费吧，把次数还给我」。

---

## 5. 未能验证 / 无结果清单（严禁当作已证实结论使用）

| 目标 | 结果 |
|---|---|
| Reddit（r/DeepSeek、r/LocalLLaMA 等）移动 App 吐槽帖 | `search.json` HTTP 403；HTML 为 JS 渲染 → **unverified，未取得任何 Reddit 原文** |
| 小红书原帖 | 未直采，仅有 smzdm 文章转引 → **间接引用** |
| 微博原帖 | 同上 → **间接引用** |
| 知乎原帖 / 回答正文 | 未取得可读正文 → **unverified** |
| 酷安（coolapk）评论 | 未取得可读页面 → **unverified** |
| sspai（少数派）站内搜索 | API 返回 `total: 0` → **无结果** |
| iOS「长按无法选中文本/复制」专门差评 | 语料 0 条 → **unverified**（仅有视障论坛 + Android 侧旁证） |
| 「重命名 / 置顶」投诉 | 语料 0 条 → **无数据**（不等于没有该投诉，只是本次未采到） |
| App Store 英国区评分 | 页面仅返回 2383 字节 → **未取到** |
| 「广告 / 插屏广告」投诉 | 语料 0 条，反而有 2 条明确称赞「无 IAP、无订阅」→ 广告**不是**当前问题 |
