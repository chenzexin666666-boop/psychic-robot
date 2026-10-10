# 轻记 QingJi

iPhone 一键无感日记测试版（v0.3）。使用 iOS 26 SpeechAnalyzer 将语音实时转为中文文字，安静一段时间后自动保存；可附加照片，记录附带时间和时区。

- 录音只用于本机语音识别，不上传语音，不调用 AI。
- 日记文字和照片仅保存在 iPhone 本机 `Documents/QingJiData/`，此公开仓库不存放个人日记。
- 项目尚未通过 Mac/Xcode 和真机验证。
- 本仓库由云端 macOS 工作流编译**未签名的 IPA**，安装仍需用户自行签名。

云端 Actions: https://github.com/chenzexin666666-boop/psychic-robot/actions

安装时把 `qingji://capture` 绑定到 iPhone 的“快捷指令 → 打开 URL → 操作按钮”。iOS 不提供普通 App 读取操作按钮松开的事件，现以静音时长为自动结束条件。
