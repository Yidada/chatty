# Chatty Next 0.2.0 (11) 发布完成

日期：2026-09-13，Asia/Singapore。交付包含 Git 代码推送和独立 Chatty Next 的 TestFlight 内测，两项已完成。

## 交付结果

| 渠道 | 结果 |
| --- | --- |
| GitHub | `Next` 分支已推送，包含实现提交 `6af5189` 和交付记录；[查看分支](https://github.com/Yidada/chatty/tree/Next) |
| TestFlight | `Chatty Next 0.2.0 (11)`，Apple 处理 `VALID`，内部状态 `IN_BETA_TESTING`，页面显示 **Testing** |
| 内部组 | `Benjamin Internal`，目标构建已明确分配；当前登录的 Apple 账号已加入，页面显示 1 个邀请 |
| 说明与加密 | 已保存简体中文 What to Test；`INTERNAL_ONLY`；`usesNonExemptEncryption=false` |
| 手机安装 | 本次未验证从 TestFlight 下载、安装和启动 |

- App ID：`6811557635`；Bundle ID：`ai.chatty.ios.next`；主语言：`zh-Hans`。
- Build ID：`1f84242b-58cb-4ede-b31c-44b6e26ee330`。
- [App Store Connect / TestFlight](https://appstoreconnect.apple.com/apps/6811557635/testflight/ios)。本次未创建 PR、合并主分支或公开上架 App Store。
- [结构化发布回执](release-evidence.json)记录产物、验证与覆盖边界。账号、Team ID、内部组 ID、原始截图和日志保留在本地忽略目录。

## 固定产物与测试

- 实现提交：`6af51895cd5dcc473a2708e246bb3218bcf3e1e2`。后续提交仅补充发布和交付说明。
- Scheme：`ChattyNext`，Release，arm64，最低 iOS 26。
- 归档与 IPA 所在目录：`.tools/chatty-next/releases/0.2.0-11-6af5189-20260913-170531/`。
- 归档：`ChattyNext-0.2.0-11.xcarchive`；IPA：`ChattyNext-0.2.0-11.ipa`，3,518,108 字节。
- IPA SHA-256：`14495ecb28ae2714b63860ee15c6180a8e270b7f36b897186d8b7ffaa04d57d2`。
- 严格签名验证通过；分发包 `get-task-allow=false`、`beta-reports-active=true`。版本和构建号未由导出过程自动修改。
- [测试记录](review.md)：148 项自动测试通过、1 项既有模拟器限制跳过；3 个真实模型合成审核案例通过，候选工具执行数为 0；模拟器发送与渲染流程通过。
- Release 成品已检查 bundle、版本、架构、麦克风和语音用途声明、系统加密声明与网络配置。二进制没有 Debug 环境配对入口或 fixture Cookie 字符串。

## 实际交付方法

1. `asc xcode archive` 以唯一归档路径构建 `ChattyNext` Release，使用已有开发签名，`codesign --verify --deep --strict` 通过。
2. 注册独立 Bundle ID，通过已登录的 App Store Connect 网页创建 Chatty Next 应用记录。创建后 API 查询确认名称、标识和主语言，未重复创建。
3. `asc xcode export` 使用 `method=app-store-connect`、`destination=export`、`testFlightInternalTestingOnly=true`、`manageAppVersionAndBuildNumber=false`。通过 Xcode 的自动签名和已有 API 认证导出 IPA。本机隔离目录中的临时认证配置与密钥副本已在导出后删除，原有 Keychain 保留。
4. 执行 `asc builds upload --app 6811557635 --ipa <上述 IPA> --wait --poll-interval 30s`，等待构建出现并完成 Apple 处理。
5. 创建内部组，在网页选择当前登录账号加入；保存 `zh-Hans` 测试说明，并通过 `asc builds add-groups` 把目标 build 分配给该组。
6. 核对 `asc builds info` 返回 `VALID`；`asc builds build-beta-detail view` 返回 `IN_BETA_TESTING`；构建组查询显示一个明确关联的内部组。网页同时显示版本 0.2.0、构建 11、Testing、内部组及 1 个邀请。
7. 推送 `Next` 分支和交付记录，核对远端提交。仓库中的默认交付说明已写入 [ios/NEXT.md](../../../ios/NEXT.md)。

两项工具问题均已处理：应用创建完成后网页没有自动跳转，改用 API 验证新记录后继续；旧应用中的 tester ID 无法直接关联新应用，改为在新应用组的网页中选择当前账号，确认新应用组内已有 1 名测试者。两项均未通过重复创建或扩大测试受众处理。

## 运行依赖与回退

- Mac 审核组件内容版本 `1f8bf92bc9d9c128`，4 个运行文件与实现提交一致，profile 引用正确且声明 live reload。本轮没有重新安装、重启 dsh 或改变其全局默认权限。
- 客户端每次发送先取得 `/chatty-review` 回执。组件缺失会保留待发送快照并报告兼容性问题；客户端与 Mac 组件需要配套运行。
- 没有数据库迁移。客户端使用独立 Keychain 与草稿存储；服务端增加 Chatty 会话事件和会话作用域内审核。
- 首次独立 TestFlight 发布没有较旧的 Next TestFlight 构建可直接回退。需要停止分发时，可在取得授权后使该构建过期；已安装副本的处理需要单独验证。
- 已保留此前开发构建和本次归档。若需要覆盖安装回退，先确认版本和签名，并保留本地草稿与 Keychain。
- Mac 安装器已有 patch 备份和内容寻址组件目录。回退时先比对当前 patch，仅恢复 Chatty 管理块并保留其他修改；本轮没有执行回退。

## 保留的验收边界

语音准确率与延迟、英文及混合语言、像素与动画、网络切换、完整附件、真实升权工具执行仍有验收缺口。渠道发布完成后继续按 [review.md](review.md) 和 [parity-matrix.md](parity-matrix.md) 验证，不能据此宣布 DeepSeek 像素级复刻完成。
