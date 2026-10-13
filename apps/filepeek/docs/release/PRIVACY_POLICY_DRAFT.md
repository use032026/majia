# FileRecheck 隐私政策草稿 / Privacy Policy Draft

状态：**仅供发布前核对，不可作为公开政策**。2026-10-13 将产品名更新为 FileRecheck，并移除外部分享导入。生效日期、负责法律主体、联系方式、公开 HTTPS 地址及适用地区法律审查尚未完成。以下数据流仍需以最终签名包、依赖清单和 Xcode Privacy Report 复核。

## 中文

FileRecheck 不要求注册或登录。用户选择的 JSON、CSV、TXT 和 LOG 文件在设备上读取、解析、搜索和编辑工作副本。本版本没有开发者自有服务器、广告或分析 SDK，也不在后台自动上传文件。

用户在应用内通过系统文件选择器提供文件。原文件不由 FileRecheck 覆盖。当前检查会话在应用内存中，关闭会话或应用后不会恢复；尚未导出的修改会在替换或关闭前提示。系统文件提供方（包括用户选择的云盘）、系统备份与用户主动选择的导出目标有各自的数据处理方式，FileRecheck 不控制这些服务。

用户主动导出副本或检查报告时，文件写入应用临时缓存并交给系统分享界面；应用下次启动会清理自己生成的旧导出文件。系统文件选择器或文件提供方可能创建本地临时副本；这些路径的最终清理和保留期必须在发行构建上验证后再对外承诺。检查报告包含文件名、类型、大小、行数、诊断和可选搜索词/JSON 差异路径，不包含 JSON 差异的前后值；用户应自行检查报告是否含敏感文件名或搜索词，再决定分享目标。

应用使用系统文件选择器，不请求广泛文件读取权限；Android 未声明 `MANAGE_EXTERNAL_STORAGE`。如用户不授予或取消选择，现有会话保留。删除应用通常会删除应用内本地数据；云端文件、系统备份和已分享副本按相应服务规则处理。

## English

FileRecheck does not require an account. It reads, validates, searches and edits working copies of JSON, CSV, TXT and LOG files on the device. This version has no developer-operated backend, advertising SDK or analytics SDK, and does not automatically upload files.

Files are supplied through the in-app system file picker. FileRecheck does not overwrite the source. The inspection session is held in memory and is not restored after the app closes. The app asks before discarding unapplied or unexported edits. A selected cloud file provider, system backup, and an export destination chosen by the user each operate under their own data practices.

When the user exports a working copy or report, FileRecheck writes a temporary file in its app cache and invokes the system share sheet. Old app-generated exports are cleared on the next launch. The system file picker or file provider may also create temporary local copies; their final retention and deletion behavior must be checked in the release build before publication. Reports include the file name, type, size, line count, diagnostics, and optional search terms or JSON difference paths, but not the compared JSON values. Users should inspect a report before sharing it.

FileRecheck uses system-scoped file access and does not request broad Android storage access. Cancelling a file selection keeps the current session. Uninstalling the app generally removes app-local data; cloud-provider content, system backups and previously shared copies follow the relevant provider's rules.

## 发布前必须补全 / Publication blockers

- 确认生产主体、隐私与支持联系人、政策生效日期及公开 HTTPS 页面；在应用内提供该政策的可访问入口。
- 对最终签名 iOS/Android 包生成依赖与隐私清单，核对 Apple App Privacy 和 Google Play Data safety 回答；确认文件选择器缓存清理行为及系统备份声明。
- 若未来加入服务器、分析、广告、账号或付费功能，先重新评估数据流与政策。
