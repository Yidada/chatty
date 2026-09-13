# Chatty Next 实现与验证

最新提交前回归见 [review.md](review.md)：148 项通过、1 项跳过，另有真实模型 3 项合成诊断和模拟器发送验证。以下按实现阶段保留历史记录与各自的覆盖边界。

## 2026-09-13 补充：D22 默认自动审核

- 已实现并安装到 iPhone 15 Pro：Chatty Next 不提供权限模式选择器，设置页固定显示“自动审核”。每次发送在附件 / prompt 前取得 Mac 的自动审核启用回执。旧会话从新版 App 下一次发送起启用，已进入人工等待的旧审批保留原状态。
- Mac 组件 `server/chatty-next-approval` 已热加载到现有 dsh web profile。组件只处理带 Chatty 标记的会话，维持工作区沙箱，使用独立无工具模型调用进行单次审核；审核不受手机后台状态影响。
- 授权明确的低 / 中风险操作允许一次；危险越权操作拒绝；不确定、缺少完整证据、超时或模型失败时保留人工确认。取消、已经结算、用户输入改变及重复请求均有处理。结构化用户问题仍由用户回答。

| 验证 | 结果 | 证据 |
| --- | --- | --- |
| Mac 审核组件 | 12 项通过；覆盖作用域、嵌套调用、拒绝、取消、超时、去重和不完整模型输出 | `.tools/chatty-next/automatic-approval-server-tests.log` |
| iOS 核心 | 15 项通过；新增准确回执与扩展事件兼容检查 | `.tools/chatty-next/automatic-approval-core-tests.log` |
| 原生回归 | 10 项通过；0 失败 | `.tools/chatty-next/automatic-approval-native-tests.log` |
| iPhone 包 | Debug 构建成功并安装 `ai.chatty.ios.next` | `.tools/chatty-next/automatic-approval-device-build.log` |
| 真实审核模型 | 3 个固定合成案例符合预期；明确授权写入 allow，无关删除含指令注入 deny，凭据外传 deny；执行工具数量 0 | `build-evidence/automatic-approval-model-check.json` |
| 真机设置页 | 固定“默认方式：自动审核”，无选择器 | `build-evidence/phone-automatic-approval-settings.png` |
| 真机发送链 | 会话 `83B3BB79-02E3-4487-A656-2514353042C0`：seq 4 命令、5 启用、6 成功回执、12 用户消息、21 固定回复、23 完成；本轮工具调用 0 | `build-evidence/automatic-approval-phone-flow.json` |

边界：升权写文件的实执行验收被本次 Codex 自动审批审核拒绝，理由是测试额外请求 `danger-full-access` 且存在更安全的验证方式。该操作没有执行；改用真实模型、合成案例、零工具执行的诊断。以上证据验证默认启用、审核结论和手机发送流程，未宣称真实升权命令已经完成端到端验收。

组件安装入口为 `scripts/install-chatty-next-approval.py --apply`，它保留 profile patch 备份，使用内容哈希路径热更新。此次未重启 dsh、未修改其全局权限默认值，也未修改 Codex 配置。

日期：2026-09-13。用户调用独立 `sdlc-build`，在 `Next` 分支沿用 D17、D20，实现独立 iOS 客户端。当前达到可运行的原生文字对话版本；第一阶段完整 DeepSeek 对齐仍未完成。

## 已实现

- `ChattyNext` / `ChattyNextFixture` 独立 target，生产 bundle `ai.chatty.ios.next`，独立 Keychain service 和受保护存储。继续由确定性脚本生成工程。
- 固定 HTTPS 来源和端口配对、HTTP RPC、WSS `/api/remote.mux`；凭据交换后只发送 Cookie，后续请求不携带 token query。拒绝跨来源重定向与过期凭据。
- 实际 modelCatalog、workspace/follow、首次创建、session/prompt、follow / control / $events。历史搜索、重命名、切换，新目录生成新草稿并保留旧会话。
- 发送前原子保存原文、附件、模型、目录和 requestId。超时保留待核对快照，恢复时对账；不自动重新 POST。第一条尚未发送的草稿也保存恢复入口。
- 临时回答与持久消息归并、重复帧去重、缺帧阻止推导；基于格式 v3 与当前模块事件词汇拒绝未知必需事件。正文 / 思考 / 工具内容分开呈现。
- 原生富文本、表格、代码、数学、复制、系统分享；相册 / 相机 / 文件入口；图片使用会话授权接口预览；队列移除、停止、工具授权和结构化提问界面。
- D20 语音：点击切换模式，按住采集，蓝色录音态，上滑红色取消态，松手等待最终识别并发送，无声不发送。Apple SpeechAnalyzer / SpeechTranscriber、中文资产准备和预热、采样转换、超时与中断保护。
- 录音身份绑定来源、会话与草稿修订号，取消后迟到结果无法发送。深色采用系统语义色；尺寸、取消阈值与触觉仍为候选参数。

## 实际验证

| 层次 | 实测结果 | 证据 |
| --- | --- | --- |
| 新核心 | 14 项通过：来源 / 端口、代理 Cookie、重定向、RPC、过期凭据、增量 / 最终归并、缺帧、录音身份、草稿与真实协议样本 | `.tools/chatty-next/core-build.log`；`ios/Packages/ChattyNextKit/Tests/` |
| Next 原生宿主 | 8 项通过：原 7 项 + 工具过程分组、流式 / 历史边界、嵌套结果展示 | `.tools/chatty-next/native-tool-collapse-tests.log` |
| 旧核心回归 | 98 项通过 | `.tools/chatty-next/shared-core-tests.log` |
| 旧 iOS 宿主 | 14 项中 13 项通过、1 项跳过、0 失败；未因此宣称旧 fixture 全旅程通过 | `.tools/chatty-next/legacy-tests.log` |
| 工程生成 | 重复生成的工程、schemes、Info.plist 哈希一致；diff whitespace 检查通过 | `scripts/generate-ios-project.py` |
| 真实 Mac 网络 | 原生 Swift 客户端经 Tailscale HTTPS 配对；WSS 工作目录 / 控制 / events 基线均通过 | `.tools/chatty-next/probe.log` |
| 真实 dsh 会话 | 在本次独立 smoke 目录创建会话，收到 27 帧与持久回答；requestId 正确对账 | 脱敏后的 `Tests/ChattyNextCoreTests/Fixtures/dsh-0.1.5-frames.json` |
| 模拟器实际操作 | iPhone 15 Pro / iOS 26.5：选实际目录、文字发送、中文回答、表格、停止、重启后恢复原会话与完整回复 | `.tools/chatty-next/simulator-*-tree.json`、截图 |
| 停止的服务端核对 | 第二轮 assistant/message 为 `interrupted:true`，turn/end 为 `aborted` / `user` | 本次 smoke 会话 v3 持久日志，未复制其他会话内容 |
| Debug / Release 构建 | 模拟器 Debug、实体设备 Debug 签名、Release 编译通过；Release 未归档或上传 | `.tools/chatty-next/*build.log` |
| 实体 iPhone | iPhone 15 Pro / iOS 27.0：已启动、完成 Tailscale 配对并加载真实模型 / workspace；录音崩溃修复后，无声松手和上滑取消通过 | `.tools/chatty-next/device-audio-fix-build.log`；真机 AX / USB 观察和崩溃摘要 |

构建使用 Xcode 26.6、iOS SDK 26.5；没有更换工具链或全局配置。具体命令见 [Next 开发说明](../../../ios/NEXT.md)。本轮未提交、推送或发布安装包到 TestFlight。

## 证据边界与下一步

1. 真机 HTTPS / WSS 配对和目录加载已完成；无声录音与上滑取消已观察。真实有声输入 → dsh → 回复正在验证。
2. ASR 30 条配对样本、延迟 / 准确率指标、来电 / 锁屏 / 无声 / 拒权，以及触觉和精确取消手势均待真机测试。现有单位测试只能证明状态隔离。
3. 蜂窝 + Tailscale、网络切换、dsh 重启、完整附件上传与工具确认流程仍待实测；代码存在不计为通过。
4. 深浅色逐屏叠图、≤1 pt 几何预算、动画 / 掉帧、10 轮日常混合对话尚未通过。模型与 workspace 替换按用户明确差异保留。
5. 删除、置顶、历史编辑、原地重新生成仍没有已确认的等价 dsh 契约；本版没有伪装这些操作。继续按 parity-matrix 追踪。
6. 本地 fixture 仅用于合成界面和协议操作；其状态时序、模拟器麦克风或 HTML 原型均不能证明 DeepSeek 真机体验。

因此 N1 已有 Mac、模拟器及真机连接证据，真机完整对话旅程仍需补齐；N2 / N3 / N4 保持未完成。无声和取消的功能检查不代表语音速度、准确率或像素预算已达标。


## 可查看的产物

- [最终浅色模拟器截图](build-evidence/next-light.png)
- [真机语音待机截图](build-evidence/phone-voice-idle.png)：iPhone 15 Pro / iOS 27.0，修复录音崩溃后的构建。
- [最终深色模拟器截图](build-evidence/next-dark.png)：候选颜色，未做 DeepSeek 深色对照。
- [源码指纹](build-evidence/source-sha256.json)：用于识别本轮安装和验证的实现。
- 本次服务端 smoke 会话：`EFDD24FA-A50B-4B5B-9784-330715E09EF1`（协议）与 `77EDC911-2356-44F5-8D3A-D2FB1703DD7E`（模拟器、停止）。独立测试工作目录保留用于追查。
- 本轮创建的合成服务已停止；既有 dsh / Tailscale 服务配置没有修改。

## 真机继续验证：15:48–15:55

- 用户启动 App 后发现 iPhone 的 Tailscale 为 Not Connected；恢复既有 VPN 后，手机成功配对当前 Mac。没有更换服务器地址、token、ACL 或 Serve 配置。
- 首次按住录音触发真实崩溃：`RealtimeMessenger.mServiceQueue` → `_dispatch_assert_queue_fail` → `SpeechInputController.begin` 的音频 tap。Swift 6 将原闭包推断为 MainActor 隔离。
- 将 tap 明确为 `@Sendable`，音频转换留在串行音频回调，界面状态回到 MainActor。跳过空音频帧。新增测试从后台调用实际 tap，检查 48 kHz → 16 kHz 转换和输入缓冲区复用后输出数据仍有效。
- 重新构建并覆盖安装。7 项 Next 原生测试通过。真机连续观察到：蓝色“松手发送，上滑取消”；8 秒无声松手 →“未识别到内容”；上滑 → 红色“松手取消”；取消松手 → 原语音输入页。两次均保留空对话，没有发送。
- 上述中间状态通过 QuickTime USB 实时画面观察。自动化工具的截图队列会等待手势结束，因此未用手势完成后的截图冒充录音中证据。
- [脱敏崩溃与修复证据](build-evidence/phone-audio-crash-and-fix.json)。线程标注依据 [Swift Sendable 文档](https://developer.apple.com/documentation/swift/sendable)。
- 修复后 Release 构建再次通过：`.tools/chatty-next/release-audio-fix-build.log`。本次仅安装开发构建，没有上传或发布。
- 已请用户在真机说出固定测试句，待核对自然语音结果。截至 15:57，App 仍在空对话语音待机页，测试目录仅有此前 Mac / 模拟器创建的两个会话。

### 用户继续试用后的服务端核对

- 15:58 观察到实体设备试用后新增会话 `FBE4F7BF-CFCC-44C3-ABB1-23FD52E5B277`，仍位于本次 smoke workspace。该会话仅有一条 `source.kind=user` 消息，随后得到持久回答与 `turn/end`。
- 用户反馈“为什么这么快”。服务端没有录音开始 / 松手时间，也没有输入方式字段；这条记录证明消息和回答到达真实 dsh，不能单独证明 ASR 延迟或把该反馈当作完整质量验收。
- 收到的英文包含 `do youg righ now`，用户原话与键盘 / 语音输入方式尚未核对，因此不能据此计算识别准确率。中文识别器目前固定 `zh-CN`，英文 / 中英混合仍属待测项。

## D21 实现：工具过程默认折叠

- `NextChatView.swift` 在展示层将连续的纯思考 / 工具消息组成一个默认收起的入口。具有正文或附件的助手消息保持在主对话中，调用参数使用独立折叠区；工具结果解开 dsh 的嵌套 `tool-result.content` 后显示实际输出。
- 过程消息不再显示空白的复制 / 分享动作。切换会话和重新启动后恢复默认折叠。没有改变 reducer 的事件顺序、存储或服务端会话。
- 真机当前会话的 4 次调用现在默认显示“工具调用 · 4 次”，下面能直接阅读回答。点开已看到真实 `run_code` 步骤、调用参数和 STDOUT，再次启动后参数与结果不在默认可见树中。
- 8 项原生测试通过，签名 Debug 构建和安装通过。记录：`.tools/chatty-next/native-tool-collapse-tests.log`、`device-tool-collapse-build.log`、`tool-collapsed-tree.json`、`tool-expanded-tree.json`、`tool-arguments-tree.json`、`tool-restarted-tree.json`。
- [真机默认折叠截图](build-evidence/phone-tools-collapsed.png)。此次没有向 dsh 发送新的测试消息，也没有为验证重新执行历史工具。

- D21 最终构建补充：Release 构建通过（`release-tool-collapse-build.log`）；最终覆盖安装后再次核对真实会话，默认折叠与正文可见均通过（`tool-final-tree.json`）。

## D22 实现：空文本输入框长按说话

- 用户要求对齐 DeepSeek 的入口：不必先点右下波形图标切到语音模式，在空的文本输入框里长按即可直接说话。
- `Chatty/ComposerText.swift` 新增可选 `hold` 回调与 `UILongPressGestureRecognizer`（阈值 0.25s，`allowableMovement` 交给手势自己判断上滑）。仅当输入框启用且草稿为空时识别；框里有文字时 `gestureRecognizerShouldBegin` 返回 false，长按仍归系统文本选择，轻点仍聚焦键盘。
- 长按开始即进入现有语音事务：蓝 / 红波形覆盖层、松手发送、上滑取消与语音模式共用 `SpeechInputController`，未新增语音 RPC。开始时收起键盘，结束后回到原文字模式。
- 手势逻辑抽成纯状态机 `ComposerHoldTracker`，宿主测试覆盖开始 / 上滑距离 / 松手 / 取消以及重复事件不重发。
- 10 项 Next 原生测试通过（新增 2 项）。模拟器 `ChattyNextFixture` 启动、配对与输入卡渲染无回归。
- 记录：`.tools/chatty-next/native-longpress-tests.log`、`longpress-composer.png`。
- 真机实测（Argent 0.25.0 真实触摸注入，iPhone 15 Pro / iOS 27.0，16:22–16:37）：
  - 空输入框轻点仍聚焦并抬起键盘（next.draft 上移、出现键盘），没有误触发录音 —— D22 的回归边界成立。
  - 在当前会话空输入框长按 2.5 秒，设备端语音流程启动；本次环境音被识别成单字母 "u" 并直接发送，dsh 随即回答，证明「长按 → 录音 → 识别 → 发送」在真机成立，且不需要先切换到语音模式。
  - 早前两次无声长按得到「未识别到内容」，没有发送任何消息。
- 证据：[真机长按发送后](build-evidence/phone-longpress-sent-u.png)、[真机轻点聚焦](build-evidence/phone-tap-focus.png)。
- 局限与副作用：Argent 截图会排在物理触摸之后，未能截到蓝色录音覆盖层帧；覆盖层复用 D20 已真机验证的同一 voiceOverlay。本次测试在 CHATTY_AUTO_REVIEW 会话留下一条 "u" 与对应回答，是真实发送证据。阈值 0.25s、结束后停留在文字模式、以及「已有草稿」入口仍为候选，未与 DeepSeek 2.4.5 逐帧核对。
