# Android 导航连续性

2026-09-05。参考 `.sdlc/changes/20260905-complete-ios-v1-native-client-p1-through-p5/design-plan.md` 的交互目标，范围为 Tab 状态保留、原生完整详情页、可取消的工作区选择。

## 行为

- 对话 / 项目 / 设置分别保留当前运行中的页面状态。切换 Tab 后回到原详情、筛选、搜索草稿和阅读位置。
- 项目列表重取数据时保留已加载分页的范围，不因切换 Tab 降回第一页；进度继续读取服务端完整统计。
- Issue 使用完整详情页，显示标题、进度、优先级、描述；状态修改继续携带 suppress_run 与 revision。
- Runtime / Agent / Squad 使用完整详情页，按字段阅读；系统返回及顶部返回逐级回到列表和设置。
- 工作区选择在底部面板完成。取消、系统返回或选中当前工作区均保留当前内容；成功选中另一工作区后重建该工作区的页面状态。
- 工作区列表加载失败时可重试或取消，当前工作区和凭据保留。

## 状态与生命周期

- 三个 Route 的状态所有者位于稳定的 Shell 中，业务数据仍仅存内存。未选中的 Tab 不渲染页面或注册返回处理器。
- 每个流程显式维护层级：项目总览 → Issue 列表 → Issue 详情；设置 → 资源列表 → 资源详情。当前固定层级未增加导航依赖。
- 对话 UI 的滚动位置与阅读模式保存、恢复；业务请求作用域独立于当前页面。离开对话不会取消已提交的发送，返回后通过 REST 同步结果。
- WebSocket 与前台轮询仅在对话可见且 Activity 前台时运行。资源列表在重新显示或回前台时刷新，保持选中的资源与阅读位置。
- 返回对话、回到前台、手动刷新和同步事件均重新获取 Agent 绑定、当前用户与工作区调用权限。同步失败时保留草稿并暂停发送，重试成功后恢复。当前 Agent 暂时消失时仍保留会话和草稿的身份，避免切到其他 Agent。
- Shell 按登录凭据及工作区 ID 隔离。切换工作区和退出会销毁旧状态所有者并取消其请求。
- 本轮保留的是应用当前运行中的工作位置。冷启动仍从服务端重新读取业务实体，既有持久化草稿机制保留；未增加离线消息库或进程重建后的完整导航恢复承诺。

## 验证入口

- `WorkspacePickerTest`：加载期间取消、选择当前工作区、提交另一工作区。
- `ProjectsControllerTest`：分页/筛选保留、详情版本刷新和迟到详情响应隔离。
- `scripts/navigation-device-test.py`：Pixel 上完整详情、逐级返回、查询/分页/滚动位置、后台合成发送、工作区取消及隔离。
- `scripts/tabs-device-test.py` 与 `scripts/chat-device-test.py`：原有项目写入、资源、聊天和恢复回归，按新的页面保留行为更新操作步骤。
- Android 合成服务支持 `CHATTY_FIXTURE_PORT`；设备脚本通过 `CHATTY_FIXTURE_URL` 选择本机端口。设备使用 ADB reverse 将固定 fixture 地址映射到独立主机端口，避免和 iOS 测试冲突。

## 本轮结果

> 历史补测确认 NAV-TEST-01：Mika 绑定 Runtime 后，返回对话和手动刷新未更新调用能力，重启才恢复。原有 41 项测试仍通过，新增边界测试 3 项通过、1 项失败。见 [原始复核记录](../.sdlc/archive/iterations/v2/evidence/navigation-sdlc-test/review.md)。该问题已在本地修复，验证与交付范围见 [修复记录](../.sdlc/archive/iterations/v2/evidence/runtime-binding-fix/review.md)。

- 构建、Lint 与 41 项 JVM 测试通过。
- Pixel 连续性、原有项目管理、聊天收发与恢复、深色/1.3 倍字体流程通过。
- 第 55 条 Issue 在切换前后屏幕坐标一致，历史消息阅读锚点保持。
- 测试证据保存在 `.sdlc/archive/iterations/v2/evidence/navigation-validation/` 与同级 `navigation-*-loop/`、`navigation-*-regression/`。

- 最终真实服务 APK 已安装至 Pixel 6 Pro；真实工作区选择取消和三个资源列表的跨 Tab 保留验证通过，当前进程无 AndroidRuntime FATAL。
- 测试包与本次端口转发已移除，系统夜间模式 auto / 字号 1.0 已恢复；未发送真实消息或修改真实 Issues。
