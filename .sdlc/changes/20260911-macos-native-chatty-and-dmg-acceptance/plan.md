# 实施计划 v1

## 已有授权与门禁
用户授权创建 macOS 目录、开发与交付 DMG；R3 具体 spec/plan 决定在本轮设计文档展示后待确认。delivery=local，无生产部署门禁。本轮不自动提交或推送新 Mac 代码，保留可评审 diff 与 SDLC 工件。

## 顺序
1. 完成设计门禁；创建 macos/Chatty、Config、Tests、scripts 和确定性 Xcode 工程生成器。记录所有已有修改基线。
2. macos/ 引用 ChattyCore，适配桌面 App/Bootstrap/主题/侧栏/设置，不迁移共享包目录。
3. 适配动态、项目、详情、富文本和链接；适配 Mika 非阻塞输入、项目选择、附件、队列恢复；仅必要共享修正在 ios/Packages/ChattyKit/ 中进行并回归。
4. 补充 macOS 文件权限和隔离测试；Fixture 独立 target 连接本地合成服务，保留生产 isolation。
5. 编译、运行核心测试和桌面 UI 验证；修复实际失败，审查最终 diff 与风险。
6. Release 打包为 macos/dist/Chatty-<version>.dmg，Developer ID 签名与公证按实际可用权限执行；没有公证时明确记录，禁止以改变系统安全设置作为成功条件。
7. 校验镜像、挂载、复制至临时验收目录、真实启动正常包；给出 SHA-256、安装说明和实际测试边界。按本地交付证据推进闭环。

## 命令与验证计划
已确认工具：xcodebuild 26.6、python3；共享包声明 macOS 15。
- 共享核心：swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/macos-chatty/swift-tests。
- 工程生成：python3 macos/scripts/generate-project.py（待实现）。
- 编译：xcodebuild -project macos/Chatty.xcodeproj -scheme Chatty -configuration Release -destination 'generic/platform=macOS' -derivedDataPath .tools/macos-chatty/derived build（具体签名参数按账户检查确定）。
- 合成服务复用 scripts/chat-fixture.py / scripts/ios-fixture.py 的已验证契约；macOS 启动封装放 macos/，不覆盖 Android 正在修改的脚本。
- 桌面 UI 用 CUA 或 XCUITest 检查 M1–M6；生产验证仅启动与隔离检查，真实发送留用户验收。
- 打包脚本 macos/scripts/package-dmg.sh（待实现），调用 codesign、hdiutil create/verify、shasum；如有公证配置再使用 xcrun notarytool 与 stapler。

以上未来命令为计划，尚未声称执行成功。
