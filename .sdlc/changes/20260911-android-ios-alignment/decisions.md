# Decisions

- 2026-09-11：用户选择「全量对齐 iOS」并授权「先优化、后补 B0」。因此本轮不等真机 B0 直接做已定位热点修复，收益量化推迟到设备可用后的前后对比。
- 动态 feed 放在 `feature-inbox`（既有空模块），复用 `WorkspaceApi`，不新建 Gradle 模块。
- 已读指纹用 DataStore 按 `token 摘要 + workspace` 隔离持久化；查看只改本地指纹，业务状态由项目页写入。
- 「和 Mika 继续」只预填草稿，不覆盖非空草稿；未移植 iOS 的项目自动归属（Android chat 尚无项目选择）。
- 性能改动用「内容刷新 vs 身份/权限刷新」分离，保持 `canSend` 依赖 `capabilitiesCurrent`，不放松发送保护。
- 未引入 Room/HTTP 业务缓存；等 B0 证据再决定 V3 Stage 3。
