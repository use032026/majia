# Somniloquy 证据登记

生成时间：2026-10-08T16:24:00+08:00

## 源码身份

| Git root | Branch | SHA | Dirty state | 说明 |
| --- | --- | --- | --- | --- |
| `/Users/starburst/Downloads/app-ui-atlas/somniloquy` | `master` | 无提交（unborn branch） | 全部为本次新建、未提交 | 独立于外层 100 个概念页；没有远程、没有推送或上传 |

## 证据层

| 层级 | 命令/设备/工件 | 结果 | 证明上限 | 原始证据路径 |
| --- | --- | --- | --- | --- |
| 静态 | format + `flutter analyze` | passed | 不证明运行态 | `automation/20261008T162136+0800/` |
| 自动化 | 16 项单元/Widget/真实临时文件仓库测试 | passed | 不证明真实麦克风、后台或真机 | `automation/20261008T162136+0800/flutter-test.log` |
| iPhone 模拟器 | iPhone SE 3 / iOS 18.3；中文明暗、英文设置、短录音、停止、草稿恢复 | passed within inspected paths | 不证明实体设备锁屏/后台、最低 iOS 或整夜稳定性 | `runtime/iphone-se-*.png` |
| iPad 模拟器 | iPad Pro 11-inch M4 / iOS 18.3；中文 NavigationRail 入口 | passed within inspected page | 不证明所有平板状态 | `runtime/ipad-pro-11-zh-tonight.png` |
| 实体设备 | 未运行 | not_run | 无真机结论 | — |
| Android 构建 | debug APK | passed | Debug 不等于 Play release 或后台录音证明 | `build/app/outputs/flutter-apk/app-debug.apk` + 构建日志 |
| iOS Archive | release、`--no-codesign` | passed | 无签名 Archive 不等于可安装、上传或 TestFlight | `build/ios/archive/Runner.xcarchive` + 构建日志 |
| 发布机械预检 | 当前工程 + 无签名 Archive | blocked as expected | 只证明本地机械缺口 | `automation/preflight-20261008T162310+0800/` |
| ASC/TestFlight/App Review | 未执行 | not_run | 没有外部状态 | — |

## 最终工件

| 工件 | SHA-256 | 大小 | 限制 |
| --- | --- | ---: | --- |
| `assets/app_icon_1024.png` | `0e01bde05f61cd3cae9a6a9e5e23279b49ddd8924b2171badfcd6440393c6166` | 947,390 B | 生成源图；权利/商标仍待外部核验 |
| `build/app/outputs/flutter-apk/app-debug.apk` | `527ed851d2f3c8c72da860ecffdd0e62623e567929c1e199dec1731042cc0996` | 145,200,602 B | Debug only |
| iOS Archive Runner binary | `68b6de3a4ca00c29ea6196f6a0d88f429eb7b29e63de53ccdf13baf8bbad0b63` | 74,080 B | 无签名，非 IPA |
| `runtime/iphone-se-zh-tonight.png` | `9a026130a20984eaea8b0cc4f99a08f76d281654a8c0050f5f53c9d83ab6492a` | 115,208 B | 运行证据，不是商店截图 |
| `runtime/ipad-pro-11-zh-tonight.png` | `f06aac23bc7c09c695fa50da124352c7fb771bfc3189d126a6b483c01d7926e9` | 210,408 B | 运行证据，不是商店截图 |

## 明确缺失

- commit-level 源码身份和远程交付记录。
- 生产 Bundle ID、Team、签名、profile 与最终签名 Archive。
- 公开隐私政策/支持 URL、责任主体与联系邮箱。
- App Store Connect 元数据、隐私回答、年龄分级、截图、类别、出口合规和中国大陆备案状态。
- iOS 15+ 实体设备整夜后台/锁屏/中断/低存储/电池/温升/VoiceOver 证据。
- 最终 Archive Privacy Report、上传、处理、TestFlight 或 App Review 证据。
