# Chatty for iPhone · 首版方案

日期：2026-09-05 · 状态：规划草案 · 尚未开始 iOS 实现或验收。

本次使用独立 `sdlc-plan`，产出范围、交互方案、技术建议和验收计划。现有 `.sdlc` 变更已关闭；本次沿用 `iterations/` 项目格式，不修改 Android 生命周期记录。

## 1. 先把问题说清楚

**你需要在离开电脑时，打开 iPhone 就能接续与 Mika 的工作：表达需求、看执行过程和结果、核对项目进度。** Multica 继续承担账号、会话、任务与 Runtime 执行；手机负责把这些信息清楚地呈现出来。

- 使用者：先按 Benjamin 个人使用规划，尚待确认是否首批就邀请 TestFlight 用户。
- 当前缺口：Chatty 已有 Android 原生客户端，仓库尚无 iOS 工程。
- 可观察结果：iPhone 登录后进入同一工作区的 Mika 会话，发送一次需求，看到对应任务和最终回复；关掉应用后再打开，重新读取服务端结果。
- 核心约束：延续「对话 / 项目 / 设置」；内部业务流程在原生页面完成；不增加第二套服务端状态。
- 范围假设：首版对齐当前 Android 核心功能，iPhone 优先，最低 iOS 26 暂定。语音、APNs 和更完整审批能力分别规划。

### 事实、建议与待确认

| 分类 | 当前结论 | 依据或影响 |
| --- | --- | --- |
| 已核实 | Chatty `main` 为 `3c003f9`，规划开始前工作区干净，只有 Android 源码 | 本轮本地检查；本次仅增加规划文档 |
| 已核实 | 最新导航为 Mika 单一对话、项目、设置，已取消 Multica 网页流程出口 | `iterations/v2/NAVIGATION.md` 优先于旧 Spec 的页面安排 |
| 已核实 | Android 支持真实历史读取；合成收发、项目管理和资源导航已有证据 | `CHAT_SOURCE_PARITY.md`、`EVAL.md` 后续增量章节；Android 全量 V2 仍未通过验收 |
| 已核实 | agent-device 0.20.10 已在 Pixel 上重放 11 步，含项目加载等待、页面断言及截图 | `.tools/agent-device-trial-20260905/replay-result.json`；这项结果只覆盖 Android |
| 已核实 | 本机 Xcode 26.6，可用 iOS 26.2 / 26.5 模拟器运行时 | 本轮 `xcodebuild -version` 与 `simctl list devices available`；没有启动模拟器 |
| 已核实 | 配对 iPhone 当前 unavailable；iPad mini available | 本轮 `devicectl list devices`；iPad 不能代替 iPhone 真机验收 |
| 已核实 | Multica 本地源码为 `1cc46b269`，已有独立 Expo / React Native 移动端 | 本轮检查 `apps/mobile/package.json`；可参考数据规则，不能视作现成 Chatty iOS |
| 设计建议 | SwiftUI 原生、iPhone 优先、iOS 26 起步 | 减少旧系统适配面；最低版本需结合目标 iPhone 确认 |
| 待确认 | 个人自用或首批 TestFlight、目标 iPhone / 系统、签名 Team | 不阻碍方案评审；分别影响发布工作、兼容范围和真机安装 |

## 2. 最小交付与首版范围

**先得到可用的 Mika 对话闭环，再补齐 Android 现有的项目与设置。** 两个交付点属于同一份首版计划。

| 能力 | 第一个可用交付 A | 首版完整交付 B |
| --- | --- | --- |
| 登录与工作区 | 邮箱验证码、Keychain、选择与恢复工作区、退出 | 切换工作区隔离、权限和异常完整回归 |
| Mika 对话 | 接续最近有效会话、文字发送、完整回复、历史分页 | 任务过程、失败详情、快捷建议、附件与 Markdown 格式对齐 |
| 实时与恢复 | 前台单 WebSocket，断线 REST 重取，回前台同步 | 重复/乱序事件、后台中断、冷启动和发送回执不明的完整验证 |
| 项目 | 不作为 A 的验收前提 | 完整项目统计、Issue 搜索/筛选/分页/详情、状态修改、未归属项目入口 |
| 设置 | 工作区与退出 | Runtimes、Agents、Squads 原生列表和详情 |
| 原生质量 | 系统键盘、基本深浅色、可访问性标识 | Dynamic Type、VoiceOver、Reduce Motion、键盘和小屏完整验收 |

### 后续增强

- 应用内长按转写：V1.1；首版文字输入可使用系统键盘提供的听写，不宣称已实现应用内语音功能。
- APNs 通知：单独的服务端与客户端联动任务；首版不依赖后台通知完成核心流程。
- 结构化审批、取消执行、排队消息、其他 Agent 直接对话、会话管理：确认接口和产品范围后再进入计划。
- iPad 多栏、Apple Watch、Widget、Live Activities、Siri / App Intents、Share Extension、公开 App Store 发布：后续独立范围。
- HTML / Mermaid 的执行式预览、任意网页嵌入、离线完整消息库、Runtime 远程控制和配置编辑：首版不提供入口。

## 3. 三个入口与关键交互

### 对话：继续和 Mika 工作

1. 登录后默认进入当前工作区的 Mika。
2. 按 `system_key = "mika"` 和实际权限定位 Agent，接续最近更新的有效会话。没有会话时，在首次发送时创建。
3. 顶部展示 Mika、连接/同步状态；主体展示用户消息、助手正文和关联任务过程。
4. 底部是附件入口、多行草稿和发送按钮。发送后以服务端 `message_id`、`task_id` 追踪结果。
5. 任务过程默认折叠；点开后查看步骤、工具结果、耗时与失败信息。最终回复保持完整文本，不制造逐 token 输出。
6. 快捷建议只填入草稿，用户再点发送。历史列表、新对话和其他 Agent 选择器不进入首版页面。

| 场景 | 用户看到什么 | 行为规则 |
| --- | --- | --- |
| 等待响应 | 正在提交，发送暂时不可用 | 同一会话只允许一个发送请求 |
| 服务端已接受 | 按 task_id 显示排队或执行状态 | 本地更新出错也不重新发送 |
| 请求超时，是否接受不明 | “发送结果待确认”，草稿保留，可先核对消息记录 | 不自动重发，不宣称服务端未收到，不用相同文字猜测唯一回执 |
| 断网 | 同次运行已加载内容仍可阅读，显示离线状态 | 前台恢复后重取；冷启动无网络时只展示草稿与明确空态 |
| Mika 无权限或不存在 | 说明当前工作区无法使用 Mika，提供切换工作区 | 不按显示名称猜 Agent，不绕过权限 |
| 回复为空或任务失败 | 明确的无回复/失败结果，可展开详情 | 不把无内容当成功回复 |

### 项目：先看全局，再处理一条 Issue

1. 首页显示项目名称、已完成/总数、进度，以及“未归属项目的 Issues”。计数取完整服务端统计。
2. 点击项目 push 到 Issue 列表；原生搜索框和状态筛选，50 条分页，保留当前位置。
3. 点 Issue push 到详情，进入时读取最新 revision。
4. 状态用原生选择器修改；提交显式携带 `suppress_run=true` 与可用的 `expected_revision`。
5. 提交期间禁用重复操作，成功后重取详情与项目统计；冲突时展示最新结果并让用户重新选择。
6. 页面说明“仅更新进度，不启动 Agent”；不给未实现的创建、分派、描述编辑提供空入口。

### 设置：工作区与协作资源

- 顶部工作区卡片：当前工作区、切换工作区；切换用原生 Sheet。
- “运行与协作”分组：Runtimes、Agents、Squads；列表 push 到原生详情，保留原生返回手势。
- 退出登录：清本机凭据、隔离草稿、临时附件与内存数据，取消旧请求和连接。
- 核心业务不跳转 Multica 网页；第三方资料链接可通过系统浏览入口查看，返回后保留阅读位置。

### 图片、文件与富文本

- 图片：应用内全屏预览、缩放、关闭后恢复对话位置。
- 文件：`PhotosPicker` / `fileImporter` 选择，上传成功后保留 attachment ID，发送回执校验实际绑定的附件。
- 文本与代码：原生阅读、复制；Markdown 至少覆盖标题、列表、引用、链接、代码、表格、删除线和任务列表。
- 普通文件：经授权下载到有保护的临时文件后交给 Quick Look；未知格式给出类型与可用操作。
- HTML / Mermaid：按源码或文本阅读；内部实体链接进入已实现的原生页面，缺少页面时保留文本。

## 4. iOS 视觉与触控规则

**保留 Chatty 的暖白、石墨、低饱和绿，让导航与交互遵循 iPhone 习惯。** HTML 中的屏幕是合成数据交互草图，最终外观以 SwiftUI 真机为准。

| 元素 | iOS 设计建议 |
| --- | --- |
| 导航 | 系统 `TabView` + 每 Tab 独立 `NavigationStack`；保持三个位置和返回路径 |
| 材质 | 使用系统导航、工具栏、Sheet 的 Liquid Glass；聊天正文和项目内容使用稳定、不透明表面 |
| 基础色 | 暖白 `#F6F7F4`、石墨 `#202521`、主色 `#365E50`；深色沿用 `#141815` / `#E5EAE2` / `#A9CDB8` |
| 字体 | 系统语义字号与 Dynamic Type；正文优先 17pt；代码用等宽字体 |
| 布局 | 页边距约 20pt；内容间距采用 8pt 基准；避免把 Android 的 dp/sp 数值直接搬成 pt |
| 触控 | 操作区至少 44×44pt；图标使用 SF Symbols 并配合可访问性文字 |
| 输入 | 按系统安全区布置 composer；只保留一套键盘避让，不重复计算底部间距 |
| 动效 | 状态和 Sheet 使用系统动效；遵循减少动态效果与降低透明度设置 |
| 长内容 | 不截断关键失败说明；表格和代码横向滚动；长消息阅读时不强制跳到底部 |

Apple 建议使用系统标准组件自动适配 Liquid Glass，并检查明暗、透明度与动态效果设置。[Apple：Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)

## 5. 技术路线与边界

### 推荐 SwiftUI 原生

| 路线 | 可以复用什么 | 主要代价 | 本次判断 |
| --- | --- | --- | --- |
| SwiftUI + Swift | 服务契约、设计语义、合成样本、验收场景 | 需要维护 Swift 的 DTO 和状态逻辑 | 推荐：符合现有原生方向，便于系统导航、键盘、文件和可访问性适配 |
| 基于 Multica Expo 客户端裁剪 | TypeScript 类型、部分数据逻辑和组件 | 需裁剪不同产品导航及状态层，持续承受上游变化；不能直接复用 Android Kotlin UI | 若目标改成最快交付跨平台客户端，可重新评估 |
| Kotlin Multiplatform | 未来可分享部分业务逻辑 | 当前 Retrofit、Hilt、Android 存储等需额外重构，扩大首版范围 | 暂不引入 |

**主要风险是两端业务规则分叉。** 解决办法是把发送回执、分页、权限、任务事件和 Issue 状态样本作为共同输入，要求 Kotlin 与 Swift 对相同样本给出一致结果。先复用契约与验证，再按需要提取共享代码。

### 拟议工程结构

以下路径与 scheme 均是计划，当前尚未创建：

```text
ios/
  Chatty.xcodeproj                 # 应用宿主与共享 scheme
  Chatty/                         # App、根导航、生命周期、环境注入
  Packages/ChattyKit/
    Sources/
      Domain/                     # Codable DTO、状态和纯转换规则
      Networking/                 # URLSession REST、WebSocket、附件策略
      Session/                    # Keychain、工作区、请求作用域
      Features/                   # Auth、Chat、Projects、Settings
      DesignSystem/               # 颜色角色、公共状态与原生组件包装
    Tests/                        # 契约、状态转换、并发与错误行为
  ChattyUITests/                  # XCTest 系统交互与生命周期补充
scripts/ios-env.sh                # 设备、scheme 与输出目录
scripts/ios-dev-loop.sh           # build → install → launch → inspect
iterations/ios-v1/flows/          # agent-device .ad 流程
iterations/ios-v1/evidence/       # 脱敏验收摘要与可提交证据
```

- 第一轮使用一个应用 target + 一个本地 Swift Package，以目录区分职责；出现真实依赖隔离需求后再拆 package。
- Swift Concurrency 管异步与取消；UI 状态在主线程，Session/连接所有者独立控制生命周期。
- 依赖通过构造器注入，首版不引入全局容器、复杂单向框架或 Core Data / SwiftData 消息库。
- Markdown 完整能力是单独的技术验证项；系统基础 Markdown 显示不能自动视为已满足表格等全部要求。第三方库需先验证格式、链接策略、可访问性与许可，再锁版本。

### 状态如何流动

```text
用户动作 → SwiftUI 页面 → Feature 状态与用例 → Multica REST
                                              ↓
                           message_id / task_id / revision
                                              ↓
前台 WebSocket → 作用域校验 → 对应数据失效 → REST 重取 → 页面更新
```

- 每个登录账号与工作区只有一套有效连接。切换工作区、退出、退后台都会取消旧监听与重连定时器。
- 每次作用域变更增加 generation；迟到的 HTTP、Socket、上传结果只能更新其所属账号与工作区。
- URLSession 使用禁用敏感响应磁盘缓存的配置；REST 明确控制重定向和凭据附加规则。
- 写请求默认不自动重试；只读请求才考虑有限退避。WebSocket 恢复后通过 REST 重取，不假定事件补发。

## 6. 沿用已有服务契约

| 入口 | 契约 | iOS 必须保持的规则 |
| --- | --- | --- |
| 登录 | `POST /auth/send-code`、`POST /auth/verify-code` | 验证码不存储；验证码请求和登录请求不自动重试 |
| 作用域 | `/api/workspaces`、`/api/me`、workspace members | `/api/` 使用 Bearer 与 `X-Workspace-Slug`；迟到的旧 401 不清新凭据 |
| Mika / 会话 | `/api/agents`、`/api/chat/sessions` | `system_key` + 权限；最近有效 Mika 会话；归档会话不作为发送目标 |
| 历史 | `/api/chat/sessions/{id}/messages/page` | `limit=50`，时间与 ID 双游标，按消息 ID 去重，向前加载保留滚动位置 |
| 发送 | `POST /api/chat/sessions/{id}/messages` | 使用回执 `message_id/task_id/attachment_ids`；用户发送一次只产生一次写请求 |
| 任务与过程 | `pending-task`、`/api/tasks/{id}/messages` | trace 按 seq 去重排序；文本/过程/最终回复按同一 task_id 关联 |
| 实时 | `GET /ws`，auth 首帧 → auth_ack | token 不放 URL；工作区与客户端参数参考现有协议；`client_os=ios`；认证超时和重连受生命周期控制 |
| 附件 | `upload-file`、attachments metadata/content/download | 刷新过期 metadata；只向 API 同源发凭据；外部签名下载不附带 Bearer；限制大小并清理临时文件 |
| 项目与 Issue | projects、issues、issue-statuses | 使用服务端统计和自定义状态；状态写入 suppress_run + revision；成功后刷新关联计数 |
| 协作资源 | runtimes、agents、squads | 保持服务端权限与归档过滤；离线 Runtime 不暗示自动迁移执行 |

### 本地数据规则

- Token：Keychain，暂定 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`，关闭跨设备同步。该保护等级适合首版前台访问；以后添加锁屏后台访问时需重新审查可访问等级。[Apple：Keychain 可访问性](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly)
- 本机允许保留：受保护、排除备份的草稿，最近工作区标识和少量偏好；服务器消息、任务和项目只保存在内存。
- 草稿按稳定账号 ID + workspace ID + session/agent ID 隔离；账号 ID 来自 `/api/me`。取不到账号 ID 时不加载其他账号草稿，不自动迁移 Android 草稿。
- 临时附件按账号作用域管理、文件保护、排除备份；退出立即清理，下载/启动时按明确 TTL 清理。首版测试需验证系统缓存和 Quick Look 相关残留。
- 用户日志记录请求类型、状态码与脱敏 ID，不记录 token、验证码、原始私密消息或完整签名 URL。

## 7. iOS 特有问题与取舍

### 后台：回到应用后收敛

- 进入后台：保存草稿，停止前台 Socket 与轮询；已在 Multica Runtime 执行的任务由服务端继续管理。
- 回到前台：立即触发一次去重的消息、pending-task 与当前页面数据重取，再恢复单连接。
- 发送途中退后台：可评估短时后台执行窗口；窗口耗尽时进入“结果待确认”，恢复后核对，不能自动重发。
- 首版不设计固定间隔后台轮询承诺。Apple 明确由系统决定 `BGAppRefreshTask` 的运行时机。[Apple：后台策略](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)

### 推送：需要服务端配合

- 在本轮检查的 Multica 本地 `1cc46b269` 后端 Go/SQL 源码中，没有发现 APNs、device-token 或 push-sender 实现；已有规格也将推送记为缺口。这不能证明线上部署的全部能力，开工前需向实际服务接口复核。
- 后续 APNs 需要设备 token 注册/解绑接口、服务端发送通道、权限、去重与原生跳转目标。仅添加客户端通知权限无法完成远程通知。[Apple：注册 APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
- 首版不出现无法兑现的通知设置；界面在必要位置说明“重新打开后同步最新进度”。

### 语音与审批：分别立项

- 应用内转写后续采用 Speech 框架候选方案，先核实目标机型、语言、`isAvailable`、`supportedLocales` 与已安装模型；不可用时保留文字输入。音频是否外发必须随实际转写引擎明确说明。[Apple：SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber)
- “需要你回复”只能基于已核实的任务受阻、Issue 状态和 Inbox 信号；打开预填草稿，用户决定发送。当前资料没有通用 approve/reject 契约，不增加虚构批准按钮。

## 8. 实施顺序与交付检查

这些是本地计划编号，尚未创建 Multica / Linear Issue。原 CLE 编号仅作为 Android 语义来源，不用来承载 iOS 实现。

| 计划项 | 工作与主要文件 | 依赖 | 完成后能检查什么 | 规模 |
| --- | --- | --- | --- | --- |
| IOS-P0 契约与测试底座 | 固化 DTO/事件样本；复用 auth-fixture.py、chat-fixture.py；建立 ChattyFixture 与 Chatty scheme；技术验证 Markdown | 目标系统建议 | 模拟器启动 fixture 包，读取页面快照；契约解析测试可运行 | 中 |
| IOS-P1 登录与导航 | Session、Keychain、Auth、三个 Tab、系统主题与标识 | P0 | 合成登录、错误验证码、401/503、冷启动与工作区隔离 | 中 |
| IOS-P2 Mika 最小闭环 | Chat 状态、历史分页、文字发送、pending、前台 Socket、恢复逻辑 | P1 | 合成两轮收发、单次写入、真实账号手动登录与读取；取得授权后验证明确内容的真实发送 | 大 |
| 交付 A | P0–P2 集成在 iPhone | P2、签名与可用 iPhone | 离开电脑后能继续一段 Mika 工作；保留失败与恢复证据 | 里程碑 |
| IOS-P3 内容与可靠性 | Markdown、任务过程、附件预览/上传、草稿、未知事件和取消清理 | P2 | 格式样本、回执不明、乱序、签名 URL 过期、后台中断与重启 | 大 |
| IOS-P4 项目与资源 | Projects、Issue 详情/状态写入、Settings、Runtimes/Agents/Squads | P1；集成在 P3 后 | 服务端计数、50→55 分页、自定义状态、revision 冲突、无 Agent 启动 | 大 |
| IOS-P5 iPhone 验收 | agent-device 流程、XCTest 补充、可访问性/键盘/深色、真实账号 E2E | P3、P4、可用 iPhone | 验收矩阵逐项带独立证据；交付 B 可日常试用 | 中 |

按 P0 → P1 → P2 → A → P3 → P4 → P5 推进，每轮有可运行结果。规模用于比较工作量，不代表工期承诺。首版发布范围若包含 TestFlight，在 P5 后增加签名归档、分发与隐私说明的独立检查项。

## 9. 验收矩阵

所有条目当前状态均为 **待实现 / 待验证**。下表描述目标，不表示已通过。

| ID | 场景与检查 | 通过条件 | 证据方式 |
| --- | --- | --- | --- |
| A01 | Fixture 与真实环境隔离 | 独立 bundle/config；fixture 不连接生产；Release 不允许宽泛 HTTP 例外 | 配置检查 + 网络请求记录 |
| A02 | 登录错误、401、403、503、迟到响应 | 凭据只按当前认证状态清理；网络/服务器错误保留登录；旧响应不污染新账号 | URLProtocol 契约测试 + 模拟器流程 |
| A03 | Mika、会话与权限 | system_key 稳定定位；最近有效会话；无权限和空工作区有明确页面 | 合成权限组合 + 真实只读核对 |
| A04 | 一次发送、未知回执 | 双击仅一个 POST；服务端已接受后不重发；超时保留草稿并提示核对 | 合成服务计数 + 模拟器操作 |
| A05 | 历史分页和重复时间戳 | 50 条边界及相同时间戳不漏不重；阅读位置保持；加载状态可访问 | JSON 样本 + 截图与断言 |
| A06 | task_id 与消息内容 | 过程按 seq 排序去重，最终回复正确关联；失败/无回复/未知事件不崩溃 | Kotlin/Swift 共同期望值 + UI |
| A07 | 断网、后台、冷启动、快速切换工作区 | 最多一个有效 Socket；恢复后数据收敛；无跨工作区消息/附件/草稿 | 可控时序测试 + iPhone 生命周期流程 |
| A08 | 原生富文本与附件 | 约定 Markdown 格式可读；图片关闭回原位置；过期链接可恢复；凭据不发给外域 | 样本集 + 本地 HTTP 检查 + 真机文件选择 |
| A09 | 项目统计、筛选、分页 | 完成数来自全项目统计；搜索/自定义状态/50→55/空列表/无项目入口正确 | 现有 chat fixture 场景 + agent-device |
| A10 | Issue 状态修改 | 一次 PUT，suppress_run=true，正确 revision；冲突不自动重发；完成数刷新 | fixture 写入计数与请求体 + UI |
| A11 | 原生资源导航 | Runtimes/Agents/Squads 数据正确，空态/无权限可用，返回路径完整 | 合成流程 + 真实只读核对 |
| A12 | 触控、键盘、可访问性 | 小屏、深浅色、两档大字号可用；VoiceOver 标签明确；键盘与输入区无重复留白或遮挡 | agent-device 截图 + XCTest/人工 VoiceOver |
| A13 | 存储与退出 | token/验证码不进入日志；草稿隔离；敏感缓存不落盘；退出后临时文件清理 | 文件/配置检查 + 重启与多账号流程 |
| A14 | iPhone 真实业务闭环 | 用户登录目标工作区；经明确消息授权后发一次、读到对应回复；后台返回和重启后与服务端一致 | 真机截图、脱敏回执、服务端事实对照 |

### agent-device 如何接进开发循环

1. 先构建和安装 ChattyFixture 到指定 iPhone 模拟器，发现并固定测试目标。
2. open → 读取可访问性树 → 按 ID/label 操作 → 等待明确内容 → 断言 → 截图 → close。
3. 控件约定标识：`auth.email`、`auth.code`、`chat.draft`、`chat.send`、`projects.list`、`issue.status`、`settings.workspaces`。具体 ID 在 P0 固化。
4. 将稳定流程保存为 `.ad`；网络完成用内容/状态条件等待，避免用固定 sleep 或页面静止代替数据就绪。
5. 每次变更先跑相关流程；发布候选再跑完整矩阵。模拟器通过后才开展 iPhone 签名安装与真实验证。
6. agent-device 物理 iPhone 路径需要配对、Developer Mode 和签名配置，当前尚未在 iPhone 上验证。系统弹窗、VoiceOver、后台时序由 XCTest/人工补足。
7. 合成数据与真实验证分开记录。原始私密截图/日志写入 `.tools/ios-v1/<run>/`，脱敏摘要写入 `iterations/ios-v1/evidence/`。

拟议命令形态如下，工程、scheme 与脚本建立后才能运行：

```bash
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture \
  -destination 'platform=iOS Simulator,id=<selected-simulator-udid>' test
scripts/ios-dev-loop.sh --fixture --device <selected-device-id>
agent-device replay iterations/ios-v1/flows/navigation.ad --platform ios
```

agent-device 官方 iPhone 前置条件：[Installation](https://oss.callstack.com/agent-device/docs/installation)。Android 的 5.4 秒重放结果不作为 iOS 性能目标。

## 10. 尚需确定的事项

| 事项 | 当前采用的建议 | 最晚何时确定 |
| --- | --- | --- |
| 首批使用对象 | Benjamin 自用、覆盖 Android 核心能力 | 进入实现前；若需 TestFlight，增加分发范围 |
| 最低 iOS / 目标设备 | iPhone 优先，iOS 26+ | P0；低版本需求会增加兼容与回归工作 |
| 实现路线 | SwiftUI 原生；本轮只形成建议 | P0 |
| Apple 签名 Team 与 bundle ID | 暂未选定，不复用已存在应用身份 | 真机安装前；不阻塞模拟器底座 |
| 真机连接 | 当前 iPhone unavailable，实施时重新连接检查 | 交付 A 的 iPhone 验收前 |
| 真实发送的测试内容 | 尚未授权任何新测试消息 | A14 执行前，与用户确定具体内容 |
| 远程推送是否升级为首版必需 | 当前放在后续，复核真实后端接口 | 若改为必需，首版必须加入服务端工作 |

## 11. 实施时要读的源码与依据

### Chatty 当前基线

- [导航与最新原生边界](../v2/NAVIGATION.md)
- [对话源码对齐清单](../v2/CHAT_SOURCE_PARITY.md)
- [Android 验证记录，含后续增量](../v2/EVAL.md)
- [现有颜色与布局语义](../../docs/android-visual-design.md)
- [认证与网络契约](../../android/core-network/src/main/java/ai/chatty/core/network/MulticaApi.kt)
- [Chat API](../../android/core-network/src/main/java/ai/chatty/core/network/ChatApi.kt) 与 [ChatSocket](../../android/core-network/src/main/java/ai/chatty/core/network/ChatSocket.kt)
- [ChatController](../../android/feature-chat/src/main/java/ai/chatty/feature/chat/ChatController.kt) 与 [呈现规则](../../android/feature-chat/src/main/java/ai/chatty/feature/chat/ChatPresentation.kt)
- [Workspace API](../../android/core-network/src/main/java/ai/chatty/core/network/WorkspaceApi.kt) 与 [ProjectsController](../../android/feature-workspace/src/main/java/ai/chatty/feature/workspace/ProjectsController.kt)
- [认证 fixture](../../scripts/auth-fixture.py) 与 [Chat / 项目 fixture](../../scripts/chat-fixture.py)：同一 8765 端口，按场景分别运行；模拟器访问 Mac loopback，物理 iPhone 需要独立受控可达地址或测试隧道，不能假设手机 127.0.0.1 指向 Mac。

### Multica 参考基线

- `/Users/benjamin/Workspace/multica/packages/core/types/{chat,agent,attachment}.ts`：协议与权限输入。
- `/Users/benjamin/Workspace/multica/apps/mobile/data/realtime/`：移动生命周期和失效范围的参考。
- `/Users/benjamin/Workspace/multica/apps/mobile/components/chat/`：当前移动端内容展示参考，不能覆盖 Chatty 最新产品范围。
- `/Users/benjamin/Workspace/multica/server/cmd/server/router.go`：进入实现时复核真实路由与服务能力。

本方案的完成标准是范围、交互、实现依赖和验证方法清楚可审查。后续实现需要独立留下运行证据；本文不标记任何 iOS 功能已完成。
