# 旅程差额 / Trip Delta 证据登记

> 2026-10-14 更新说明：下方 2026-09 的 `app-ui-atlas` 路径和非 Git 状态是当时的来源记录。当前应用位于 `apps/trip_delta`；旧 Archive 与商店预检不代表本次版本。

更新时间：2026-09-21（Asia/Shanghai）。

## 源码身份

工程位于 `app-ui-atlas/trip_delta`；本目录及父目录均不是 Git 仓库，因此没有 branch/SHA/dirty-state 证明。`evidence/source-hashes.txt` 记录终版 Dart、测试、锁文件与 iOS 配置的 SHA-256，仅能定位本地文件。外部 TripCost 分支 SHA 见 `../product/MARKET_EVIDENCE.md`，本工程未借用其实现。

## 证据层

| 层级 | 操作与环境 | 结果 | 证明上限 | 原始证据 |
| --- | --- | --- | --- | --- |
| 静态 | Flutter 3.35.7、Dart 3.9.2；格式与 `flutter analyze --no-pub` | passed | 不证明运行态 | `evidence/automation/20260918T115136+0800/QUALITY_GATE.md` 与原始日志 |
| 自动化 | `flutter test --no-pub --reporter expanded`，10 项 domain/store/widget 测试 | passed | 不证明平台集成 | 同上 `flutter-test.log` |
| iOS Simulator 主路径 | iPhone 16 / iOS 18.3：创建 CNY 300 计划、锁定、记餐饮 CNY 350、复盘完成；切换中英；显示超 CNY 50 | passed（已操作路径） | 不证明真机 | `evidence/iphone16-empty-zh.png`、`evidence/iphone16-completed-en.png` |
| iOS 模拟器压力 | iPhone 16 深色及 accessibility-medium 现场目视；SE 3 / iOS 18.3 与 iPad Pro 11 M4 / iOS 18.3 注入 30 笔长标题/备注合成数据；平板详情滚动至中段 | passed（已观察区域） | 截图只证明所示区域；深色/大字未截图 | `evidence/iphone-se-stress-home-en.png`、`evidence/ipad11-stress-home-en.png`、`evidence/ipad11-stress-detail-en.png`、`evidence/runtime-stress-data.json` |
| 模拟器本地恢复 | iPhone 16 结束进程、重新安装并启动，英文设置及已完成旅程仍在 | passed（该设备） | 不证明卸载/系统备份/实体设备 | 现场观察；`test/store_test.dart` 覆盖文件读写与坏文件拒载 |
| Android 构建 | `flutter build apk --debug --no-pub` | passed | 非 Play 包；未运行 Android | `evidence/automation/20260918T115136+0800/android-debug-build.log` |
| iOS Simulator 构建 | `flutter build ios --simulator --no-codesign` 并安装到上述模拟器 | passed | 不证明 Release/真机 | `build/ios/iphonesimulator/Runner.app` 与上述截图 |
| iOS Archive | Xcode 26.5 / iOS 26.5 SDK；`flutter build ipa --release --no-codesign --no-pub` | passed（Archive），签名缺失 | 不证明 IPA/上传/TestFlight | `evidence/automation/20260918T115136+0800/ios-unsigned-archive.log` |
| 机械预检 | `flutter_release_preflight.py` 检查 ID、URL、签名、清单、截图及工件 | blocked | 脚本不作 Apple 政策判定 | `evidence/automation/preflight-20260918T115236+0800/RELEASE_PREFLIGHT.md` |
| 实体设备 / ASC / TestFlight / App Review | 未执行，用户要求不上架 | not_run | 无外部验收 | 无 |

## 2026-09-21 核心改版复验

| 层级 | 操作与环境 | 结果 | 证明上限 | 证据 |
| --- | --- | --- | --- | --- |
| 静态/自动化 | `dart format lib test`、`flutter analyze`、`flutter test --reporter expanded` | 0 分析问题，13 项测试通过 | 不证明平台集成或用户价值 | `test/domain_test.dart`、`test/store_test.dart`、`test/widget_test.dart` |
| iOS Simulator 实操 | iPhone 16e / iOS 18.3：当前行程首页直达，金额 JPY 1280，自动沿用 0.05 汇率，保存后已记录额、日均额和估算笔数更新 | passed（该路径） | 不证明实体设备、iOS 15、软件键盘或长期数据 | `evidence/iphone16e-revised-workbench-zh.png`、`evidence/iphone16e-revised-quick-expense-zh.png` |
| Android 构建 | `flutter build apk --debug` | passed | Debug APK，未运行 Android | `build/app/outputs/flutter-apk/app-debug.apk` |
| iOS 构建 | `flutter build ios --simulator --no-codesign`、`flutter build ipa --no-codesign` | Simulator App 和 Archive passed | Archive 未签名、无 IPA、未上传 | `build/ios/iphonesimulator/Runner.app`、`build/ios/archive/Runner.xcarchive` |
| Store 预检 | Archive 设置检查 | blocked | 占位 ID、默认图标/启动图、无签名及公开 URL 仍未关闭 | `APP_STORE_PREFLIGHT.md` |

## 2026-10-14 功能缺口补齐验证

| 层级 | 操作与环境 | 结果 | 证明上限 | 证据 |
| --- | --- | --- | --- | --- |
| 静态与自动化 | `flutter analyze --no-pub`、`flutter test --no-pub`、`git diff --check` | 分析 0 问题、28 项测试通过、差异检查通过 | 测试覆盖估算完成门禁、预算按实付复用、类别/日期筛选、备份格式、冲突与写入失败；不证明全部原生交互 | `test/backup_test.dart`、`test/domain_test.dart`、`test/store_test.dart`、`test/widget_test.dart` |
| iOS Simulator | iPhone 17 Pro / iOS 26.5 启动新版与备份页；空白 iPhone 16 Pro / iOS 18.3 经系统文件界面导出空备份，再选回并合并 | 启动、原生文件弹窗与空备份往返通过 | 非空真实数据的跨设备恢复、完整旅程手动操作与真机未检 | `evidence/iphone16pro-backup-import-en-20261014.png`；现场操作 |
| Android Debug 构建 | `flutter build apk --debug --no-pub` | passed | 未在 Android 设备运行，不证明文件选择交互 | `build/app/outputs/flutter-apk/app-debug.apk` |
| 分发/商店 | 未执行本次签名 Archive、上传或商店处理 | not_run | 无发布证明 | 无 |

## 最终工件

| 工件 | SHA-256 | 限制 |
| --- | --- | --- |
| `build/app/outputs/flutter-apk/app-debug.apk` | `1ecccb52008b383d4d0a62fff70afbad2e84ee35d94639019e852c439ec27f0e` | 2026-09-21 Debug，未运行 Android |
| `build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` | `a66a629dc0315563efb8b8b721edaac2f3ed9aa7bb26e7118b19609a25d5d428` | 仅 Mach-O 哈希；Archive 未签名 |
| `build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/App.framework/App` | `1565d70d977b2dc38c3bd34146e60c098a42432f964e735ea26acdad877c327a` | 2026-09-21 Flutter 应用代码二进制；Archive 未签名 |

完整哈希、字节数与截图尺寸见 `evidence/automation/preflight-20260918T115236+0800/release-preflight.json`。终版源码文件哈希见 `evidence/source-hashes.txt`。

2026-09-18 的旧截图边界保持不变；2026-09-21 两张新截图来自本次最终代码的小屏实操。新 PNG 为 1170×2532 且带 alpha，仅作工程证据，不可直接充当 App Store 素材。

## 明确缺失

正式 Bundle ID、原创图标、公开隐私政策和支持 URL、ASC 隐私回答、最终商店元数据/截图；签名 IPA 与 Xcode Privacy Report；真机、iOS 15、Android 运行、完整无障碍/横屏/后台/低存储矩阵。上传、处理、TestFlight 与 App Review 均未做。
