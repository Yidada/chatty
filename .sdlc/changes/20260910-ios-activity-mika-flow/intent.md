# iOS：项目动态与连续交办

Benjamin 已确认精简交互方案，并明确要求先在 iOS 实现。解决两个问题：项目里的事项由不同人或 Agent 发起，单一聊天入口难以追踪；发送一条消息后输入和发送被锁住，无法继续交办。

交付行为：底部为动态 / Mika / 项目；右上角头像进入现有设置；动态提供新进展和待处理，覆盖工作区全部可访问事项；Mika 可选择项目，连续提交消息且不等待前一轮执行完成。

现状证据：WorkspaceTabs 仍为对话 / 项目 / 设置；ChatModel.canSend 排除 sending、pending.taskId；ChatScreen 在 sending 时禁用文本输入；后端支持 chat session project_id、supports_queue 和 queued_tasks。个人 Inbox 限制 recipient_id，不能独立满足全项目追踪。

本次先完成 iOS 开发和可复核验证。Android 保留现有改动，随后推进。TestFlight 延续此前用户授权，但当前 Apple 登录未完成，发布与本地验证分别记录。
