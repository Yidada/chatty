# Chatty Next

独立的 SwiftUI / UIKit iPhone 客户端。聊天、模型和工作目录通过 HTTPS / WSS 连接当前 Mac 的 dsh。最低 iOS 26，首要设备为 iPhone 15 Pro。

## 启动

```sh
python3 scripts/generate-ios-project.py
open ios/Chatty.xcodeproj
```

- 真实服务：选择 `ChattyNext` scheme，bundle 为 `ai.chatty.ios.next`。
- 本地演示：运行 `python3 scripts/chatty-next-fixture.py`，选择 `ChattyNextFixture`。服务仅绑定 `127.0.0.1:8876`，只有合成数据。
- 首次连接输入 Mac 的完整 HTTPS 地址与 dsh 启动凭据，或含 token 的连接 URL。凭据交换后 Cookie 存入本 App 的 Keychain，来源包含端口；不会共享系统 Cookie jar。
- 工作目录使用 Mac 已登记的 workspace。首次发送才创建会话；既有会话改选目录会确认并新建草稿。
- 点击右侧波形图标切换为“按住说话”。首次需要麦克风权限和中文语音资源；按住录音，松手发送，上滑取消。识别器预热后供下一次按住使用。
- 空的文本输入框里长按也会直接说话：0.25 秒后进入录音，松手发送、上滑取消，结束后回到文字模式；轻点仍然是聚焦键盘，框里已有文字时长按仍是系统文本选择。
- 工具过程默认收起为一行并显示调用次数，点击查看步骤、参数和结果；回复正文直接显示。
- 语音内容通过 Apple SpeechAnalyzer 在设备端转成文字；文字与附件随后发给 Mac。模型推理位置由 dsh 的配置决定。
- 当前附件限制每项 20 MB、每条消息最多 20 项。图片通过会话授权接口读取；文件显示名称。服务端能力与 UI 都不支持的历史删除、置顶、原地编辑和重新生成不提供入口。

## 检查

```sh
swift test --package-path ios/Packages/ChattyNextKit --scratch-path .tools/chatty-next/swift-build
swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyNextFixture \
  -destination 'platform=iOS Simulator,name=Chatty Next iPhone 15 Pro' \
  -derivedDataPath .tools/chatty-next/xcode CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

本机测试设备名可以替换为已有模拟器。实体设备需在 Xcode 选择自己的签名团队和有效开发描述文件；仓库不硬编码团队或个人描述文件。

`NextProbe` 使用与 App 相同的原生网络及归并代码，可执行真实服务 smoke。JSON 文件格式如下，存放在忽略的 `.tools/` 下，设置文件权限为 `600`：

```json
{"address":"https://YOUR-MAC.ts.net:8443","token":"YOUR-LOCAL-TOKEN","sendSmoke":false}
```

```sh
swift run --package-path ios/Packages/ChattyNextKit --scratch-path .tools/chatty-next/swift-build \
  NextProbe .tools/chatty-next/connection.json .tools/chatty-next/capture
```

- `sendSmoke:false` 只验证配对、模型目录和三个状态流。
- 明确设为 `true` 并提供 `workspace` 绝对路径，会登记该目录、创建测试会话并发送一句 smoke 提示。生成物可能包含服务端系统上下文，应留在忽略目录中。
- Debug App 支持一次性的 `CHATTY_NEXT_PAIR_URL` 启动环境变量，便于在受控设备验证中配对；Release 不编译此入口。凭据不写进 scheme 或仓库。
- `ChattyNextFixture` 只覆盖基础文字流、模型、目录、历史、停止和重命名。它的停止通过恢复快照结束临时流，不作为生产停止时序证据。附件、工具确认和 ASR 验收使用真实链路。

## 结构与边界

### 默认自动审核（Approve for me）

- App 不提供权限模式选择。每次发送前通过 `commands/execute` 的 `/chatty-review` 确认当前会话已启用审核。
- Mac 使用 `workspace-write` 基线；权限请求由独立、无工具的 DeepSeek 模型调用审核。明确授权的低 / 中风险操作自动允许一次，危险越权操作拒绝，不确定或服务失败时交给用户判断。
- 普通提问仍由用户回答。自动审核不会代填 `user-questions/request`，也不会自动重放旧的人工审批。
- 现有会话在下一次从新版 App 发送消息时启用。启用标记保存在服务端会话日志，手机后台或断线不影响后续审核。
- Mac 需要安装仓库内的 `server/chatty-next-approval` 组件。当前适配本机 dsh 0.1.5-rc.2；没有组件时客户端保留发送快照并报告兼容性错误。

```sh
python3 scripts/install-chatty-next-approval.py --apply
node --test server/chatty-next-approval/review.test.js
```

安装器只修改所选 dsh profile 的 Chatty 组件入口，保留备份。支持 `patchReload: live` 的部署会热加载，不改变 dsh 的全局默认权限。`/chatty-review-check` 使用真实模型审核三个固定合成案例，不执行案例工具。

### 源码

- `ChattyNext/NextModel.swift`：连接代次、会话草稿、发送事务、状态流和工具确认。
- `ChattyNext/SpeechInputController.swift` / `HoldToTalk.swift`：麦克风、识别结果与真实触摸的绑定。录音身份同时绑定来源、会话、草稿修订号。
- `Packages/ChattyNextKit`：来源校验、HTTP / WSS、会话事件归并、Keychain、草稿快照以及可重复的核心测试。
- `Chatty/RichContentView.swift` / `ComposerText.swift`：共享富文本与输入法逻辑；旧 Chatty 保留原业务适配。
- 服务会话格式目前为 v3，事件词汇依据本机 dsh 0.1.5-rc.2。未知必需事件、增量缺口或格式升级会阻止继续推导；不可忽略地跳过事件会得到不完整历史。
- 请求超时不会自动再次发送；快照和队列负责核对。无法确认时保留原始发送快照，并提供复制到新草稿的操作。

实测记录与未完成验收见 [build.md](../.sdlc/changes/20260913-chatty-next-deepseek-ios/build.md)。真机语音质量、蜂窝网络和像素一致性尚未通过。
