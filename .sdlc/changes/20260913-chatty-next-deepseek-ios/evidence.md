# 本轮核查依据

本文保留规划时点的核查记录。当前实现见 [build.md](build.md)，最新提交前测试见 [review.md](review.md)；下文“尚未完成”以当时阶段为准。

日期：2026-09-13。以下区分代码 / 文档观察、网络探测和未验证事项。

## 已执行

| 核查 | 结果 | 证据边界 |
| --- | --- | --- |
| Git 基线 | 本地 `main` 在 `7f4703e`，开始时工作区干净；已执行 `git switch -c Next` | 没有 fetch，不声明远端实时最新；本轮未提交、推送或合并 |
| 当前产品入口 | `README.md`、`ios/README.md`、`WorkspaceTabs.swift` 描述 / 实现动态、Mika、项目 | 旧文档的“没有历史 / 停止”等描述已落后于当前源码，不能当作今天的缺口 |
| 当前对话代码 | `ChatModel.swift` 读取 `/api/agents`、`/api/chat/sessions`，选择 `system_key == mika`；依赖 `WorkspaceContext` | 换一个 base URL 不足以接入 dsh |
| 已有组件 | `ChatHistoryView.swift`、`ComposerText.swift`、`RichContentView.swift`、`Theme.swift` 及按会话草稿逻辑存在 | 可以评估复用，不表示完成 DeepSeek 真机对照 |
| 语音代码 | 在 iOS 源码、plist 与工程生成脚本中未找到 `Speech` / `AVAudioEngine` / 转写 / 麦克风权限声明的实现匹配 | 当前未定位到可复用的完整语音输入链路 |
| dsh launcher | `/opt/homebrew/bin/dsh --version` 返回 `0.1.5-rc.1` | 启动器版本与下列依赖版本分开记录 |
| dsh 安装依赖 | `dsh-host-webserver`、`dsh-api-session-controller` 等 package 显示 `0.1.5-rc.2` | 磁盘包版本不证明运行进程已经加载同一份版本；需协议闭环确认 |
| 监听服务 | PID 62706 的 Node 进程监听 `127.0.0.1:3080`，工作目录为 DeepSeek Harness 安装目录 | 未启动、停止或重配服务 |
| Tailscale | `BackendState=Running`，当前 Mac 在线；Serve 的 `:8443` 代理到 `http://127.0.0.1:3080` | 配置与本机网络观察；尚未从用户 iPhone 验证 |
| 本机 HTTP | `GET http://127.0.0.1:3080/` 返回 HTTP 401 | 服务有响应；没有会话读取或模型请求 |
| Tailscale HTTPS | 从当前 Mac 对 `https://benjamins-mac-mini.tailcef6e6.ts.net:8443/` 请求返回 HTTP 401 | 证明当前 Mac 可通过该地址到达鉴权响应；不代表 iPhone 链路和登录完成 |

Tailscale 官方文档说明 Serve 用于将本地服务提供给 tailnet 内设备：[Tailscale Serve](https://tailscale.com/docs/features/tailscale-serve)。本轮复用已有配置，没有新增公网入口。

## dsh 接口证据

本地安装根：`/Users/benjamin/Library/Application Support/DeepSeek Harness/node_modules/@deepseek-ai/`。

| 文件 | 本轮读到的能力 / 约束 |
| --- | --- |
| `dsh-client-connection/README.md`，Browser authentication and request trust | `GET /?token=…` 换取绑定 hostname + port 的 cookie；HTTP RPC 与 WebSocket 都要求 session；没有 Authorization-header token 支持；401 与 403 分别表示鉴权和信任检查失败 |
| `dsh-api-gateway/README.md` | unary 走 `/api`；实时流复用 `/api/remote.mux` WebSocket；断线续接与业务失败区分处理 |
| `dsh-api-session-controller/lib/typert.remote-client.d.ts` | 声明 `session/list`、`create`、`search`、`rename`、`prompt`、`page`、`follow`、`control`、`cancel`、`updateQueue`、`fork`、`modelCatalog`、`selectModel` |
| `dsh-api-session-controller/README.md` | 文档描述 Assistant 临时增量、最终持久消息替换、历史分页、重连补齐以及 requestId 去重 |
| `dsh-api-session-controller/lib/index.js` | prompt 路径检查已有 `requestId`，命中时返回原接受语义；仅做源码核查，未发送请求 |
| `dsh-api-session-controller/lib/types/types.d.ts` | prompt 支持 text / image / file receipt；模型选择含 provider、model、可选 reasoningEffort |

不能由上述声明直接推出的结果：

- iOS 客户端已经可以接入，或全部配置已经适配当前 Tailscale authority。
- 已存在完整 ASR 服务。此次安装包名称和 iOS 代码核查未建立这项能力的证据。
- 所有 DeepSeek 操作都能直接映射。当前 session namespace 没有列出删除方法，仍需检查其他插件 / Remote。
- `reasoningEffort` 等于参考 App 的逐消息“深度思考”开关，或 web 工具等于逐消息“智能搜索”开关。
- 当前模型可以本地离线推理。

## DeepSeek 参考

- 用户本轮直接确认：iPhone 15 Pro，最突出的是语音快和准；同时要求输入、排版、流式输出、历史与动画体验。
- 本轮打开 [新加坡 App Store 官方页面](https://apps.apple.com/sg/app/deepseek-ai-assistant/id6737597349)，页面显示 2.5.1，版本说明包含思考过程自动折叠。它不证明用户手机的安装版本。
- 本轮查看 `ds/cn2.png`：现有营销素材包含欢迎区、输入卡片、深度思考 / 智能搜索、语音入口及附件面板。
- `ds/cn1..cn5.png` / `ds/us1..us5.png` 为已有仓库素材；它们是营销图片，不能作为 iPhone 15 Pro 整屏几何和手势时序的最终基准。
- 昨天的 [research.md](../20260912-ios-deepseek-chat-alignment/research.md) 和 [decisions.md](../20260912-ios-deepseek-chat-alignment/decisions.md) 包含候选与来源。当前要重新按真机证据分类，尤其是从 Web / 评论推测的 iOS 行为。
- 昨天的该规划目录没有 `state.json`；本轮未把历史阶段记录切换为本次活动协调器。

## 语音候选的依据

[Apple WWDC25 SpeechAnalyzer 说明](https://developer.apple.com/videos/play/wwdc2025/277/) 描述 iOS 26 的设备端识别、音频流输入、临时与最终转写。设备 / 语言支持仍需通过 [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber) 的能力查询确认。

这是候选路线的依据。本机的识别准确率和速度仍待测试。

## 本轮完成边界

已完成：分支创建、现有代码 / 文档核查、本机监听与 Tailscale 只读探测、规划产物。

尚未完成：DeepSeek 真机采样、语音评测、dsh 鉴权 / 发送 / 流式闭环、Next 产品代码、构建安装、像素验收、发布。
