# Release: iOS 0.2.0 (11) → TestFlight

- 版本 / 构建号：**0.2.0 (11)**（构建号在 `scripts/generate-ios-project.py` 维护并重新生成工程）
- 归档：`.tools/ios-sidebar-release/Chatty-0.2.0-11.xcarchive`
- 导出：`.tools/ios-sidebar-release/export/Chatty.ipa`（用 Admin API Key 走 `-authenticationKey*`）
- 上传：`asc builds upload --app 6809083972 --ipa … --wait`

## 核对

| 项 | 值 |
| --- | --- |
| Bundle ID | `ai.chatty.ios` |
| 处理状态 | `VALID` |
| 加密声明 | `ITSAppUsesNonExemptEncryption=false`（exempt） |
| 内测组 | 原内部组（Benjamin Internal） |
| 分发状态 | `IN_BETA_TESTING` |
| 真机安装 | 未验证 |

签名凭据、Key ID、组 ID 仅存本机，不写入公共文档。
