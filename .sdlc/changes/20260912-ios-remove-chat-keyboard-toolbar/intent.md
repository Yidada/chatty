# iOS：去掉 Mika 对话的「收起键盘」按钮

Benjamin 的小优化（2026-09-12）：Mika 对话页键盘上方工具栏里的「收起键盘」按钮是该项的唯一内容，去掉后整条 accessory bar 不再出现；键盘收起改走系统手势与消息列表的交互式滚动。

交付行为：键盘弹起时键盘上方只有系统键盘；`.scrollDismissesKeyboard(.interactively)` 与 iOS 系统手势是唯二的收起路径；`draftFocused` 焦点状态保留，发送后保持键盘的行为不变。

现状证据：`ios/Chatty/ChatScreen.swift` 的 `.toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("收起键盘") { draftFocused = false } } }` 是 keyboard placement 下唯一的项；`tests/device/ios/v1-core.ad:28` 与 `tests/device/ios/v1-workspaces.ad:12,21` 直接按 label 点该按钮。Android 侧没有这个入口。

范围：只动这一处键盘工具栏与受影响的两个回放脚本。不改发送 / 附件 / 项目选择行为，不动版本号，不上传 TestFlight。
