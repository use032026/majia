# FilePeek 证据登记

> 2026-10-21 产品显示名已统一为 Fylto；下述记录保留当时的名称与验证结果，不代表 Fylto 构建的运行证据。

> 历史证据登记：2026-10-13 更名为 FileRecheck，并移除文件分享导入。表内旧构建的分享扩展与 ACTION_SEND 证据不适用于当前版本。

记录时间：2026-10-12 18:47（Asia/Shanghai）。本表把代码、自动化、模拟器、发行包与商店状态分开；所有路径相对仓库根目录。

## 源码身份

| Git root | Branch | 受检代码 SHA | 记录时状态 | 范围 |
| --- | --- | --- | --- | --- |
| `filepeek/`（独立 Git 仓库） | `main` | `e728d35f6a17fe59a71d070809427f502f60ed4b` | 审核文档/截图证据待提交；预检 JSON 记录 dirty | 代码、平台配置与测试；报告提交单独进行 |

没有配置 Git 远端，也没有推送。最终质量门禁在这份代码及提交前的同内容 Swift 文件上运行；后续文档提交不改产品代码。

## 证据层

| 层级 | 实际操作与结果 | 证明上限 | 原始证据 |
| --- | --- | --- | --- |
| 静态 | 独立功能审核 `passed`；Store 审核 `blocked`；iOS 最低 15、Android 最低 API 24、target 36、iOS SDK 26.5 已从源码/Archive 核对 | 静态配置不证明真机与商店接收 | `docs/release/FUNCTIONAL_REVIEW.md`、`APP_STORE_PREFLIGHT.md`、`docs/release/evidence/automation/preflight-20261012T184717+0800/RELEASE_PREFLIGHT.md` |
| 自动化 | 格式、`flutter analyze`、35 项 Flutter 测试通过 | 不证明平台集成或真机 | `docs/release/evidence/automation/20261012T184622+0800/QUALITY_GATE.md`、同目录 `quality-gate.json` 和本地步骤日志 |
| iOS 模拟器 | iPhone 17 Pro/iOS 26.2：Files 导入、JSON/CSV/LOG 主流程、中英与深浅色、系统分享；iPhone 16 Pro/iOS 18.3：Files→分享扩展→手动返回/冷启动导入、App Group 待处理文件清理 | 仅证明这些模拟器、样本和路径；后者使用本地 ad-hoc 模拟器签名 | `docs/release/evidence/runtime/ios26-iphone17pro-app.png`、`ios-share-validation.md`、`ios-share-*.png` |
| Android 模拟器 | Pixel 7/API 35：系统文件选择 JSON、ACTION_SEND 导入 JSON/CSV/TXT、TXT 报告系统分享；PNG 留作运行证据 | 不证明 API 36、最低 API 24 或实体设备 | `docs/release/evidence/runtime/android-api35-*.png` |
| 视觉/交互复核 | iOS 中文浅色、英文深色，首屏/格式/错误/比较/导出状态已操作；Android JSON/CSV/TXT 和报告分享页已操作 | 未覆盖完整大字、VoiceOver/TalkBack、横屏或所有尺寸 | `docs/release/FUNCTIONAL_REVIEW.md` 与上述运行截图 |
| 实体设备 | `not_run` | 无实体设备结论 | 无 |
| Android 构建 | debug APK 成功 | 不是正式签名 AAB 或 Play 上传 | `docs/release/evidence/automation/20261012T184622+0800/QUALITY_GATE.md` |
| iOS Archive | iOS 无签名 Release Archive 成功，`DTSDKName=iphoneos26.5`；隐私清单可解析 | 不是可分发的签名 IPA，也不证明 Privacy Report 完整 | `docs/release/evidence/automation/preflight-20261012T184717+0800/RELEASE_PREFLIGHT.md` |
| ASC/TestFlight/App Review/Play | `not_run`；未登录、上传或提交 | 没有外部处理或审核结论 | 本次停止条件 |

## 本地工件

| 工件 | SHA-256 | 大小 | 修改时间 | 限制 |
| --- | --- | ---: | --- | --- |
| `build/app/outputs/flutter-apk/app-debug.apk` | `278ed5ec8caa39dadab23fb2698b4ea9cf0c49db96caa34e9333ff77407e33e4` | 170874512 B | 2026-10-12 18:46:31 +08:00 | 本地 debug，不可作为 Play 发行证明 |
| `build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` | `de6337d19dcd0708709bf5f6cc74ae144a00d71744efdd46f98163f9e32b28ad` | 96528 B | 2026-10-12 18:47:00 +08:00 | 仅主可执行文件 hash；Archive 目录整体未做哈希，未签名 |

完整工件清单、PNG 哈希与检查细节在 `docs/release/evidence/automation/preflight-20261012T184717+0800/release-preflight.json`。模拟器 PNG 含 alpha，被机械预检警告；它们未当作商店截图。`*.log` 默认被 Git 忽略；本次明确纳入初次 Android 失败日志和最终质量门禁五项日志，其余中间日志仅保留在本地证据目录。

## 明确缺失

生产身份、正式签名 IPA/AAB、公开隐私和支持 URL、最终商店截图与元数据、App Privacy/Play Data safety、实体设备与最低系统/API 36/辅助功能和 16 KB 验证、TestFlight/Play 轨道、上传处理与商店审核。
