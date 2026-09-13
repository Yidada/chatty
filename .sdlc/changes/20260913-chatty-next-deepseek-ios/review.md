# Chatty Next 提交前测试

日期：2026-09-13，Asia/Singapore。分支 `Next`，父提交 `7f4703e`。用户明确调用独立 `sdlc-test`，并已要求提交当前改动。

结论：本轮 148 项自动测试通过、1 项跳过、0 项失败；真实审核模型 3 个合成案例通过；模拟器发送与富文本展示流程通过。本次为实现者自测与自审，覆盖本批 iOS、共享组件和 Mac 审核组件；完整 DeepSeek 体验验收仍待完成。

## 本轮结果

| 检查 | 结果 | 覆盖范围 |
| --- | --- | --- |
| ChattyNextKit | 15 通过 | 固定来源、Cookie、RPC、事件合并、缺帧、草稿、语音身份、审核回执 |
| ChattyKit 旧核心 | 98 通过 | 复用代码相关的既有核心回归 |
| Mac 审核组件 | 12 通过 | 会话作用域、单次允许、拒绝、缺失证据、嵌套调用、取消、输入改变、超时、异常和去重 |
| Next 原生宿主 | 10 通过 | 音频后台回调、长按与输入法、富文本、工具折叠、草稿与目录切换 |
| 旧原生宿主 | 13 通过、1 跳过 | 共享输入和渲染组件回归；文件保护属性仅能在实体设备验证 |
| 真实 DeepSeek 审核 | 3 通过 | 明确授权临时写入 allow；无关删除及指令注入 deny；凭据外传 deny；工具执行数 0 |
| 模拟器交互 | 通过 | 选演示目录、输入、回车发送、回复中、完成、表格和代码展示；此流程使用合成 fixture |
| 工程生成与文件检查 | 通过 | 9 个生成文件重跑后不变；83 个提交候选文件在测试期间没有变化；凭据特征扫描和 whitespace 检查通过 |

结构化结果、日志摘要、合成模型结果和模拟器 AX / 截图保存在 [test-evidence](test-evidence/results.json)。完整日志位于 `.tools/chatty-next/precommit-*-tests.log`，其 SHA-256 已记录；本机日志和连接凭据不提交。

## 环境与复现

- macOS 26.6.2（25G83），Xcode 26.6（17F113），iOS SDK 26.5，Swift 6.3.2。
- Node.js v22.23.0，Python 3.9.6，Argent 0.25.0。
- 本次专用 iPhone 15 Pro 模拟器，iOS 26.5，UDID `9C63D23A-19C8-4223-9517-258D1C014F60`。
- 已读取 `.sdlc/config.json`。其中命令针对 Android；本批没有 Android 改动，使用以下 iOS 和 Node 检查。活动目录没有 `state.json`，没有启动协调器、创建审批记录或推进发布阶段。

以下命令均在仓库根目录执行：

```sh
swift test --package-path ios/Packages/ChattyNextKit --scratch-path .tools/chatty-next/swift-build
swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build
node --test server/chatty-next-approval/review.test.js
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyNextFixture -destination 'platform=iOS Simulator,id=9C63D23A-19C8-4223-9517-258D1C014F60' -derivedDataPath .tools/chatty-next/xcode CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -destination 'platform=iOS Simulator,id=9C63D23A-19C8-4223-9517-258D1C014F60' -derivedDataPath .tools/chatty-next/legacy-regression CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
python3 scripts/generate-ios-project.py
git diff --check
```

真实模型诊断：通过本机测试适配器 `python3 .tools/chatty-next/approval-live-probe.py check` 创建独立诊断会话，先执行 `/chatty-review`，取得准确启用回执，再调用仓库组件提供的 `/chatty-review-check`。会话 `3BE6975E-E53D-41DF-AB0B-2823C05468C9`，命令回执和三项逐案结果见 [real-model-check.json](test-evidence/real-model-check.json)。该检查使用真实模型处理固定合成输入，无候选工具执行；可在已安装组件的 dsh 会话中以相同两条命令复现。诊断适配器读取忽略目录的配对凭据，未复制凭据到工件。

模拟器流程：启动 `python3 -u scripts/chatty-next-fixture.py`，在 Argent 中启动 `ai.chatty.ios.next.fixture`，选择演示目录，在输入框键入 `Chatty Next precommit fixture check` 并按 Enter。观察到回复中和停止入口，随后得到单份完整回答、表格和代码块，停止入口消失，输入框恢复空草稿。界面证据仅支持本次合成发送流程；当前 fixture 对 `/chatty-review` 提供固定成功回执，不包含真实模型审核。

## 环境问题、跳过项和未完成验收

1. Next 原生宿主启动时，合成服务尚未运行，日志记录 `127.0.0.1:8876` 连接拒绝（`-1004`）。10 项测试没有依赖该服务，全部通过。随后启动 fixture 并完成上述实际界面发送，验证服务恢复后的流程；没有修改断言或跳过失败测试。
2. 旧宿主的 `testPhysicalFileProtectionAttribute` 在 `ios/Tests/SimulatorContractTests.swift:98` 按既有规则跳过，原因是模拟器不提供该属性。本轮没有实体设备重测。
3. 本轮核对先前安装和真机验证的 24 个实现文件指纹没有变化，因此沿用 [build.md](build.md) 中工具默认折叠、固定自动审核设置和真实手机发送证据。本轮没有重新操作用户 iPhone，也未重新宣称一次真机完整验收。
4. 自动审核已验证模型结论、失败回退、启用回执及客户端发送顺序。真实升权工具执行的端到端验收仍缺失；此前测试被自动审批审核拒绝的原因和未执行事实保留在 [build.md](build.md)。
5. 语音 30 条样本的准确率和延迟、英文及混合语言、来电与锁屏、蜂窝及网络切换、完整附件旅程、逐屏像素与动画预算、日常混合对话仍未验收。测试通过不能据此宣布完成 DeepSeek 像素级复刻。

本轮未发现所测范围内的新增阻塞缺陷。提交定位为当前可运行实现及证据的开发检查点；没有触发 TestFlight、发布或推送。
