# Android 导航连续性交付候选包

状态：用户已要求发布并安装当前包；将交付至 GitHub 开发预览版和 Pixel。NAV-TEST-01 未修复并随版本披露。

## 内容

- chatty-navigation-debug.apk：当前导航连续性开发包，连接 https://api.multica.ai/。
- chatty-previous-debug.apk：上一轮视觉设计版本，供需要时回退。
- manifest.json：APK 校验值、签名核对、源码基线及已知问题。
- test-review.md：最近一次自审结果；41 项已有测试通过，4 项补充边界测试中 1 项失败。

## 变化

- 对话、项目、设置保留当前运行中的页面、搜索、筛选和阅读位置。
- Issue / Runtime / Agent / Squad 使用完整原生详情页及逐级返回。
- 工作区切换支持取消与当前工作区保留。

## 已知问题 NAV-TEST-01

Mika 在服务端新绑定 Runtime 后，设置能看到绑定，对话仍提示未绑定且无法发送；返回 Tab 和手动刷新都不恢复，重启应用后恢复。JVM 与 Pixel 已复现。建议修复、复测后再合入。

## 安装与回退边界

- 两个 APK 均为开发测试包：ai.chatty.app.debug，0.2.0-dev，versionCode 1。
- 两包签名已验证且证书一致；包名与版本号匹配，可准备使用 adb install -r 覆盖安装。
- 本轮没有执行回退演练。覆盖安装保留数据的实际结果仍需在目标手机验证。
- 当前代码未引入数据库或服务端迁移；运行中导航状态在重启后重新建立。
- APK 回退只替换客户端；真实发送、Issue 更新等已经发生的服务端操作不会随安装包回退。
- 本目录不表示已提交、推送、合并、创建 GitHub Release 或发布应用商店。

需要回退时，在本目录使用：

```sh
adb -s 1A021FDEE004VC install -r chatty-previous-debug.apk
adb -s 1A021FDEE004VC shell am force-stop ai.chatty.app.debug
adb -s 1A021FDEE004VC shell am start -n ai.chatty.app.debug/ai.chatty.app.MainActivity
```

安装后应重新检查登录、Mika 连接以及三 Tab 导航。

本地候选包：`/Users/benjamin/Workspace/chatty/.tools/deliverables/navigation-continuity-1376f653-candidate`。
