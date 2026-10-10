# Almanac 证据登记

生成时间：2026-10-10T16:10:49+08:00

## 源码身份

| Git root | Branch | SHA | Dirty state | 非 Git 替代证据 |
| --- | --- | --- | --- | --- |
| 无 | — | — | — | 独立目录 `/Users/starburst/Downloads/app-ui-atlas/almanac`；质量报告、工件 SHA-256 与生成时间见下 |

缺少 commit-level 可追溯性是发布警告；本次没有把目录初始化为 Git 仓库，也没有改动父工作区的其他概念文件。

## 证据层

| 层级 | 命令/设备/工件 | 结果 | 证明上限 | 原始证据路径 |
| --- | --- | --- | --- | --- |
| 静态 | format + analyze | passed | 不证明运行态 | `docs/release/evidence/automation/20261010T155447+0800/` |
| 自动化 | Flutter tests，23 项 | passed | 不证明平台集成或实体设备 | 同上 `flutter-test.log` |
| iOS 模拟器 | iPhone 16 Pro、iPad Pro 11/13-inch M4，iOS 18.3 | passed for observed paths | 不证明实体设备或 iOS 15 | `docs/release/evidence/ui/ios-*` |
| Android 模拟器 | Pixel 7，Android 15 API 35 | launch passed | 只证明启动页与当前运行态 | `docs/release/evidence/ui/android-api35-en-light-welcome.png` |
| 视觉/交互复核 | 中英文、浅深色、首次/封笺/回看/笺册/设置、iPad 宽屏 | passed for observed matrix | 不覆盖完整 Dynamic Type、横屏、读屏 | `docs/release/FUNCTIONAL_REVIEW.md` |
| 实体设备 | 未执行 | not_run | 无实体设备结论 | — |
| Android 构建 | debug APK、release APK、release AAB | build passed; release signing blocked | AAB/APK 使用 debug cert，不是 Play candidate | `build/app/outputs/` |
| Android 包检查 | min 24 / target 36；arm64-v8a + x86_64；release APK 16 KB zipalign | passed | 未在 16 KB emulator/Play Console 验证最终交付拆分包 | 本报告与终端记录 |
| iOS Archive | Xcode 26.5 / iOS SDK 26.5 / min iOS 15，unsigned | build passed; signing blocked | 不证明安装、上传或审核 | `build/ios/archive/Runner.xcarchive` |
| ASC/TestFlight/Play/App Review | 未执行 | not_run | 无外部状态结论 | — |

## 最终工件

| 工件 | SHA-256 | 大小 | 限制 |
| --- | --- | ---: | --- |
| `build/app/outputs/bundle/release/app-release.aab` | `9d5d2d6fb0ea99dfb257b1c9040e45be2b1cb3d9710fba4edf8e647e1dfd65a3` | 41,490,483 | Debug certificate；不可上传生产 |
| `build/app/outputs/flutter-apk/app-release.apk` | `267b6da7d57015c09db5c3f8d3be51ab3d7b3ae7acdaace7e087303372b2b92c` | 约 48 MB | Debug certificate；仅本地验证 |
| iOS archive executable | `14ed5fe766ef065df2c4c70c8d9cee3be93da81d3940238c768f89ce2e4a3cb0` | 73,832 | Archive 未签名、无 profile |
| `assets/branding/app_icon.svg` | `51c6e0028dcc0dc5851d0b6851d234db027f6cb13aff027c7d7920161cf52795` | 604 | 源资产 |
| iOS 1024 icon | `2d9dd46bac9c5f5b5f944b1c8bd9266bf9bb0bd26cb517d314f043a4bcb449d9` | 13,442 | 1024×1024、无 alpha |

截图候选已转为无 alpha PNG，尺寸为 iPhone `1206×2622`、11 英寸 iPad `1668×2420` 与 13 英寸 iPad `2064×2752`，位于 `docs/release/evidence/store-screenshots/`。它们来自模拟器 debug 构建，不是最终签名归档的逐像素来源证明。

## 明确缺失

- 生产 Bundle/Application ID、Apple Team/profile/signature、Android upload/release key。
- 开发者法定主体、可监控联系邮箱、公开且稳定的隐私政策与支持 HTTPS URL。
- 商标/名称检索、最终类目、年龄分级、App Store/Play 元数据与隐私表单。
- 中国大陆发行主体与许可/备案判断。
- 实体设备、最低系统、完整辅助功能与最终签名构建截图。
- 上传、处理、TestFlight/内部测试、审核或发布状态。
