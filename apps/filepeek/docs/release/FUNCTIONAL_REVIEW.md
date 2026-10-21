# FilePeek 功能审核报告

> 2026-10-21 产品显示名已统一为 Fylto；下述记录保留当时的名称与验证结果，不代表 Fylto 构建的运行证据。

> 历史审核快照：2026-10-13 更名为 FileRecheck 后，用户决定暂不提供文件分享导入。下述分享入站测试与修复记录仅描述旧构建；当前版本只通过应用内系统文件选择器导入。

审核日期：2026-10-12。结论：`passed`，限于本地实现和已核对的 iPhone 模拟器流程；没有开放的已知 P0/P1。此结论不代表真机或商店审核通过。

UI/交互验收：`passed_with_limits`。iOS 26.2 上中文浅色、英文深色的核心页面与异常态已实际操作；Android API 35 上文件入站、内容页及报告分享已操作。完整无障碍、大字、横屏和实体设备矩阵留到发行候选验证。

## 审核发现与关闭

| 优先级 | 发现与影响 | 修复及证据 | 状态 |
| --- | --- | --- | --- |
| P1 | 已应用的工作副本在关闭或替换时可能丢失。 | 统一丢弃确认；widget 测试覆盖保留文件和继续导入。 | closed |
| P1 | 分享导入可覆盖原文编辑页尚未应用的草稿。 | 原文草稿纳入丢弃确认；保留后可继续应用，确认丢弃后关闭编辑页；两条 widget 测试覆盖。 | closed |
| P1 | 分享导入与异步比较/CSV 对话框相遇时，旧结果可能写入新会话。 | 会话 epoch 和文件身份守卫；widget 测试覆盖。 | closed |
| P1 | 只显示前 500 行/100 个 CSV 行，长文件尾部不可达。 | 分页、前后页及页码跳转；测试到达第 501 行和第 101 个 CSV 行并编辑导出。 | closed |
| P2 | iOS 智能引号会破坏手输 JSON。 | 原文编辑关闭智能引号、智能破折号与自动纠错；iPhone 模拟器确认直引号保持原样。 | closed |
| P2 | 恰好 10,000 行且以换行结尾的文件被误拒。 | 行数规则与 Dart LineSplitter 一致；测试覆盖末尾有/无换行及 10,001 行。 | closed |
| P2 | 原文编辑中的多字节文本可超过 128 KiB 后无法再编辑。 | 应用时按 UTF-8 字节数检查，超限留在编辑页；widget 测试覆盖。 | closed |
| P2 | 取消原文草稿或系统返回可能静默丢失内容。 | 取消确认、PopScope 保护返回；widget 测试覆盖取消/保留。 | closed |
| P2 | JSON 的 null 与字段不存在混淆；报告写入比较值。 | 区分 missing/null；报告只保留差异种类和路径；domain 测试覆盖。 | closed |
| P2 | Android 系统分享表显示时间戳前缀，干扰报告文件名。 | 唯一性放进临时子目录，输出使用简洁文件名；API 35 模拟器复测显示 `filepeek_report.txt`。 | closed |
| P2 | iOS 分享扩展调试日志包含来源文件名和可能含路径的错误。 | 删除文件名与错误文本日志；保留不含文件信息的保存成功事件。 | closed |

## 核心闭环

| 环节 | 结论与边界 |
| --- | --- |
| 输入/取消/失败 | iOS Files 选择器实测导入 JSON、CSV、LOG；iOS 18.3 分享扩展从 Files 保存带空格文件名的 JSON，主 App 从后台返回与冷启动均读到正确内容并清理 App Group 待处理文件。Android API 35 系统选择器导入 JSON，系统文件管理器分享 JSON/CSV/TXT 到 FilePeek 成功。取消及无效 UTF-8 保留当前会话由 widget/domain 测试覆盖。 |
| 检查与处理 | JSON 格式化、诊断、结构差异；CSV 表格、筛选、编辑；LOG 级别着色和搜索在模拟器实测。TXT、极限边界和错误格式由自动化测试覆盖。 |
| 确认与撤销 | CSV 编辑、原文修正、未导出修改替换确认、原文草稿取消确认及撤销由自动化测试覆盖；CSV 修改在模拟器可见。 |
| 自动复检 | 原文修改后重新解析，错误 JSON 修复后状态转为有效；widget 测试覆盖。 |
| 数据保留/删除 | 工作副本仅在会话内存；原文件不覆盖。关闭后失去未导出状态，这是界面说明和确认路径，不提供跨启动恢复。缓存导出在下次启动清理。 |
| 输出/分享 | iOS 模拟器确认系统分享表可打开 LOG 副本和 TXT 检查报告；Android API 35 模拟器确认 TXT 检查报告可打开系统分享表。自动化测试核对导出字节、文件名及报告语言。 |
| 本地化与视觉 | iPhone 17 Pro/iOS 26.2 实测中文浅色、英文深色：首屏、JSON/CSV/LOG、错误态、比较结果、底部导出均可读和可触达。Android API 35 验证文件导入、JSON/CSV/TXT 检查页及报告系统分享。完整 Dynamic Type、VoiceOver/TalkBack 与横屏未验证。 |

## 自动化与平台层

- `docs/release/evidence/automation/20261012T184622+0800/QUALITY_GATE.md`：最终源码的格式检查、`flutter analyze`、35 项 Flutter 测试、Android debug APK 构建、iOS 无签名 Archive 均通过。
- iOS 模拟器：iPhone 17 Pro，iOS 26.2，Xcode 26.5；Files 导入与系统分享、中文/英文、浅色/深色在 2026-10-12 人工操作检查。观察过程的截图在工具会话中，未保存为商店素材。
- Android 模拟器：Pixel 7/API 35；系统选择器导入 JSON，系统文件管理器通过 ACTION_SEND 分享 JSON、CSV、TXT 后，主应用分别显示正确文件名、字节数与检查结果。TXT 报告可打开系统分享表。截图：`docs/release/evidence/runtime/android-api35-json-share.png`、`android-api35-csv-share.png`、`android-api35-txt-share.png`、`android-api35-report-share.png`。没有把模拟器截图作为商店素材。
- iOS 分享扩展：iPhone 16 Pro/iOS 18.3 模拟器，从 Files 分享 JSON，经扩展保存并提示手动打开 FilePeek。后台返回及冷启动两种路径均读到正确文件名和内容，待处理键与临时副本已清理。截图：`docs/release/evidence/runtime/ios-share-saved-open-app.png`、`ios-share-resume-import-space-name.png`、`ios-share-cold-start-import.png`。没有把模拟器截图作为商店素材。
- 已知 P2 边界：iOS 分享待处理副本在读取后即清理，用户拒绝替换时需从 Files 重新分享；若文件提供方不返回大小元数据，扩展先复制再检查 5 MiB。不同云文件提供方及低存储场景需真机复测。
- 未验证：Android API 36 运行设备、iOS/Android 实体设备、最低系统机型、低内存/低存储、完整辅助功能和大字矩阵、签名 Release、TestFlight 或商店审核。
