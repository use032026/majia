# Fylto 隐私政策草稿 / Privacy Policy Draft

状态：**内部发布核对文档，公开政策以官网为准**。2026-10-13 将产品名更新为 FileRecheck，并移除外部分享导入；2026-10-21 将产品显示名更新为 Fylto。用户已确认运营主体为独立开发者，支持与隐私联系邮箱为 ashcar1986@icloud.com，生效日期为 2026-10-21，正式域名为 https://fylto1.com。以下数据流仍需以最终签名包、依赖清单和 Xcode Privacy Report 复核。

## 已确认信息 / Confirmed details

- 运营主体 / Operator：独立开发者 / Independent developer。
- 支持与隐私联系邮箱 / Support and privacy contact：ashcar1986@icloud.com。
- 生效日期 / Effective date：2026-10-21。
- 正式域名 / Production domain：https://fylto1.com。
- 中文政策 / Chinese policy：https://fylto1.com/privacy.html?lang=zh。
- 英文政策 / English policy：https://fylto1.com/privacy.html?lang=en。
- 支持页面 / Support：https://fylto1.com/#support。

## 中文

Fylto 不要求注册或登录。用户选择的 JSON、CSV、TXT 和 LOG 文件在设备上读取、解析、搜索和编辑工作副本。本版本没有开发者自有服务器、广告或分析 SDK，也不在后台自动上传文件。

应用内保留可离线阅读的隐私说明。只有用户点击“完整隐私政策”时，才通过系统浏览器视图打开与当前应用语言对应的官网政策页面；该请求不附带所选文件内容或检查报告。关闭浏览器视图可返回应用，无法打开时可重试或复制网址。

用户在应用内通过系统文件选择器提供文件。原文件不由 Fylto 覆盖。当前检查会话在应用内存中，关闭会话或应用后不会恢复；尚未导出的修改会在替换或关闭前提示。系统文件提供方（包括用户选择的云盘）、系统备份与用户主动选择的导出目标有各自的数据处理方式，Fylto 不控制这些服务。

用户主动导出副本或检查报告时，文件写入应用临时缓存并交给系统分享界面；应用下次启动会清理自己生成的旧导出文件。系统文件选择器或文件提供方可能创建本地临时副本；这些路径的最终清理和保留期必须在发行构建上验证后再对外承诺。检查报告包含文件名、类型、大小、行数、诊断和可选搜索词/JSON 差异路径，不包含 JSON 差异的前后值；用户应自行检查报告是否含敏感文件名或搜索词，再决定分享目标。

应用使用系统文件选择器，不请求广泛文件读取权限；Android 未声明 `MANAGE_EXTERNAL_STORAGE`。如用户不授予或取消选择，现有会话保留。删除应用通常会删除应用内本地数据；云端文件、系统备份和已分享副本按相应服务规则处理。

## English

Fylto does not require an account. It reads, validates, searches and edits working copies of JSON, CSV, TXT and LOG files on the device. This version has no developer-operated backend, advertising SDK or analytics SDK, and does not automatically upload files.

An offline privacy note remains available in the app. Only choosing “Privacy policy” opens the website policy in the current app language through a system browser view. The request does not include selected file contents or inspection reports. Closing the browser view returns to the app; a browser-launch failure allows retrying or copying the URL.

Files are supplied through the in-app system file picker. Fylto does not overwrite the source. The inspection session is held in memory and is not restored after the app closes. The app asks before discarding unapplied or unexported edits. A selected cloud file provider, system backup, and an export destination chosen by the user each operate under their own data practices.

When the user exports a working copy or report, Fylto writes a temporary file in its app cache and invokes the system share sheet. Old app-generated exports are cleared on the next launch. The system file picker or file provider may also create temporary local copies; their final retention and deletion behavior must be checked in the release build before publication. Reports include the file name, type, size, line count, diagnostics, and optional search terms or JSON difference paths, but not the compared JSON values. Users should inspect a report before sharing it.

Fylto uses system-scoped file access and does not request broad Android storage access. Cancelling a file selection keeps the current session. Uninstalling the app generally removes app-local data; cloud-provider content, system backups and previously shared copies follow the relevant provider's rules.

## 发布前必须补全 / Publication blockers

- 已记录正式域名及中英文 HTTPS 政策/支持页面；应用内入口已接入。提交时仍需把对应地址填写到商店字段，并以最终签名包复核入口。
- 对最终签名 iOS/Android 包生成依赖与隐私清单，核对 Apple App Privacy 和 Google Play Data safety 回答；确认文件选择器缓存清理行为及系统备份声明。
- 若未来加入服务器、分析、广告、账号或付费功能，先重新评估数据流与政策。
