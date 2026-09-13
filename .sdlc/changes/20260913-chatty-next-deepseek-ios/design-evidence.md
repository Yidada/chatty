# 设计阶段证据

日期：2026-09-13。`Next` 基点仍为 `7f4703e`。本轮沿用前一轮未提交规划工件，仅新增 / 更新设计文档、合成协议样例和 HTML 阅读原型。

## 1. 本轮当前证据

| 核查 | 结论 | 影响 |
| --- | --- | --- |
| AppBootstrap / SessionRootView | 普通配置仍指向 api.multica.ai；身份恢复后进入 WorkspaceTabs | Next 需要独立根入口 |
| ChatScreen / ChatHistoryView | 底部 safeAreaInset 输入区，历史仍通过 sheet 呈现，已有读位和过程状态 | 新抽屉容器与生成中的布局需要单独设计 |
| ComposerText | UIKit UITextView，markedTextRange 与硬件 Shift+Return 处理已存在 | 保留中文输入能力，具体发送规则等真机对照 |
| RichContentView | 依赖 WorkspaceContext 处理链接与附件 | 提取纯呈现接口时保留旧调用适配 |
| ProtectedStorage | Keychain ThisDeviceOnly、原子文件、complete protection、排除备份 | Next 采用独立身份 / 目录，继承存储属性 |
| ClientFlowTests | 已有连续发送、回执不明、重复点击、相同文本独立身份、跨来源凭据约束 | 这些是设计检查来源，本轮没有运行或宣称 Next 通过 |
| DraftScopeTests | 草稿按会话、迁移、已存在目标不覆盖等测试 | 新会话键迁移与录音结果归属需继承不变量 |
| dsh client connection 实现 | 请求 URL 是 `/api/<endpoint>`；envelope 为 client-request / server-response | 修正规划中仅描述 `/api` 前缀的细节 |
| dsh generated host descriptor | list 参数 wire 名为 `_request`，prompt / follow 为 `request`，control 无参数 | 示例按描述符区分，不能盲目统一包装 |
| dsh cancel 实现 | `agent.cancel({kind:"user"},{keepInbox:true})` | 停当前与清空队列分开，禁止自动重试 cancel |
| dsh prompt 实现 | requestId 查队列和 user/message，后面存在异步附件解析 | 不承诺任意并发 / 崩溃场景的原子去重 |
| dsh assistant stream | start / chunk / end、attemptId / revision / index、durable settlement | Next reducer 必须完整归并临时和持久内容 |
| dsh file upload | application/octet-stream 原始 body，返回有独立 receiptId | 不套用旧 Multica 上传接口 |
| dsh approval / user-questions | $events waterfall，授权一次 / 拒绝；问题按 id 返回 selected / custom | 原生确认和问答卡具有明确返回格式 |
| Tailscale / HTTP 再核查 | 8443 仍转发至 127.0.0.1:3080；本地和 tailnet URL 的 GET 均返回 401 | 当前仅证明服务可达鉴权边界，没有验证 iPhone |

安装代码与生成声明的绝对路径、packageVersion、SHA-256 收录于 [协议来源清单](contracts/manifest.json)。启动器为 0.1.5-rc.1；相关磁盘包版本单列，不能推断运行进程已经加载它们。

## 2. 外部来源

- [Apple SpeechAnalyzer 官方说明](https://developer.apple.com/videos/play/wwdc2025/277/)：设备端语音候选及临时 / 最终结果设计依据。
- [SpeechTranscriber 官方文档](https://developer.apple.com/documentation/speech/speechtranscriber)：设备 / 语言能力检查入口。
- DeepSeek 2.4.5（2）、iOS 27.0、iPhone 15 Pro 已取得真机语音与键盘参考；详见第 5 节和 voice-reference.md。

## 3. 本轮检查

- 初版 HTML 检查（旧语音流程已撤回）：通过录音 → 转写 → 回复 → 停止中切换；停止中按钮禁用；历史、离线、授权提交状态可达；离线发送禁用、授权提交后禁用；深浅色切换正常；390 px 窄窗口无横向溢出，录音按钮可见。已视觉检查桌面深色和窄屏浅色截图。
- 原型证据：[观察记录](design-qa/checks.json)、[窄屏录音截图](design-qa/narrow-recording.png)。这些结果只适用于设计 HTML。
- 文档检查：本地链接、JSON 格式、Markdown 代码块配对和 diff 空白检查通过。
- 合成协议示例：使用安装包 `TYPERT.invocations` 的生成参数 schema 校验 list、create、prompt、cancel、follow、control 共 6 个方法，通过；没有实例化服务或调用模型。[验证记录](contracts/validation.json)
- 该参数校验不包含真实鉴权、网络 envelope、WebSocket 完整生命周期、服务端运行状态或语音质量；它们仍需 N1 / N2 验收。

## 4. 没有执行的工作

初版设计没有操作真机。后续 USB 取证已安装 ArgentRunner，并在 DeepSeek 中实际按住录音和观察一次识别文字提交。本轮仍未修改产品 Swift 代码、创建产品 target、安装 ASR、启动新 dsh、调整 Tailscale、推送或发布。

设计规范的冻结状态详见 [spec.md 第 10 节](spec.md)。候选 UI 与静态契约检查不替代真机功能、语音、性能和像素验收。


## 输入框选择器修订（2026-09-13）

- 用户标注原“深度思考 / 智能搜索”位置，要求改成 model 选择 + workspace 选择；设计与计划同步记录为 D17 / A13。
- 读取已安装 dsh-api-workspace-controller 类型和生成契约，确认目录来自 workspace/follow 的 baseline / increments。注册目录与真实可读路径仍需运行时验证。
- 核查 SessionCommandController.create / selectModel：cwd 在 session 创建时绑定；selectModel 作用于后续请求并尝试保存共享默认模型。设计没有隐藏这些行为边界。
- HTML 增加两个可点开的选择面板、完整目录路径、已有会话换目录确认、草稿复制示意、运行时模型禁用、离线选择禁用和键盘关闭。
- 模型与目录均为合成数据，没有读取用户目录清单、调用模型、创建会话或修改服务配置。浏览器检查见 design-qa/selector-checks.json。

- 修订核查：15 项浏览器选择器检查通过，包括选择、确认 / 取消、草稿复制后可发送、历史返回、焦点循环、离线 / 运行中限制、390 px 窄屏与深色面板。4 个接口参数样本通过已安装生成 schema 校验，服务未调用。


## 语音交互纠正的历史记录（后续结果见第 5 节）

- 用户指出语音交互与 DeepSeek iOS 不一致。撤回 D11 的回填草稿再发送候选，移除旧录音 / 转写确认演示，保留模型和 workspace 选择。
- phone-harness connection_state 返回 not-running；未连接真机、未录音、未发送测试消息。需要用户完成镜像连接才能继续真机观察。
- 官方权限页只说明麦克风用于语音输入，未定义开始 / 取消 / 结束 / 提交流程：https://cdn.deepseek.com/policies/zh-CN/app-permissions.html 。公开资料没有被用作当前版本的手势基线。
- design-qa/checks.json 与 narrow-recording.png 中的旧录音演示检查已失效，仅保留历史追溯。当时语音对齐状态为 awaiting-reference；后续主流程参考已补齐，旧检查仍然失效。

- 用户建议采用 Argent USB。已读指定 X 帖文及官方实体设备文档，npx 运行 0.25.0 成功；未运行 init。CoreDevice 显示 iPhone 15 Pro 已 USB 配对连接，开发者模式关闭，未安装 Runner 或取得 DeepSeek 屏幕。详见 voice-reference.md。

## 5. 2026-09-13 USB 真机取证与语音重做

- 用户开启开发者模式后，已成功建立 Argent 0.25.0 → 实体 iPhone 15 Pro → DeepSeek 2.4.5 的操作路径。解决 runner 签名后完成安装；复用已有开发证书，新增此手机专用开发描述文件，没有改产品签名设置。
- 实际观察到模式切换、按住录音、蓝色波形与“松手发送，上滑取消”、正常松手提交、上滑红色“松手取消”和空结果提示。
- Argent 不能在阻塞的长按命令中间截屏；用 QuickTime USB 屏幕源取得连续记录。参考图、8 秒无音轨片段和观察树在 reference/，来源哈希在 reference-manifest.json。
- HTML 已实现指针按下 / 移动 / 松开事件链、取消锁存、Space / Esc 操作和意外中断取消。模型与工作目录选择保留。对应设计更新 spec.md 第 4 节、D20 和 contracts.md 第 8 节。
- 当前验证结果见 [语音原型检查](design-qa/voice-checks.json)。它们只验证 HTML；真实 ASR 延迟 / 准确率、原生实现、像素、触觉与 dsh 联网仍未通过验收。

- 最终浏览器检查 26 项通过：按住 / 上滑 / 松手、重复松手、键盘取消与发送、失焦 / pointercancel、草稿保护、选择器、390 px 窄屏 / 深色面板，以及触摸上滑取消。窄屏固定宽度问题已修正并复验；录音 / 取消截图来自专用静态阅读状态，行为检查使用真实浏览器指针与触摸事件。
- 本次取证完成后已停止该 iPhone 的 Argent runner 及本次 tool-server；已安装 runner 和专用开发描述文件保留，产品签名未改。
