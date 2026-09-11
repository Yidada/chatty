# iOS 0.1.0 (3) TestFlight 交付记录

日期：2026-09-11。

Benjamin 在 CLE-85 确认「需要新的」TestFlight 包后，本轮完成版本提升、Release 归档与校验，并核实上传链路。**归档尚未上传**：本机 Xcode 当前没有登录 App Store Connect 账号，也没有 iOS Distribution 证书，命令行导出与 Organizer 上传都缺凭据。

## 交付内容

- 构建号提升提交：`c52ff217ff6bbbbdd3072bd7e7a1cc54a27dd4e0`（`scripts/generate-ios-project.py` 的 `CURRENT_PROJECT_VERSION` 由 2 改为 3，`ios/Chatty.xcodeproj/project.pbxproj` 同步重生成；两个生成器脚本重跑后除构建号外无差异）。
- 功能源码：`d158991a512ced9fbf222c8d51924770b5fcdec8`（PR [#6](https://github.com/Yidada/chatty/pull/6)，动态页多选与批量处理），构建号提升提交是它的直接后继。
- 归档：`.tools/ios-testflight/0.1.0-3/Chatty.xcarchive`（17 MB，含 dSYM）。
- Organizer 可见副本：`~/Library/Developer/Xcode/Archives/2026-09-11/Chatty.xcarchive`，Xcode 归档列表中的 `Chatty 0.1.0 (3)` 即为本次归档。

归档树与 `c52ff21` 的工作树一致；本轮之后新增的只有 `.sdlc/` 与 `ios/TESTFLIGHT.md` 文档，不参与编译，二进制不受影响。

## 归档校验

校验脚本输出见 [archive-validation.json](evidence/release-0.1.0-3/archive-validation.json)。

- `CFBundleShortVersionString` = `0.1.0`，`CFBundleVersion` = `3`，`CFBundleIdentifier` = `ai.chatty.ios`，架构 `arm64`。
- 签名：`Apple Development: Benjamin Zhang (DN7SAK4V8K)`，Team `9247PC9936`；`codesign --verify --deep --strict` 通过（valid on disk / satisfies its Designated Requirement）。
- 发布隔离：普通包内无 `CHATTY_FIXTURE`、`ai.chatty.ios.fixture`、`FixtureSupport` 标记，`Info.plist` 无 ATS 例外。
- 主二进制 SHA-256：`168df16b13bedc961de5cb69b50ced5b2c8cd704401573a41b8e899f9dd499ef`。
- Release 归档唯一告警是 `appintentsmetadataprocessor: Metadata extraction skipped. No AppIntents.framework dependency found.`，与本应用无关。

## 上传阻塞（实测证据，2026-09-11 10:56 SGT）

```
$ xcodebuild -exportArchive -archivePath <2026-09-10 归档> -exportOptionsPlist <app-store-connect> \
    -exportPath <空目录> -allowProvisioningUpdates
error: exportArchive No Accounts
error: exportArchive No signing certificate "iOS Distribution" found
** EXPORT FAILED **
```

- `IDEProvisioningErrorDomain Code=23 "No Accounts"`，Apple 给的恢复建议是「Add a new account in Accounts settings」。
- 登录钥匙串中没有 `iOS Distribution` 证书（只有 Apple Development 与 Developer ID Application）。
- Xcode 偏好 `DVTDeveloperAccountManagerAppleIDLists` 为空，即 GUI 侧也没有已登录的 Apple ID。

命令行导出与上传（`destination = upload`）、Organizer 的 Distribute App 都依赖同一份账号/证书，因此本轮无法把归档送上 App Store Connect。

## 解封方式

两条任选其一，都不需要把任何密钥交给 agent：

1. **登录 Xcode 账号**（与 `0.1.0 (2)` 相同路径）：Xcode → Settings → Accounts 登录拥有 Team `9247PC9936` 的 Apple ID。之后既可自己点 Organizer 中 `Chatty 0.1.0 (3)` → Distribute App → TestFlight Internal Only，也可让 agent 重跑命令行导出与上传。
2. **配置 App Store Connect API Key**（可全程无人值守）：在 App Store Connect 创建 App Manager 角色的 API Key，把 `.p8` 放到仓库之外的固定位置（例如 `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`），只把 Key ID 与 Issuer ID 告知 agent；随后用 `xcodebuild -exportArchive -allowProvisioningUpdates -authenticationKeyPath … -authenticationKeyID … -authenticationKeyIssuerID …` 导出并以 `destination = upload` 上传。`.p8` 不进入对话、不进入仓库。

## 提交前测试

- `swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build-3 --disable-sandbox`：**51 项通过，0 失败**（原始日志 [swift-tests.log](evidence/release-0.1.0-3/swift-tests.log)）。
- Release / generic iOS 归档：**ARCHIVE SUCCEEDED**（`.tools/ios-testflight/0.1.0-3/archive.log`）。
- 本次改动只有构建号常量与生成后的工程文件，未触碰 Swift 源码；批量处理的功能验证沿用上一轮记录（[evidence.md](evidence.md)，51 项 Swift 测试与 iOS 宿主 XCTest）。

## 尚未完成

1. `0.1.0 (3)` 的上传与 Apple 处理状态核对。
2. 上传后保存中文 What to Test 说明（已备好 [testflight-notes.zh-Hans.txt](testflight-notes.zh-Hans.txt)），并把构建加入既有 `Benjamin Internal` 内测组（本轮未改动内测成员）。
3. 真机安装与真实账号体验验证。
