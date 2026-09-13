# Chatty Next 发布准备

日期：2026-09-13。用户调用独立 `sdlc-release`，随后明确选择独立 Chatty Next 的 TestFlight 内测。当前状态：Bundle ID 已注册、分发签名 IPA 已导出，等待 Apple 网页登录以创建应用记录；尚未上传。

## 固定产物

- 代码提交：`6af51895cd5dcc473a2708e246bb3218bcf3e1e2`，分支 `Next`。
- Scheme：`ChattyNext`，Release，版本 `0.2.0 (11)`，bundle `ai.chatty.ios.next`，arm64，最低 iOS 26。
- 归档：`.tools/chatty-next/releases/0.2.0-11-6af5189-20260913-170531/ChattyNext-0.2.0-11.xcarchive`。
- 本地归档使用已有开发签名，严格签名验证通过；以下 IPA 已重新导出为分发签名，后续仍需上传、等待处理及分配内测组。
- 已导出 `ChattyNext-0.2.0-11.ipa`，位于归档同级目录，3,518,108 字节；SHA-256 `14495ecb28ae2714b63860ee15c6180a8e270b7f36b897186d8b7ffaa04d57d2`。IPA 分发签名验证通过，`get-task-allow=false`、`beta-reports-active=true`，导出选项为 TestFlight Internal Only。上传及 Apple 处理尚未执行。
- 发布检查见 [release-evidence.json](release-evidence.json)。归档完整文件哈希、签名与构建日志、内测说明草稿保存在同一忽略目录，签名配置和个人凭据不提交。

## 验证结果

1. 复用同一代码的 [提交前测试](review.md)：148 项通过、1 项既有模拟器限制跳过；3 个真实模型合成审核案例通过，候选工具执行数为 0；模拟器发送与渲染通过。
2. 本轮重新归档成功。检查成品的 bundle、版本、架构、麦克风和语音用途声明、系统加密声明及网络配置。Release 二进制没有 Debug 环境配对入口或 fixture Cookie 字符串。
3. 当前 Mac 安装的审核组件内容版本为 `1f8bf92bc9d9c128`，4 个运行文件与提交内容一致，profile 引用正确且声明 live reload；已有 2 份安装前 patch 备份。本次没有重新安装或修改服务配置。
4. GitHub 实时只读查询显示 `main` 为 `7f4703e`，远端没有 `Next`。当前变更还没有 PR 或远端发布。
5. App Store Connect 对 `ai.chatty.ios.next` 的查询返回 0 个应用。已通过 API 注册该 Bundle ID；创建 Chatty Next 应用记录需要 Apple 网页登录。既有 `ai.chatty.ios` 属于另一应用。

归档方法：使用 `asc xcode archive --project ios/Chatty.xcodeproj --scheme ChattyNext --configuration Release --archive-path <上述唯一归档路径>`；通过 `--xcodebuild-flag` 提供 `-destination generic/platform=iOS`、独立 derivedData、已有本地 Team、自动签名和 `-skipPackageUpdates`。使用已有描述文件完成，没有触发在线 provisioning 更新。随后执行 `codesign --verify --deep --strict <归档内 ChattyNext.app>`，验证通过。

导出方法：`asc xcode export` 使用 `method=app-store-connect`、`destination=export`、`testFlightInternalTestingOnly=true`、`manageAppVersionAndBuildNumber=false`，通过 Xcode 的 `-allowProvisioningUpdates` 和已有 API 认证完成分发签名。本机隔离目录中的临时认证配置与密钥副本已在导出后删除；原有 Keychain 保留。

## 发布内容与依赖

- 独立原生聊天入口、模型与工作目录选择、Tailscale HTTPS / WSS 连接、历史与流式回答。
- 按住说话、松手发送、上滑取消、空输入框直接长按；工具过程默认折叠。
- 默认自动审核需要 Mac 上的 `server/chatty-next-approval` 组件。每次发送先取得 `/chatty-review` 回执，组件缺失时保留待发送快照并报告兼容性问题。
- 本次没有服务端数据库迁移。客户端使用独立 Keychain 和本地草稿存储；服务端增加带 Chatty 名称的会话事件及作用域内权限审核。
- ASR 准确率和延迟、像素与动画、网络切换、完整附件、真实升权工具执行仍有验收缺口，详见测试记录。当前交付适合继续内测。

## 回退准备与限制

1. 客户端：保留此前开发构建和本次归档。若替换安装后出现问题，可在确认目标版本后覆盖安装保留的同 bundle 构建；优先保留草稿与 Keychain，避免卸载清除本地数据。此次独立应用尚无已确认可回退的 TestFlight 历史构建。
2. Mac：安装器已有 patch 备份与内容寻址组件目录。回退前先比对现有 patch，只恢复 Chatty 管理块并保留其他修改。移除组件会使当前客户端下次发送无法获得启用回执；客户端与组件需配套处理。
3. 源码：当前开发实现有独立提交，可通过新的 revert 提交回退；本轮未执行 revert、改写历史或覆盖远端。
4. 外部分发尚未执行，无需渠道回滚。应用记录创建、上传、Apple 处理、组分配和手机安装必须分别记录，归档成功不等同于渠道发布。

## 当前等待项

用户已授权独立 TestFlight 内测。API 认证有效；CLI 网页 session 与浏览器登录均已过期。Ego Lite 的本次发布窗口已交给用户完成登录和双重验证；收到继续指令后，在同一窗口创建应用，并继续上传、处理与内部组分配。无需再次确认发布目标。
