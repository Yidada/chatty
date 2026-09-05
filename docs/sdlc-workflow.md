# SDLC 模具 (Repo Mold)

> 基于 Anthropic Agentic SDLC：**意图 → 规格 → 任务 → 实现 → 评估 → 加固** 六阶段。
> 每一阶段产出一个可审阅的仓库级 Artifact，Gate 通过后才进入下一阶段；评估以实证（命令输出、截图、Appium 证据）而非主观判断为准。

## 仓库地图

```
chatty/
├── README.md               # 定位 + 当前轮次指针 + 目录导航 (人/Agent 首先读它)
├── iterations/             # 每轮迭代一个目录, 轮内 md 与证据同生共死
│   ├── v1/                 # 本轮产物
│   │   ├── intent.md       #    S1: 意图 (含验收签名, Draft → Accepted)
│   │   ├── spec.md         #    S2: 规格
│   │   ├── ISSUES.md       #    S3: 任务清单 → Multica CLE-xxx 
│   │   ├── EVAL.md         #    S5: 验收矩阵 + 实证日志
│   │   ├── HARDENING.md    #    S6: 加固队列
│   │   ├── delivery.md     #    本轮交付摘要 (结论喂给下一轮 intent)
│   │   └── evidence/       #    本轮实证截图/日志 (唯一证据存放处)
│   └── v2/ ...
├── docs/                   # 跨轮长期文档 (dev-loop、sdlc-workflow)
├── scripts/                # 跨轮工具 (dev-loop.sh, appium-ui.sh)
├── android/                # 实现源码 (版本跟随 git tag, 不按轮分目录)
└── test/                   # (已并入 iterations/vN/evidence/)
```

## 轮次迭代机制

- **一轮 = 一个完整六阶段**：`vN/intent.md → spec.md → ISSUES.md → 实现 → EVAL → HARDENING → delivery.md`。
- **开新轮**：先读 `vN/delivery.md`（上轮结论/遗留），写成 `vN+1/intent.md` 的出发点；`spec.md` 只列相对 vN 的增量。
- **冻结规则**：轮次推进后，`vN/` 内容视为历史，不再修改；需要修历史缺陷 → 作为新轮 intent 的输入。
- **代码不按轮分目录**：`android/` 永远是当前代码；每轮验收通过后打 git tag `v1.0.0`、`v2.0.0`，轮次与代码一一对应。
- **README 指针唯一真值**：`README.md · Status` 标明 `当前轮次` 与 `当前 Stage`，Agent 开工先对齐它。

## 阶段与产物

| Stage | 产物 | 为谁而写 | 进入条件 |
| --- | --- | --- | --- |
| 1 Plan | `intent.md` | 产品负责人 (acceptance) | 想法可用一句话描述 |
| 2 Spec | `spec.md` | 实现 Agent / 验收者 | intent Accepted |
| 3 Task List | `ISSUES.md` + Multica 项目 Issue | 执行 Agent | spec Reviewed |
| 4 Implementation | 源码 + 运行证据 | Agent 自证 | Issue 有验收标准 |
| 5 Evaluation | `EVAL.md` 实证矩阵 | 验收者 | 全部功能实现 |
| 6 Hardening | `HARDENING.md` | 验收者 | EVAL 全绿 |

## Gate 规则

- **G1 (Intent → Spec)**：intent.md 头部 `Status: Accepted`，由产品负责人确认；否则 spec.md 不准创建。
- **G2 (Spec → Tasks)**：spec.md 含 objective / schedule / acceptance criteria / eval plan 四节；Issue 分解在其后。
- **G3 (Task → 实现)**：每个 Issue 在 Multica 项目 (Issues.md 同目标) 有 assignee、优先级与验收标准；实现只在负责 runtime 上执行。
- **G4 (实现 → 验收)**：该 Issue 的验收标准必须转化为一条可复现的验证命令；拒绝"已改好了"式口头验收。
- **G5 (EVAL → Hardening)**：EVAL.md 全部单元格有证据路径；Hardening 只允许 P1/P2 优先级任务进入。

## 实证纪律 (Evidence rules)

1. **每条验收必须落证据**：`EVAL.md · 验收矩阵` 每行 = 验收项 | 命令或脚本 | 证据路径 (`test/…png`、logcat 摘录、Appium session id) | 结论。
2. **产物命名**：`iterations/vN/evidence/<feature>-<case>-<round>.png`，旧截图保留原文件、EVAL 追加重叠行，不覆盖证据。
3. **闭环工具是证据源头**：`scripts/dev-loop.sh`（安装即崩溃检查）、`scripts/appium-ui.sh`（UI 识别/点击/截图）产出所有 UI 类证据；真实交互闭环 = 最终验收手段。
4. **失败也记录**：bug 复现命令写入 `HARDENING.md` 的 P1/P2 队列，与它对应的修复 commit 一一对应。
5. **无用提交**：每个 Issue 完成 = 一个或多个自足 commit（含验证摘要），不把半成品证据留在工作区。

## 状态机

```
intent.md(Draft) → intent.md(Accepted) → spec.md → ISSUES.md → 实现(逐 Issue) → EVAL.md(绿) → HARDENING.md(清空)
```

当前阶段以 `README.md · Status` 为唯一指针，本文件只定义流程规则。
