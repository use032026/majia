# Somniloquy App Store 预检报告

审核日期：2026-10-08
范围：本地源码、16 项自动化、iPhone/iPad 模拟器目视、Android debug APK、iOS 无签名 Archive、当前 Apple 官方规则。未检查实体设备、App Store Connect 实际记录、签名上传、处理、TestFlight 或审核。

结论：`blocked`。MVP 功能审核通过，但当前不是可提交 App Store 的发布候选；本次没有上传或提交。

## 阻断与风险

| 优先级 | 阻断/风险 | 当前证据 | 进入下一门禁的验收条件 | 状态 |
| --- | --- | --- | --- | --- |
| P0 | 生产身份与签名缺失 | Bundle ID 为 `com.example.somniloquy`；Archive 明确无签名和 provisioning profile | 提供生产 Bundle ID/Team/App ID/profile，生成并验证 Distribution Archive | open |
| P0 | 公开隐私政策与支持入口缺失 | 仅有本地草案，无稳定 HTTPS URL；应用内无可点击政策入口 | 发布可访问页面，补齐责任主体/联系信息，并在应用内与 ASC 填写 | open |
| P0 | App Store Connect 配置未建立/未核 | 无名称保留、SKU、类别、年龄分级、App Privacy、中英文元数据、截图或审核备注外部证据 | 完成并逐项与最终构建核对；中国大陆发行时同时核验备案字段与可用地区 | open |
| P1 | 真机整夜录音证据缺失 | 模拟器短录音通过；12 小时上限仅静态/短时验证 | iOS 15+ 实体机覆盖锁屏、后台、中断、低存储、发热、电量、删除和 12 小时自动停止 | open |
| P1 | 最终 Archive 隐私/依赖证据缺失 | 无签名 Archive 中隐私清单可解析，嵌入 5 个 framework | 对最终签名 Archive 导出 Privacy Report，复核 SDK 清单、Required Reason API 和无外传事实 | open |
| P1 | 名称与素材权利链未完成 | 图标原创生成且技术检查通过；无商标/名称检索记录 | 完成 Somniloquy 名称、图标、字体与所有商店素材的权利核验并留档 | open |
| P2 | 当前截图不能作为商店素材 | 目视截图带 alpha，且 iPhone SE/iPad 运行证据并非最终商店规格 | 用最终签名构建按当前 ASC 设备规格生成无 alpha 中英文截图 | open |

## 规则矩阵

| 当前规则 | 结论 | 本地证据 | 外部/缺口 |
| --- | --- | --- | --- |
| [2.1 App Completeness](https://developer.apple.com/app-store/review/guidelines/) | blocked | 核心闭环、错误恢复、删除和双语已通过静态/自动化/模拟器 | 无签名候选、真机审核路径与最终审核备注 |
| 2.3 Accurate Metadata | blocked | 应用内坚持“候选 + 人工确认 + 非医疗 + 本地保存” | ASC 名称、副标题、描述、关键词、截图、年龄分级均未验证 |
| 3.1 Payments | N/A for current build | 无 IAP、订阅或外部数字解锁 | 商业模式变化需重新审核 |
| 4.1 Copycats / 5.2 IP | conditional pass | 未复制参考产品名称、文案、图标、评分或趋势流程；原创图标 | 名称/商标及完整素材权利证明待补 |
| 4.2 Minimum Functionality | conditional pass | 录前提示 → 本地录音 → 候选 → 人工标注 → 晨间笔记 → 卡片/背景回看 | 真机可靠性待证明 |
| 4.3 Spam | medium risk | 差异化闭环不依赖离线/无账号本身 | 商店素材必须突出人工确认与夜间记忆，而非泛化“睡眠监测” |
| 4.8 Login Services | N/A | 无账号和第三方登录 | 若引入账号需重新审核 |
| [5.1 Privacy](https://developer.apple.com/app-store/app-privacy-details/) | blocked | 权限即时触发、同室人员确认、删除、备份边界与非上传文案成立 | 公开政策/支持 URL、ASC 隐私回答、最终 Privacy Report 缺失 |
| 1.4.1 Health claims | conditional pass, drift risk | 明确不检测鼾症、呼吸暂停、睡眠阶段或睡眠质量 | ASC 文案/关键词不得改成诊断、准确率或治疗主张 |
| 2.5.14 Recording consent/indicator | static pass, device pending | 同意后才请求麦克风；应用中有文字 + 红点录音状态 | 锁屏、后台和中断时的系统/应用指示待真机 |
| 2.4.2 / 2.5.4 Battery/background | high-risk pending | `audio` 后台模式用于核心录音；12 小时上限；提示稳定通风表面且禁止枕下/床垫下 | 需真机电量、热量、空间和音频中断报告 |
| [当前提交工具链](https://developer.apple.com/news/upcoming-requirements/) | local toolchain pass | Xcode 26.5、iOS SDK 26.5、最低 iOS 15.0 | 最终上传产物及 ASC 接收仍未验证 |

## 身份、隐私与依赖观察

- 版本：`1.0.0 (1)`；最低 iOS：15.0；Bundle ID：占位 `com.example.somniloquy`。
- `NSMicrophoneUsageDescription` 有中英文资源；`UIBackgroundModes` 仅声明 `audio`；`ITSAppUsesNonExemptEncryption=false`。
- 应用隐私清单声明无追踪、无收集；无签名 Archive 中 Flutter、`path_provider_foundation`、`record_ios` 隐私清单均可解析。
- Archive framework：`App`、`Flutter`、`audioplayers_darwin`、`path_provider_foundation`、`record_ios`。清单存在不等于最终 Privacy Report 已通过。
- 1024×1024 AppIcon 无 alpha；19 个 iOS 图标声明项均有文件。原创图由内置图像生成生成，权利/商标清查仍是外部事项。
- 机械预检：`docs/release/evidence/automation/preflight-20261008T162310+0800/RELEASE_PREFLIGHT.md`，结论 `blocked`；明确阻断为占位身份、URL 缺失和无签名。

## 当前官方依据

访问日期均为 2026-10-08：

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [提交前完整性检查](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/)
- [麦克风用途说明](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription)
- [Privacy Manifest](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Required Reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [第三方 SDK 要求](https://developer.apple.com/support/third-party-SDK-requirements/)
- [App Privacy 申报](https://developer.apple.com/app-store/app-privacy-details/)
- [出口合规](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- [ASC App 信息及中国大陆备案字段](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)

本报告不是 Apple 审核结论。Archive、上传、处理、TestFlight 可用与 App Review 是彼此独立的证据层。
