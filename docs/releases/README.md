# Chatty 四端发布流程

同一次产品发布使用一个版本号和一份[行为契约](activity-contract.md)，各平台构建号可以不同。Web 使用独立 Sites 源码仓库，在版本记录中固定其提交 SHA。最近一次记录：[0.2.0.json](0.2.0.json)。

## 1. 冻结与并行构建

1. 检查主仓库与 Web 仓库的分支、未提交修改和远端最新提交。使用独立工作树整合发布，保留用户原有工作。
2. 更新 Android、iOS/macOS 工程生成器及生成工程、Web package 的产品版本。每个平台维护自己的构建号。
3. 固定行为契约、各端源码 SHA 和验收场景。先执行只读检查：

```sh
python3 scripts/check-release-alignment.py --web-repo /path/to/web-checkout
```

当前脚本读取 `docs/releases/0.2.0.json`；下次发布需要更新脚本的记录路径和版本记录。检查只证明版本声明和契约快照一致，行为一致性仍需测试。

4. 在独立工作树并行执行 Web 测试/构建、Android 单测/lint/APK、Apple 共享核心测试及 iOS/macOS Release 归档。同一目录保持单一写入者。
5. 按契约验证自定义待验收状态、分页后的受阻任务、已读与待关注独立、验收回执及冲突。自动测试使用合成数据，不修改生产任务。

## 2. 分渠道发布与结束条件

| 渠道 | 操作与结束条件 |
| --- | --- |
| Web | 按 Sites hosting skill 保存精确源码版本并部署；确认部署状态 succeeded、最终 URL 和原有访问范围。终态成功后停止轮询。 |
| Android | 记录包名、版本、签名类型、SHA-256；安装合成数据测试包验证关键流程。连接正式服务的 debug APK 必须标注“debug 签名验收包”，不得称为商店正式包。 |
| iOS | 按[TestFlight 流程](../../ios/TESTFLIGHT.md)上传，等待处理，处理加密信息，添加原内测组，确认 Testing 与组名。手机安装另外记录。 |
| macOS | Developer ID 签名归档 → Apple 公证通过 → 导出带票据的应用 → 签名 DMG → 从 DMG 复制安装并验证启动。见下方命令。 |

各端构建可并行。Xcode Organizer 的交互弹窗按顺序操作，Apple 后台处理与其他端工作可并行。每个渠道单独记录结果，不承诺四端在同一时刻可用。

## 3. Mac 公证与安装验证

1. 在 Organizer 中确认应用标识、版本、构建号和架构，选择 Distribute App → Direct Distribution。
2. 上传到 notary service 后仍需等待。打开状态日志检查 `Ready to distribute` / `Notarized`；上传成功或 Processing 不能作为公证完成证据。
3. 优先 Export Notarized App。若图形导出按钮不可用，使用 Xcode 官方命令：

```sh
xcodebuild -exportNotarizedApp \
  -archivePath "$CHATTY_NOTARIZED_ARCHIVE" \
  -exportPath "$CHATTY_EXPORT_DIR"
```

`CHATTY_NOTARIZED_ARCHIVE` 必须指向实际提交公证、带提交记录的 Organizer 归档。导入可能产生重复归档；原始构建路径或同版本的另一个副本可能没有公证记录。先核实再导出。

4. 验证导出应用，随后打包（签名身份只在本机环境变量中设置）：

```sh
codesign --verify --deep --strict "$CHATTY_EXPORT_DIR/Chatty.app"
xcrun stapler validate "$CHATTY_EXPORT_DIR/Chatty.app"
spctl --assess --type execute -vv "$CHATTY_EXPORT_DIR/Chatty.app"
bash macos/scripts/package-dmg.sh "$CHATTY_EXPORT_DIR/Chatty.app"
```

5. 验证 DMG 签名与镜像校验和，记录 SHA-256。只读挂载 DMG，用 `ditto` 复制应用到独立安装检查目录，卸载镜像，再检查复制后应用的签名、票据与 Gatekeeper。
6. 启动安装副本，确认实际进程路径、版本和窗口。到达登录页只证明启动成功；真实账号业务验收需单独记录。不要覆盖用户旧应用或清除其数据来完成检查。

## 4. TestFlight 本次经验

- 使用用户指定的 ego lite；检查实际登录状态，不能由 Xcode 已登录推断网页也已登录。
- 可使用浏览器中对应账号的已存密码正常登录；遇到无法自动完成的双重验证再请用户操作，不导出密码或凭据。
- 原生应用的可访问性树可能滞后。登录后页面显示空白时，可通过 CUA 标签页接口读取同一个已观察到的标签页，避免反复登录或另开浏览器。
- `Missing Compliance` 时先对照当前代码和依赖回答加密问题。0.2.0 使用 Apple 系统网络、Keychain、文件保护和 CryptoKit SHA-256，选了 `None of the algorithms mentioned above`；后续版本必须重新检查，不能盲目复用。
- `Ready to Test` 后检查组分配。已有内测组也可能未自动收到新版；通过 Add Group 选择原组，确认最终为 `Testing` 且显示该组。
- `Testing` 与组分配证明渠道可用，手机成功下载、安装和启动需要另外验证。

## 5. 记录与交付

每次记录产品版本、各端构建号、源码 SHA、测试结果、渠道状态、产物名及哈希、验证时间和未完成项。交付表提供 Web URL、APK、TestFlight 版本和 DMG。

- 源码文档保持去标识化，不提交个人邮箱、手机号、Team ID、证书身份、绝对个人路径、原始截图或日志。
- 凭据、签名私钥、归档、安装包和原始证据留在本地忽略目录；分发包中的正常签名证书信息与源码隐私检查分开处理。
- 源码提交、远端推送和渠道发布分别记录；发布包成功不代表主分支已同步。
- 0.2.0：Web 已上线；Android debug 验收包通过 Pixel 合成数据闭环；Mac 公证 DMG 安装副本启动通过；iOS 已在原内测组显示 Testing，手机安装未验证。

此流程提供可重复的并行发布步骤与检查，不代表已配置无人值守 CI。下一步自动化应复用这些结束条件与凭据隔离规则。
