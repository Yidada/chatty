# 执行计划：先定位体验损失，再验证最小修复

## 来源与状态

用户 2026-09-09 反馈整体操作多余、卡顿，并显式要求 AI-Native SDLC 驱动。
复用本变更与 CLE-70/CLE-73。旧式 Stage 2 表示性能基线阶段；协调器当前 Plan/Design 表示需求与设计工作，两者不等同。已有样本保留原始结论。

## 工作顺序

1. **体验诊断与补齐 B0**：确认 Pixel 当前独占窗口、解锁、安装版本和 APK/source 一致性；保持正常包数据，用独立 benchmark 包与 synthetic fixture。电量40–80%、温度稳定/thermal NONE、固定60Hz，同设备、数据与编译模式重复采样。
2. **补足测量边界**：在 android/macrobenchmark 的 ChattyBenchmark.kt 与 scripts/perf/ 中补编辑器可用时间、切 Tab/返回、请求计数和发送禁用区间。先测 S1 常用路径，再测 S2 分页/实时更新；新增设备流程放 tests/device/android/。为每条路径记录重复点击、是否必要及其原因，避免凭主观删除确认操作。
3. **提交诊断结果**：生成瓶颈排序、原始样本路径、B0 与建议预算 T。首个修复按用户影响、测量证据与改动范围选择，不预先认定缓存能解决全部卡顿。
4. **具体设计与最小产品修复**：补充 spec、风险和回滚，确认已有授权覆盖具体设计；优先评估 ChatController.refresh/readContext/start、ProjectsController、WorkspaceScreens 的刷新触发与状态。权限保护继续有效。
5. **缓存增量**：在首个修复复测后，按需引入账号/工作区隔离的 repository/持久化读缓存、失效与容量控制，依据 intent.md 的既有约束；避免一次重写全部数据层。
6. **验证与交付**：同条件前后对比、身份隔离与失败回归、代码审查。记录达标路径及遗留问题；仅在用户授权的交付范围内合并/推送，发布另按目标环境处理。

## 验证命令

从仓库根目录执行：

```bash
source scripts/android-env.sh
android/gradlew -p android :app:assembleDebug :app:assembleBenchmark :macrobenchmark:assembleBenchmark test lint
python3 -m unittest discover -s scripts/perf -p 'test_*.py' -v
python3 scripts/perf/collect.py --serial 1A021FDEE004VC --scenario S1 --rounds 2 --methods cold hot scroll --output .tools/perf/<unique-run>
```

最后一条只覆盖现有启动/首窗口滚动，UX1完整就绪时间、UX2/UX3、S2完整路径仍需扩展测量，不能将其成功当作全部验收。
原始私密数据留 .tools/；可提交的脱敏汇总放本目录 evidence/；旧 baseline/ 不覆盖。

## 授权与依赖

1A–6A 已批准，不重复询问缓存范围。B0/T 验收仍是产品优化前置条件。
Pixel 连接已确认；独占窗口、当前安装包、解锁与温度需每次测试前重新核实。
当前没有承诺真实账号发送或外部 Issue 写入，也未创建重复 Issue。
