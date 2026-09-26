import Foundation

/// 原型阶段的演示数据。模型列表取自 docs/compatibility-matrix.md 的实测结果。
enum DemoData {
    static func harnesses() -> [HarnessInfo] {
        [
            HarnessInfo(
                id: "claude-code",
                name: "Claude Code",
                isAvailable: true,
                note: nil,
                models: [
                    ModelInfo(id: "sonnet", name: "Sonnet 5"),
                    ModelInfo(id: "opus", name: "Opus 5.5"),
                    ModelInfo(id: "claude-fable-5-1", name: "Fable 5.1"),
                    ModelInfo(id: "haiku", name: "Haiku 4.5"),
                ],
                defaultModelID: "sonnet"
            ),
            HarnessInfo(
                id: "opencode",
                name: "OpenCode",
                isAvailable: true,
                note: nil,
                models: [
                    ModelInfo(id: "opencode/big-pickle", name: "Big Pickle"),
                    ModelInfo(id: "github-copilot/claude-sonnet-5", name: "Sonnet 5 · Copilot"),
                    ModelInfo(id: "github-copilot/gpt-5.5", name: "GPT-5.5 · Copilot"),
                ],
                defaultModelID: "opencode/big-pickle"
            ),
            HarnessInfo(
                id: "codex",
                name: "Codex",
                isAvailable: false,
                note: "第二阶段",
                models: [],
                defaultModelID: nil
            ),
        ]
    }

    static func repos() -> [String] {
        ["chatty", "runner", "docs"]
    }

    static func agents() -> [AgentConfig] {
        [
            AgentConfig(id: UUID(), name: "修 Bug 助手", harnessID: "claude-code", modelID: "sonnet", repo: "chatty"),
            AgentConfig(id: UUID(), name: "OpenCode 探索", harnessID: "opencode", modelID: "opencode/big-pickle", repo: "chatty"),
        ]
    }

    static func runner() -> RunnerInfo {
        RunnerInfo(name: "MacBook-Pro", address: "100.101.102.103", isConnected: true)
    }

    static func suggestions() -> [String] {
        ["修复失败的测试", "解释这个仓库的结构"]
    }

    static func sessions(now: Date = .now) -> [ChatSession] {
        [
            ChatSession(
                title: "修复登录 bug",
                repo: "chatty",
                harnessID: "claude-code",
                modelID: "sonnet",
                updatedAt: now.addingTimeInterval(-120),
                items: [
                    .notice("已切换引擎，上下文已通过摘要迁移"),
                    .user("修复登录 bug"),
                    .tools([
                        ToolStep(icon: "doc.text", title: "读取 src/auth/login.ts"),
                        ToolStep(icon: "magnifyingglass", title: "搜索 “refreshToken”"),
                        ToolStep(icon: "doc.text", title: "读取 src/auth/session.ts"),
                        ToolStep(icon: "pencil", title: "编辑 login.ts"),
                        ToolStep(icon: "pencil", title: "编辑 session.ts"),
                    ]),
                    .agent("问题在 token 过期后没有刷新。我改了 login.ts 和 session.ts，并补了一个测试。"),
                    .changes([
                        FileChange(path: "src/auth/login.ts", added: 18, removed: 4),
                        FileChange(path: "src/auth/session.ts", added: 9, removed: 3),
                        FileChange(path: "test/login.test.ts", added: 15, removed: 0),
                    ]),
                ]
            ),
            ChatSession(
                title: "重构 WebSocket 层",
                repo: "chatty",
                harnessID: "opencode",
                modelID: "opencode/big-pickle",
                state: .awaitingApproval,
                updatedAt: now.addingTimeInterval(-600),
                items: [
                    .user("把 WebSocket 重连逻辑抽成独立模块"),
                    .tools([
                        ToolStep(icon: "doc.text", title: "读取 src/gateway/ws.ts"),
                        ToolStep(icon: "pencil", title: "新建 src/gateway/reconnect.ts"),
                    ]),
                    .agent("重连逻辑已经抽出来了。我想跑一遍格式化，统一代码风格。"),
                ],
                approval: ApprovalRequest(title: "请求执行命令", command: "npx prettier --write src/gateway")
            ),
            ChatSession(
                title: "补充单元测试",
                repo: "runner",
                harnessID: "claude-code",
                modelID: "opus",
                updatedAt: now.addingTimeInterval(-86_400),
                items: [
                    .user("给状态机补充单元测试"),
                    .agent("已补充 24 个用例，覆盖所有状态转换。"),
                ]
            ),
            ChatSession(
                title: "Adapter 接口草案",
                repo: "runner",
                harnessID: "claude-code",
                modelID: "sonnet",
                updatedAt: now.addingTimeInterval(-90_000),
                items: [.user("起草 HarnessAdapter 接口"), .agent("草案已写入 src/harness/types.ts。")]
            ),
            ChatSession(
                title: "README 翻译",
                repo: "docs",
                harnessID: "opencode",
                modelID: "opencode/big-pickle",
                updatedAt: now.addingTimeInterval(-200_000),
                items: [.user("把 README 翻译成英文"), .agent("已完成，生成 README.en.md。")]
            ),
        ]
    }

    /// 演示用 diff，查看改动时展示
    static func sampleDiff() -> [(kind: Character, text: String)] {
        [
            (" ", "export async function login(credentials) {"),
            (" ", "  const session = await api.login(credentials)"),
            ("-", "  return session"),
            ("+", "  scheduleRefresh(session.expiresAt)"),
            ("+", "  return session"),
            (" ", "}"),
        ]
    }
}
