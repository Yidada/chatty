# 证据与缺口

- Outcome: pending
- 2026-09-09，起点提交 e60e166；规划前 git status --short 为空。
- 同会话只读设备检查：source scripts/android-env.sh; "$ADB" devices -l；Pixel 6 Pro / 1A021FDEE004VC，状态 device。getprop ro.product.model 确认型号，dumpsys battery 显示80%。不证明独占窗口或温度合格。
- 源码检查：ChatController.refresh 会调用 readContext，并将 capabilitiesCurrent 设为 false；canSend 依赖该状态。start 中5秒循环有条件刷新。WorkspaceScreens 在重新进入前台时 refresh，概览条件下30秒刷新。以上是候选原因，未测得它们对真实延迟的贡献。
- 历史样本见 baseline/results.md：S1冷启动约305–315ms中位数，首屏而非可输入时间；热条件与刷新率不符合预算级协议，状态 NO_BUDGET。
- 当前未运行设备场景，未修改产品代码，未取得新 B0、缓存命中或优化收益。
- 下一份证据：固定条件的常用路径时间线、请求数、不可操作区间、帧分布与版本绑定。

- 本轮记录校验：sdlc.py transition --change-id 20260906-android-v3-performance-baseline --stage design 成功；validate 同一变更返回 valid=true、issues=[]。该结果只证明记录结构符合契约，不代表性能或产品验收通过。
