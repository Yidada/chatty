# Plan
1. 检查 WorkspaceScreens.kt、ChatScreen.kt、ChatPresentation.kt、MainActivity.kt 全部浏览器出口。
2. 删除设置网页菜单和详情跳转，保留有原生能力的资源列表。移除无工作区时的网页引导。
3. 去除 Chat webUrl 传递及富内容外跳；Markdown 内部链接渲染为文本，统一浏览器出口拒绝 Multica 域名及当前 API 主机；图片增加原生预览。
4. 为链接边界补充单元测试；扩展合成真机断言，回归项目状态修改及对话。
5. 执行 source scripts/android-env.sh 后在 android/ 运行 ./gradlew testDebugUnitTest assembleDebug lintDebug；使用 -PchattyFixture=true 构建隔离测试包。
6. 运行 scripts/tabs-device-test.py、scripts/chat-device-test.py，证据写入 .sdlc/archive/iterations/v2/evidence/ 新目录。安装真实包，检查启动和原生设置，不发送真实消息或修改真实数据。
7. 自审并填 evidence/review/decisions，关闭 local 交付；本次不自动提交或推送。
