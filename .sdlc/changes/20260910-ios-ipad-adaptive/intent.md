# iOS：iPad / iPadOS 自适应兼容体验设计

## 目标

Benjamin 在 Chatty iOS 升级线上提出「帮我设计一下 iPad 端的兼容体验」。本变更交付一份可执行、可验收的 iPad / iPadOS 自适应设计规范与实施拆分，使 Chatty 从 iPhone-only 变成一个通用 App 在 iPad 上有原生体验，同时 iPhone 紧凑宽度零回归。

来源：[CLE-84](https://multica.ai)（Chatty iOS：iPad / iPadOS 自适应兼容体验设计）。设计规范见 [spec.md](spec.md)，证据见 [evidence.md](evidence.md)，实施拆分见 [plan.md](plan.md)。

## 范围

- 交付设计文档：现状核对（带代码位置）、宽度档位矩阵、逐屏适配表、输入映射表、风险与回滚、与 [CLE-78](https://multica.ai) 的合并顺序、待拍板决策。
- 允许为验证设计结论做最小实验性改动；实验代码不得合入。

## 非目标

- 不做独立 iPad App、不新建平行 UI 代码路径、不加 iPad 专属 target。
- 不做桌面级三栏信息架构、不做离线/同步协议改造、不做 PencilKit（v1 只保证 Scribble）、不做 Android 对齐。
- 不发布、不上传 TestFlight；发布属实现阶段。
- 本变更不产生任何需要发布的产品代码变更。

## 已确定的基线

D1 一个通用 App（沿用 target 与 Bundle `ai.chatty.ios`）；D2 以 size class 驱动、不以 `userInterfaceIdiom` 判断设备；D3 紧凑宽度零回归；D4 窗口尺寸/分屏/Stage Manager/旋转都不重建会话状态。

## 验收口径

文档已合入仓库并附 PR；结论区分实测与推断；矩阵与逐屏表无占位项；与 CLE-78 的合并顺序明确；待拍板项可直接由 Benjamin 逐条决定；未越界到实现。
