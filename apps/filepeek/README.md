# FilePeek

离线优先的 Flutter 文件检查工具，支持 iOS 和 Android。通过系统“文件”选择器或分享入口读取 JSON、CSV、TXT、LOG；查看格式诊断、搜索内容，在工作副本中修正 JSON/CSV，比较两份 JSON，再主动导出副本或简短检查报告。无账号、开发者后台、分析或广告 SDK；不自动上传文件。

## 本地运行

需要 Flutter 3.35.7、Dart 3.9.2。iOS 工程在 Xcode 26.5 验证；Android 使用 compile/target SDK 36。

```sh
flutter pub get
flutter test
flutter run
```

核心逻辑位于 `lib/src/domain/filepeek_document.dart`；系统文件和分享入口位于 `lib/src/data/file_gateway.dart`；界面位于 `lib/main.dart`。测试覆盖格式边界、工作副本、错误与撤销、比较、分页、分享竞态及编辑草稿保护。

## 范围和限制

- 单文件最多 5 MiB、10,000 个实际文本行；CSV 最多 200 列。原文副本编辑最多 128 KiB，长内容分页显示。
- 读取 UTF-8（含 BOM）；其他编码和二进制会报错。源文件只读，导出由用户主动通过系统分享完成。
- `com.example.filepeek` 与 iOS App Group 仍为开发占位。图标由 `tool/generate_icons.py` 生成；发布前需确认正式名称、Bundle ID/包名、签名与隐私/支持页面。
- 本仓库的本地质量门禁和预检在 `docs/release`。通过测试或无签名 Archive 不代表商店已接收或审核；本次没有上传商店。
