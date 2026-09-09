# 实施决策

- 延续已批准的 SwiftUI / iOS 26+ / P1-P5 本地客户端范围。普通包使用 https://api.multica.ai/；Fixture 独立 bundle、源码组、Keychain service 和目录。
- 复用 Android 与 Multica 1cc46b269 的协议语义。iOS fixture 包装现有脚本，为两个账号、两个工作区、上传与异常增加独立状态；未修改 Android 实现或原 fixture。
- 每个工作区持有不可变 APIClient；切换时取消旧请求、Socket 和轮询。generation 与 context.active 双重阻止迟到结果。写请求不自动重试。
- 发送前持久保存待确认状态；回执合法后清除。附件只有 receipt 明确确认的 ID 才移除，缺失字段不猜测绑定。
- 冷启动离线恢复保存凭据哈希与最少作用域元数据，才能定位本机草稿；不保留 token、历史消息或离线权限。服务恢复后必须重新读取账号/工作区/Agent。
- 模拟器执行从无签名改成本地 ad-hoc 签名，因为实际运行验证发现未签名宿主的 Keychain 写入失败。正式 iPhone 编译检查仍可无签名；设备安装需要用户选定 Team。
- 使用确定性 Python 生成 Xcode 工程，避免依赖机器上的未安装项目生成器。工程、scheme、配置和包锁文件保留在 ios/。
- HTML/SVG/Mermaid 等主动内容只显示源码或文本；文件经过大小限制、同源凭据规则与保护目录后使用系统预览/分享。图片采用受限缩略图与系统缩放容器。
- iOS Simulator 不暴露物理文件保护属性。相应 XCTest 明确 skip，保留真实 iPhone 检查；不以模拟器通过宣称文件加密已在真机验证。
- 回放使用稳定 accessibility ID 和明确内容条件；去掉录制器易随系统变化的 UIKit 祖先层级绑定。最终回放结果单独保存。
- 本次自行检查实现和 diff；未使用独立审查 Agent。未提交、推送、发布应用，也未发送真实测试消息或修改真实 Issue。

- 前台刷新只由当前可见的项目、Issue 和资源页面触发；隐藏页面取消刷新任务。
- 仅 Fixture target 开放 Documents 文件共享，用于原生 Files 合成导入验证；普通 Release 不开放此权限。
- 原生后台验证发现 WebSocket 优雅关闭会残留服务端连接。实时连接改为独立 ephemeral URLSession，stop 时立即 cancel 并 invalidateAndCancel；REST 会话保持独立。修正后的后台连接数为 0，后续恢复重新认证。
