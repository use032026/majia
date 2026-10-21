# Fylto App Review Notes 草稿

状态：**不可提交**。基于 2026-10-12 本地构建，2026-10-13 将产品名更新为 FileRecheck，并移除外部分享导入；2026-10-21 仅将产品显示名更新为 Fylto；名称可用性、生产身份、签名包、附件示例文件和 ASC 元数据仍未最终确认。

## 审核者可执行的路径

1. 首屏选择“打开文件 / Open file”，从系统 Files 中选择一份 UTF-8 的 `.json`、`.csv`、`.txt` 或 `.log` 文件。应用不需要登录、网络、设备配件或购买。
2. JSON：导入 `{"status":"ready","count":1}` 保存成的 `.json` 文件；选择“格式化 JSON / Format JSON”，观察工作副本状态，再选择“撤销 / Undo”。对一份第二 JSON 使用“比较 JSON / Compare JSON”，可见新增、删除及值变化的路径。
3. CSV：导入含表头的 `name,status\nAlice,ready\nBob,warning` 文件；搜索 `warning`，点击单元格并修改工作副本，然后通过“导出副本 / Export copy”打开系统分享界面。原文件不会被覆盖。
4. LOG：导入 `INFO started\nWARN delayed\nERROR failed`；搜索 `ERROR`，查看按级别着色的行。选择“检查报告 / Report”可预览本机生成的报告；返回不会导出，只有点击预览页“导出报告 / Export report”才打开系统分享界面。
5. 错误与恢复：导入语法错误的 JSON，页面会显示位置；“编辑原文副本 / Edit raw copy”修正后重新检查。关闭或替换已修改副本会要求确认。

仓库中的 `docs/release/review_samples/` 已备好不含真实用户数据的示例。正式提交时仍需通过 App Review 附件或应用内样本入口让审核者取得；当前应用没有内置样本，故这份草稿尚不能视为充分的审核访问证明。

## 功能与数据

- 核心用途：在移动端临时检查小型技术文件，保留源文件，处理并验证工作副本，主动导出副本或检查摘要。
- 格式和上限：JSON/CSV/TXT/LOG、UTF-8、5 MiB/10,000 行、CSV 200 列、原文编辑 128 KiB；超限有明确提示。
- 没有账号、开发者服务端、广告、分析 SDK、IAP 或订阅。系统 Files 文件提供方和用户主动分享目的地可能使用网络。
- 文件选择仅在用户点击“打开文件”时打开；无广泛 Android 存储权限。当前应用不接收其他应用的文件分享，用户主动导出仍打开系统分享界面；正式签名包及真机仍需复验。

## 发行前核对

本地门禁已经完成，但 iOS 仅有无签名 Archive，Android 仅有 debug APK；没有 TestFlight、ASC 上传处理或 App Review 记录。最终 Notes 必须按实际签名包重写版本、设备、示例附件、修复项、已知限制以及审核联系人，不能把本草稿直接粘贴到 ASC。
