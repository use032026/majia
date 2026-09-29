# PaceJar · 节奏罐证据登记

生成时间：2026-09-29T18:00:00+08:00

## 源码身份

| Git root | Branch | SHA | Dirty state | 非 Git 替代证据 |
| --- | --- | --- | --- | --- |
| 无（工程不在 Git 仓库） | N/A | N/A | 无法得出 | 当前 `lib/test/ios/android` 全部普通文件按路径排序后逐文件 SHA-256 再聚合为 `2aaebdb956bd2ea8e8c69183fb6716ff6c0d5db93c028247a783f36ec60d8165`；无 commit 级可追溯性 |

## 证据层

| 层级 | 命令/设备/工件 | 结果 | 证明上限 | 原始证据路径 |
| --- | --- | --- | --- | --- |
| 静态 | Dart format check + `flutter analyze --no-pub` | passed | 不证明运行态 | `evidence/automation/20260929T175103+0800/` |
| 自动化 | `flutter test --no-pub --reporter expanded` | 29 passed | 不证明平台集成或真机 | `evidence/automation/20260929T175103+0800/flutter-test.log` |
| iOS 模拟器 | iPhone 17 Pro Max + iPad Pro 13-inch (M5), iOS 26.5 | passed for observed paths | 不证明真机/iOS 15/签名包 | `evidence/screenshots/`；`evidence/store-screenshots/` |
| 视觉/交互复核 | 创建→记录→恢复→时间线；中英文/深色；iPad 宽屏 | passed for observed states | 只证明已观察页面和动作 | `FUNCTIONAL_REVIEW.md` UI 矩阵 |
| 实体设备 | 未运行 | not_run | 不得宣称真机可用 | 无 |
| Android 构建 | Flutter 3.35.7 debug APK | passed | Debug APK 不是 Play release 工件 | `evidence/automation/20260929T175103+0800/android-debug-build.log` |
| iOS 15 定向构建 | Xcode Release、临时 DerivedData、`CODE_SIGNING_ALLOWED=NO` | passed；产物 plist 与 Mach-O 均为 15.0，加密标记 false | 不证明 iOS 15 真机或签名发行 | `evidence/automation/ios15-20260929T180240+0800/IOS15_VALIDATION.md`；临时 DerivedData 已清理 |
| iOS Archive | Xcode 26.5 / iOS SDK 26.5 / `--no-codesign` | passed；MinimumOSVersion 15.0 | Archive 不等于签名、上传、TestFlight | `build/ios/archive/Runner.xcarchive`；Flutter archive 输出 |
| 机械预检 | factory release preflight | blocked as expected | iOS 15、加密标记、图标/清单/截图通过；生产身份、URLs、签名阻断 | `evidence/automation/preflight-20260929T180000+0800/` |
| ASC/TestFlight/App Review | 用户明确禁止上传 | not_run | 无任何外部状态证明 | 无 |

## 最终工件

| 工件 | SHA-256 | 大小 | 生成时间 | 限制 |
| --- | --- | ---: | --- | --- |
| `build/app/outputs/flutter-apk/app-debug.apk` | `6eff90ba6fb7f3e0a26aef5f8df21fabf50244b9ab39deacd933e7226d1fade0` | 145,339,958 B | 2026-09-29 17:51 +08:00 | Debug only，非 Play 候选 |
| unsigned archive Runner binary | `ffeaa1f71649627b09bc5d49cee92160e34c5f036163ace1db9f61df839b5604` | 73,832 B | 2026-09-29 18:00 +08:00 | iOS 15.0；加密标记 false；无签名/无 profile/无 IPA |
| `docs/product/assets/pacejar-icon.svg` | `958e4d4fa1f813706f7d489d2d42f9a89360f43cdd96908ccd36a478243a5e97` | 522 B | 2026-09-29 17:40 +08:00 | 原创工程源图；1024/180px 已人工看图；商标可用性未验证 |
| iPhone/iPad store screenshot set | 见 preflight 哈希清单 | 6 PNG | 2026-09-29 | 尺寸/无 alpha 通过；未上传 |

## 明确缺失

- 真实唯一 Bundle ID、Apple Developer Team、App Store distribution certificate/profile、签名 archive/IPA。
- 公开可访问的隐私政策 URL 与 Support URL，负责主体/联系方式。
- ASC 记录、名称可用性/商标清查、分类、年龄分级、价格/地区、App Privacy 回答、完整中英元数据。
- 中国大陆发布所需的当前备案/合规证据。
- 真机、VoiceOver/TalkBack、最低系统、Xcode Privacy Report、网络行为和最终签名工件复核。
- 上传、ASC 处理、TestFlight 可用、提交审核和审核结果；本次未执行。
