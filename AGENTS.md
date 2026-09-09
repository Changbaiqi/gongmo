# 项目约定

## 工作流
- 完成任务后**不要**执行 `flutter build apk`（也不要 adb install）。用户自己负责构建和验证。
- 代码改完后运行 `flutter analyze` 确认无 error 即可。
- 用户使用中文交流，回复用中文。
- 含中文的源文件不要用 PowerShell `Get-Content`/`Set-Content`/`-replace` 管道修改（会乱码/破坏结构），优先用 Edit/Write 工具。
