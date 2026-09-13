# DeepSeek 官方 App（iOS/Android，App Store id 6737597349）主源核查报告

抓取日：2026-09-12（报告内所有"抓取日"均指该日）。严格区分 VERIFIED（官方域名 / 官方商店 API / 官方 CDN 政策页）与 CLAIMED-BY-THIRD-PARTY。未在任何官方页面出现的说法标注"官方未说明"。

---

## 0. 关键结论

**官方帮助中心（FAQ）只有 4 个分类、45 个问答，且完全没有"联网搜索 / 深度思考 / 文件上传限制 / 语音输入"专题。** 官方 FAQ 分类：登录问题(9)、使用引导(10)、对话问题(10)、API相关(16)。因此：

- 「联网搜索」的官方定义只有《用户协议》一处；
- 「深度思考」在官方域名没有任何 App 侧定义，只有 API 文档的"思考模式"；
- 文件上传的格式/数量/单文件 MB 上限：**官方未说明**；
- 语音输入存在（权限+隐私政策），语音**对话/语音通话**：**官方未说明**（仅媒体称灰度）。

官方 FAQ 的内容不在 HTML 中：`https://static.deepseek.com/faq/index.html` 是 562 字节空壳，正文以 `JSON.parse('...')` 的 mdast 载荷内嵌在主 JS chunk 里（chunk 文件名带内容哈希）。当前 chunk：`https://static.deepseek.com/faq/static/main.d7e066fb1b.js`（抓取日）。

---

## 1. 输入模态

| 模态 | 官方依据 | 日期 | 置信度 |
|---|---|---|---|
| 文本 | 用户协议 1.2 https://cdn.deepseek.com/policies/zh-CN/deepseek-terms-of-use.html | 生效 2025-09-05 | 高 |
| 图片 | 同上 1.2「文本、图片、文件等」；隐私政策 https://cdn.deepseek.com/policies/zh-CN/deepseek-privacy-policy.html 「上传图片→相册权限」 | 2026-02-10 | 高 |
| 文件（存在，无任何限额说明） | 用户协议 1.2；个人信息收集清单 https://cdn.deepseek.com/policies/zh-CN/collected-personal-information.html 「输入内容（包括文本、图片、文件、语音）」 | 2025-12-22 | 高（仅"存在"） |
| 语音输入（ASR 式） | 权限说明 https://cdn.deepseek.com/policies/zh-CN/app-permissions.html ：RECORD_AUDIO / NSMicrophoneUsageDescription「用于帮助您完成**语音输入**」 | 修订 2026-04-27 | 高 |
| 拍照/相机 | 同上：CAMERA / NSCameraUsageDescription「拍摄及发送图片」 | 2026-04-27 | 高 |
| 语音对话（双向、TTS、音色） | 无官方页面 | — | **官方未说明** |
| 视频输入 | 无官方页面（权限文案提"拍摄照片和视频"） | — | **官方未说明** |
| 扩展名 / 单文件 MB / 文件数上限 | 无官方页面 | — | **官方未说明** |

### 官方 FAQ 中与上传相关的两条原文（分类 3「对话问题」）
- 「为什么图片上传失败」：图片格式暂不支持 / **系统未从图片中检测到可提取的文字** / 图片大小超过允许的上传限制 / 内容不符合平台使用规范。
- 「选择文件上传后无任何响应」：检查公司或学校内部网络是否限制文件上传功能。

URL：https://static.deepseek.com/faq/index.html?lang=zh#/category/3

### App Store 官方更新日志（App 内功能的时间线，一手）
来源：Apple 官方查询 API https://itunes.apple.com/lookup?id=6737597349&country=cn （抓取日）

| 版本 | 日期 | 要点 |
|---|---|---|
| 2.2.0 | 2026-06-29 | 支持识图模式 |
| 2.1.2 | 2026-06-02 | 支持表格复制、下载及全屏预览 |
| 2.1.1 | 2026-05-21 | 支持搜索历史对话 |
| 2.1.4 | 2026-06-03 | 支持调整字号大小 |
| 2.3.0 | 2026-07-28 | 支持识图模式 |
| 2.3.1 | 2026-07-30 | 优化图片和文件上传体验 |
| 2.3.2 | 2026-08-07 | 优化图片和文件上传体验 |
| 2.5.0（美区） | 2026-09-11 | 快速、专家、识图模式合并升级；思考过程自动折叠 |
| 2.5.1（中区） | 2026-09-12 | 同上 |

其它元数据：releaseDate 2025-01-10；currentVersionReleaseDate 2026-09-12T08:22:12Z；60.2MB；iOS 15.0+；bundleId `com.deepseek.chat`；开发者 杭州深度求索人工智能基础技术研究有限公司。
App Store 隐私（开发者自行申报，与该 app 本体关联的数据）：用户内容→**照片或视频、音频数据**、搜索历史记录、标识符、使用数据、诊断。

### 第三方声称（不可当官方）
- 最多 50 个文件、每个 100MB、支持各类文档和图片、**仅 OCR 识别文字**：
  - https://www.ithome.com/0/937/349.htm （2026-04-09）
  - https://digital.it168.com/a2026/0409/6923/000006923558.shtml （2026-04-09）
- 2026-05 专家模式关闭文件上传，官方提示"资源紧张，不支持文件上传"；快速模式仍可传文件与图片：
  - https://www.chinaz.com/2026/0514/1752236.shtml （2026-05-14）
  - https://m.ithome.com/html/950419.htm
- App 灰度测试语音对话（右上角小喇叭、4 种海洋音色）：https://www.sohu.com/a/1075110172_122014422 （2026-09-12）

---

## 2. 联网搜索 / 深度思考

### 联网搜索（VERIFIED，唯一定义）
用户协议 1.2（https://cdn.deepseek.com/policies/zh-CN/deepseek-terms-of-use.html ，2025-09-05）：

> 特别的，我们提供了"联网搜索"功能，开启该功能后，产品将按照输入信息和指令先检索互联网的公开信息，并根据检索的公开信息生成内容。

用户协议 5.2：打开"联网搜索"**或将**在一定程度上提升输出的准确性和时效性，但模型生成内容可能不准确无法完全避免。

→ 是否自动开启、使用哪个模型：**官方未说明**（1.3 条仅称"可能针对新增服务功能开展内部或外部测试"）。

### 深度思考
- 官方域名无功能定义。相关的一手材料只有：
  - 首页口号「深度思考 智能搜索」：https://www.deepseek.com/
  - API 侧「思考模式」：https://api-docs.deepseek.com/zh-cn/guides/thinking_mode
- API 事实（可参照，非 App 承诺）：deepseek-flash 与 deepseek-v4-pro「支持非思考与思考模式（**默认**）」→ https://api-docs.deepseek.com/zh-cn/quick_start/pricing
- App 端模式分层（媒体转述官方 UI 文案，2026-04-08）：快速模式=日常对话、即时响应、支持图片和文件中文字识别；专家模式=擅长复杂问题、支持**深度思考和智能搜索**，并提醒高峰需等待 → https://www.ithome.com/0/936/763.htm

---

## 3. 对话历史 / 删除 / 多端同步 / 账号

来源：官方 FAQ（抓取日）与隐私政策、注销须知。

- 重命名 / 置顶 / 删除 / 分享：网页端「…」菜单；APP 端**长按**对话 → https://static.deepseek.com/faq/index.html?lang=zh#/category/2
- 删除不可恢复：「已删除的对话无法恢复」「账号注销后…所有对话记录将被永久清空」→ 同上；https://cdn.deepseek.com/policies/zh-CN/deepseek-account-deletion-notice.html
- 导出：隐私政策 2.2 路径「头像 → 设置 → 数据管理 → 导出所有历史对话」；官方 FAQ 补充：**仅网页端**可导出，下载链接**有效期 7 天**，文件含账号信息与全部历史对话
- 多端同步：官方 FAQ 承认会出现不同步，给出手动刷新法（网页端刷新页面 / APP 端下拉刷新历史对话侧边栏）→ 分类 3。即多端同步是预期能力，但同步机制、延迟、范围**官方未说明**
- 分支：点击对话（提问或回答）下方数字箭头切换分支 → 分类 3
- 长上下文建议换端：「若当前对话上下文较长，建议尝试切换到网页端或性能更强的设备查看」→ 分类 3（官方暗示 App 与网页端不完全等同）
- 登录方式（官方 FAQ 分类 1）：手机号+验证码；密码登录（含忘记密码重置）；**微信登录**（海外 IP 不支持）；**Google 登录**（大陆 IP 不支持）；注册邮箱建议 Gmail/Outlook/Hotmail/Yahoo（部分域名不支持）；**换绑邮箱暂不支持**；「登出所有设备」
- 第三方账号登录的一手依据（隐私政策）：「您可以使用第三方账号登录…获取您在第三方平台注册的公开信息（头像、昵称…）」；另有「一键登录」
- 数据安全：境内存储、目前不外传；对话记录保留"以向您展示对话历史"；可通过「数据用于优化体验」关闭训练用途（隐私政策 2.2b、用户协议 4.3）

---

## 4. "服务器繁忙" / 容量 / 限速 / 官方建议

**API 侧（VERIFIED）** → https://api-docs.deepseek.com/zh-cn/quick_start/error_codes
- `500 服务器故障` → 请等待后重试；若一直存在请联系我们
- `503 服务器繁忙`（服务器负载过高）→ **请稍后重试您的请求**
- `429 请求速率达到上限` → 请合理规划您的请求速率

**并发与扩容（仅 API）** → https://api-docs.deepseek.com/zh-cn/quick_start/rate_limit
- 并发限制：deepseek-flash **2500**、deepseek-v4-pro **500**；按账号粒度；超限返回 HTTP 429
- 可提交「账号扩容申请工单」，扩容不增加额外费用

**峰谷定价（仅 API）** → https://api-docs.deepseek.com/zh-cn/quick_start/pricing
- 高峰时段=北京时间周一至周五 9:00-12:00、14:00-18:00；其余为空闲时段，闲时价为高峰一半
- 2026-09-10 12:00 新价生效（见 https://api-docs.deepseek.com/zh-cn/updates ）

**请求保活**：10 分钟后仍未开始推理，服务器关闭连接（rate_limit 页 / API FAQ）。

**App / 网页端用户**：官方**未说明**任何免费用户速率、次数或时长上限，也**未说明**"服务器繁忙"的官方 workaround。唯一间接官方口径是用户协议 8.2：「不保证本服务…不会中断、没有错误、不受干扰、持续稳定或不存在任何故障」。
官方服务状态页：https://status.deepseek.com/ （无公开 JSON API）。
第三方转述的 App 内官方文案：「专家模式…如遇高峰需等待」（2026-04-08）、「资源紧张，不支持文件上传」（2026-05-14）。

---

## 5. 回答长度 / 上下文 / App 与网页端差异

- 官方 API 文档：上下文长度 **1M**；输出长度**最大 384K**（deepseek-flash 与 deepseek-v4-pro 相同）→ https://api-docs.deepseek.com/zh-cn/quick_start/pricing
- 官方更新日志：2026-04-24 DeepSeek-V4「百万上下文」；2026-09-10 V4.1-Flash 发布（原生多模态视觉理解，模型名 `deepseek-flash`）→ https://api-docs.deepseek.com/zh-cn/updates
- 2026-08-13 更新日志：「DeepSeek-V4-Pro 正式版已同步在 **APP、网页端**和 API 更新上线」→ App 与网页端同档
- **App 自身上下文/输出上限：官方未说明**；App 与网页端是否不同：官方未说明（仅有 FAQ 的端间不同步、长上下文建议换端两条间接证据）
- 网页端/APP 端「提问次数/修改次数」限制：仅见于 App Store 用户评论，**非官方文档**

---

## 6. 社区镜像对比

镜像：https://github.com/thevibeworks/deepseek-docs/tree/main/content/zh-cn/faq （`fetched: 2026-08-05`）
树：https://api.github.com/repos/thevibeworks/deepseek-docs/git/trees/main?recursive=1

与官方当前 bundle（抓取日）对比：分类数与标题**完全一致**；个别问答正文有增量（category-1 首条多出"停机/骚扰拦截/重启手机"排查项；category-4 官方现有 16 问、镜像 15 问，官方新增"企业实名账号如何更新认证名？"）。→ 镜像可用，但**镜像日期不等于官方日期**。
镜像仓库 `sources.json`（updated 2026-08-02）明确注明「www.deepseek.com 不在镜像范围」，故 App 端特性只能依赖官方政策页 + App Store 元数据。

---

## 7. 证据表（claim | URL | 日期 | 置信度）

| 断言 | URL | 日期 | 置信度 |
|---|---|---|---|
| App 当前版 2.5.1；快速/专家/识图三模式合并升级；思考过程自动折叠 | https://itunes.apple.com/lookup?id=6737597349&country=cn | 2026-09-12 | 高（Apple 官方 API） |
| 支持识图模式 | 同上（2.2.0 / 2.3.0 更新日志） | 2026-06-29 / 2026-07-28 | 高 |
| 文件上传存在于 App（"优化图片和文件上传体验"） | 同上（2.3.1 / 2.3.2） | 2026-07-30 / 2026-08-07 | 高 |
| 输入含 文本、图片、文件、语音 | https://cdn.deepseek.com/policies/zh-CN/deepseek-terms-of-use.html | 2025-09-05 | 高 |
| 语音输入 / 拍照 / 相册为官方声明功能与权限 | https://cdn.deepseek.com/policies/zh-CN/app-permissions.html | 2026-04-27 | 高 |
| 联网搜索官方定义（先检索互联网公开信息再生成） | 用户协议 1.2 同上 | 2025-09-05 | 高 |
| 联网搜索仅"或将"提升准确性与时效性 | 用户协议 5.2 同上 | 2025-09-05 | 高 |
| 深度思考（App 端定义/开关/自动开启/所用模型） | 无官方页面 | — | **官方未说明** |
| 文件上传格式/数量/MB 上限 | 无官方页面 | — | **官方未说明** |
| 官方 FAQ 仅 4 类 45 问，无搜索/思考/上传/语音专题 | https://static.deepseek.com/faq/index.html?lang=zh#/category/1 | 抓取日 | 高 |
| 删除对话不可恢复；注销清空对话 | FAQ 分类 2；https://cdn.deepseek.com/policies/zh-CN/deepseek-account-deletion-notice.html | 抓取日 | 高 |
| 仅网页端可导出全部历史对话；链接 7 天有效 | FAQ 分类 2 | 抓取日 | 高 |
| 多端同步异常需手动刷新 | FAQ 分类 3 | 抓取日 | 高 |
| 登录：手机号 / 密码 / 微信（海外 IP 不支持）/ Google（大陆 IP 不支持） | FAQ 分类 1 | 抓取日 | 高 |
| 500 请等待后重试；503 请稍后重试 | https://api-docs.deepseek.com/zh-cn/quick_start/error_codes | 抓取日 | 高 |
| API 并发 2500 / 500；超限 429；扩容工单不加价 | https://api-docs.deepseek.com/zh-cn/quick_start/rate_limit | 抓取日 | 高 |
| 峰谷时段与闲时半价（周一至五 9-12、14-18 为高峰） | https://api-docs.deepseek.com/zh-cn/quick_start/pricing | 抓取日（新价 2026-09-10 12:00 生效） | 高 |
| 上下文 1M / 输出最大 384K | 同上 | 抓取日 | 高（API；App 未说明） |
| App/网页端免费用户速率与次数上限、官方 workaround | 无官方页面 | — | **官方未说明** |
| 文件上传最多 50 个、每个 100MB、仅 OCR 识别文字 | https://www.ithome.com/0/937/349.htm | 2026-04-09 | 第三方（转述官方 UI 提示） |
| 专家模式支持深度思考与智能搜索、高峰需等待 | https://www.ithome.com/0/936/763.htm | 2026-04-08 | 第三方（转述官方 UI 提示） |
| 2026-05 专家模式文件上传关闭，提示"资源紧张" | https://www.chinaz.com/2026/0514/1752236.shtml | 2026-05-14 | 第三方 |
| App 灰度测试语音对话、4 种音色 | https://www.sohu.com/a/1075110172_122014422 | 2026-09-12 | 第三方（官方无公告） |

---

## 8. 仍缺一手证据的空白

1. App 内提示原文（"资源紧张""高峰需等待""仅识别文字"）只能真机截图取证，官方 Web 无对应页面。
2. 文件上传扩展名 / 大小 / 数量、App 上下文与输出上限：官方渠道全部缺失。
3. 语音输入 vs 语音对话的官方定性：建议核查 Google Play（`com.deepseek.chat`）描述或 APK 内 strings；`https://download.deepseek.com/` 仅为 JS 壳，只暴露 Google Play / iOS 入口，未提供可公开访问的直链。
