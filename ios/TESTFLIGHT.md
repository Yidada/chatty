# Chatty TestFlight 发布

统一入口：[四端发布流程](../docs/releases/README.md)。当前发布记录：[0.2.0](../docs/releases/0.2.0.json)。

## 最近确认的状态

- 应用标识：`ai.chatty.ios`；生产 Scheme：`Chatty`，排除 `ChattyFixture`。
- 版本：`0.2.0 (11)`（移除 iPad 侧边栏，iPhone / iPad 统一单栏 Tab）。
- 已上传并完成 Apple 处理，已保存与代码实现一致的加密信息。
- 已加入原有内部测试组，App Store Connect 显示 **Testing**。
- 分发方式为 **TestFlight Internal Only**；此构建仅用于内部测试。
- 手机下载、安装和启动尚未验证。以上为本次发布观察，不保证后续会话的登录和服务状态。

## 归档与上传

1. 检查生产版本、构建号、Bundle ID、隐私声明与图标。版本在 `scripts/generate-ios-project.py` 维护，修改后重新生成工程。
2. 使用唯一归档路径，禁止覆盖旧归档。开发团队只通过本机参数提供：

```sh
swift scripts/generate-ios-icon.swift
python3 scripts/generate-ios-project.py
xcodebuild -project ios/Chatty.xcodeproj -scheme Chatty \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$CHATTY_IOS_DERIVED_DATA" \
  -archivePath "$CHATTY_IOS_ARCHIVE" \
  DEVELOPMENT_TEAM="$CHATTY_DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates -skipPackageUpdates archive
```

3. 在 Xcode Organizer 核对归档版本和标识，选择 **Distribute App → TestFlight Internal Only**，记录上传结果。
4. 若 CLI 提示 `No Accounts`，检查实际认证配置。已有 GUI 登录可以通过 Organizer 完成上传，不需要为解决此问题临时导出登录凭据。

## 网页分发

1. 在用户指定浏览器打开 App Store Connect，进入 Chatty → TestFlight。Xcode 登录和网页登录独立检查。
2. 等待目标版本/构建完成处理。出现 **Missing Compliance** 时打开 Manage，对照当前代码与依赖回答。
3. 本轮代码仅使用 Apple 系统网络、Keychain、文件保护与 CryptoKit SHA-256，无自定义加密算法或独立加密库，问卷选择 **None of the algorithms mentioned above**。加密实现变化后重新评估，不能默认复制该答案。
4. 保存后确认 **Ready to Test**。检查原内测组是否包含该构建；如未分配，通过 **Add Group** 选择原组。
5. 以目标版本/构建同时显示 **Testing** 和原组名为渠道发布完成证据。不要因为旧版已有内测组而假设新版自动分发。
6. 如任务包含真机闭环，在 iPhone TestFlight 更新并启动，单独记录安装和业务验证；未操作时明确标注未验证。

## 隐私与证据

公共源码仅记录去标识化状态。账号、Team ID、组 ID、签名凭据和原始截图日志不写入发布文档。使用本地发布清单保存产物哈希和实际结果，源码提交/推送状态与 TestFlight 分发状态分别记录。
