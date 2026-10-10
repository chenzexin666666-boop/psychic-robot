# 轻记 QingJi（iPhone 测试版）

已上传可通过 GitHub Actions 云端 macOS 编译的**精简原型**（不是先前 v0.3 ZIP 的逐文件镜像）。

功能：iPhone 打开 App 或通过 `qingji://capture` 进入速记；中文语音实时显示；连续静音约 5 秒自动保存；延迟约 3 秒收起；可从照片库附图。记录包含系统时间戳，本地 `Documents/journal.json` 和照片，不上传到 GitHub，也不接 AI。

技术：SwiftUI + Apple Speech（SFSpeechRecognizer）+ XcodeGen。语音是否完全离线取决于设备是否支持本地识别。不保证 iPhone 操作按钮松开后立即结束，按键释放事件并不开放给普通 App。

**当前状态：源码与工作流已上传，云端 Xcode 编译和 iPhone 真机安装仍需验证。** 编译成功后 Actions → Build QingJi iOS → Artifacts → `QingJi-unsigned-IPA` 下载，Windows 可用 Sideloadly 自行签名安装。

完整、功能更多的 v0.3 项目源码仍保留在此前对话提供的 ZIP 包里。
