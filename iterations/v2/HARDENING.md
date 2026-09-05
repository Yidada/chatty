# Chatty v2 · 实施期缺陷记录

此文件在 Stage 4 记录失败与修复。完整 EVAL 尚未全绿，未进入 Stage 6 正式加固验收。

| 优先级 | 发现 | 复现 | 修复与证据 | 状态 |
|---|---|---|---|---|
| P2 | Android 26 不支持主题 `windowLightNavigationBar` | `android/gradlew -p android lint`，初始主题 | 移除不兼容属性；`evidence/m1-build-round1/build.log` → `m1-build-round2/build.log` | 已修复 |
| P2 | macOS zsh 下 Bash 路径变量为空，工具缓存路径落到父目录 | 在 zsh `source scripts/android-env.sh` 检查 CHATTY_ROOT | 分别处理 zsh/Bash 来源路径，二者均验证指向本仓库 | 已修复 |
| P2 | adb shell 的带空格日期参数被拆开 | 初版 `scripts/dev-loop.sh` | 把日期命令作为完整远端 shell 参数；`evidence/m1-launch-round3/launch.json` | 已修复 |
| P2 | Appium 默认服务环境与项目驱动不一致 | 原 4723 服务建立 session 返回 500 | 项目专用 4725 + APPIUM_HOME；`evidence/m1-ui-round3/result.json` | 已修复 |
| P2 | Compose 测试标签需实验 API 声明 | M2 第一轮构建 | 显式 OptIn；`evidence/m2-build-round1/build.log` | 已修复 |
| P2 | debug network security 域缺少 includeSubdomains | M2 第二轮 lint | 明确 false，仅开放 loopback；`evidence/m2-build-round2/build.log` → `m2-final-checks/lint.txt` | 已修复 |
| P2 | 本地 fixture HTTP/1.0 连接关闭与分块 POST 处理不完整，验证码路径出现 IOException | `python3 scripts/auth-device-test.py`，fixture 初始实现 | 支持 HTTP/1.1 与 chunked；`evidence/m2-auth-ui-round3/failure.png` 至 round5 保留，round6 全通过 | 已修复，问题位于测试服务 |
| P2 | 状态栏在设备深色设置下图标对比度不足 | M1 启动截图 | 为浅色应用显式设置浅色状态栏样式，当前登录截图可读 | 已修复 |

下一里程碑继续按 `ISSUES.md` 的 M3–M10 执行，功能开发不混入缺陷清单。

## 2026-09-05 Chat 源码对齐与闭环

- 用 Multica 实际类型/API 校正 workspace members 路由、system_key Mika 定位、task_id 稳定行键、附件点击时重签名、nullable attachments/quick_actions。
- 初次 lint 提示在 Compose 中直接读取 StateFlow.value；改为 lifecycle-aware 收集，最终 lint 通过。
- 初次设备脚本在验证码提交后未等待工作区页面；失败截图定位为测试等待时序，增加明确页面断言后完整闭环通过。
- 同时间戳历史刷新增加 id 次序比较，避免漏掉已经加载的相邻旧消息。
- 发送锁在发起协程前设置；断线导致回执不明时禁止无确认重发；本地写入失败不能把已接受的消息转换为重试 POST。
- 服务端附件回执若缺少请求中的附件，保留这些附件并显示提示，防止静默丢失。
- WebSocket 首帧认证、15 秒握手上限、onClosing 清理、生命周期取消和 REST 补取；不会把整个 workspace 的其他任务事件混入当前对话。
- 最终发送/消息去重、附件预览、任务过程、重连、草稿/进程恢复、分页、无回复、失败详情和 503 恢复在 Pixel 合成环境通过。真实历史与 socket auth_ack 另行只读验证。

## 三 Tab 真机修复

- 初轮项目页持续加载。诊断确认每次重绘都重建控制器；原因是把 Retrofit 动态代理放进 `remember` / `LaunchedEffect` 的 key。修复为 workspace ID、base URL、section 等稳定值。
- 同步修复设置页的代理 key，删除临时日志。Pixel 增加 3 秒稳定窗口的请求次数断言，修复后通过。
- 项目统计只用后端完整 counts；分页按返回条数推进 offset 并按 ID 去重。
- 自定义状态读取失败不会隐藏项目，状态编辑保持禁用；无 Mika 时不得回退到其他 Agent 发送。
- 进度 PUT 的 `suppress_run` 是必传序列化字段，防止默认值被省略后意外触发执行。用 API 单测和 Pixel 服务端记录同时验证。
- 设置页从后台回到前台会重新读取资源；详细配置留给 Multica 自身权限和功能开关处理。
