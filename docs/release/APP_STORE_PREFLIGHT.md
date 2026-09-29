# PaceJar · 节奏罐 App Store 预检报告

审核日期：2026-09-29

范围：当前本地源码、29 项自动化测试、iPhone/iPad 模拟器路径、Android Debug APK、Xcode 26.5 生成的 iOS 26.5 SDK 无签名 Archive、隐私清单和候选截图。未覆盖实体设备、最终签名包、App Store Connect、TestFlight 或 App Review。

结论：`blocked`。MVP 功能审核已通过，本地质量门已通过，但当前包不是可提交候选；不得把本结论描述为“可上架”或“Apple 已接受”。本次按用户要求未上传 App Store。

## 阻断与风险

| 优先级 | 阻断/风险 | 当前证据 | 进入下一门禁的验收条件 | 状态 |
| --- | --- | --- | --- | --- |
| P0 | `com.example.paceJar` 为占位 Bundle ID | 新 archive 与 Xcode 工程一致，但预检明确标记 placeholder | 选择唯一生产 ID，并与 RunnerTests、签名和 ASC 记录一致 | open |
| P0 | 无 App Store Distribution 签名或 embedded profile | `codesign --verify` 返回未签名；archive 仅为 `--no-codesign` | 最终 archive 校验通过，Team/profile/entitlements/有效期与发行方式匹配 | open |
| P0 | 无公开 Privacy Policy URL 与 Support URL | 只有本地隐私草案；机械预检两项均 blocker | 两个 HTTPS 地址无需登录即可访问，内容、主体和联系信息与最终构建一致 | open |
| P0 | 工作名与权利未清查 | `PaceJar · 节奏罐`、图标和商店名称没有商标/名称证据 | 完成名称、商标、域名和图标权利记录，确认最终商店名 | open |
| P1 | 未生成最终 ASC 元数据和 App Privacy 回答 | 本地仅有审核备注/隐私草案和候选截图 | 中英文描述、关键词、年龄分级、分类、地区、隐私回答与最终构建一致 | open |
| P1 | 无真机、最低 iOS 15、VoiceOver/TalkBack 与网络行为证据 | 仅 iOS 26.5 模拟器与 Widget 大字证据 | 在最终签名候选上验证核心闭环、后台恢复、剪贴板、删除和辅助功能 | open |
| P1 | 金融类表述边界 | 当前实现只做手动本地计划，但金额/储蓄语言可能触发更严格审阅 | 元数据持续明确“不连接银行、不转移/托管资金、不提供建议或收益” | open |
| P2 | 截图集来源与覆盖有限 | 6 张 PNG 的尺寸和无 alpha 通过；英文缺 iPad 完整组，中文时间线含用户输入的英文备注 | 从最终签名源码身份重拍中英 iPhone/iPad 完整组并做内容审校 | open |
| P2 | 启动画面、图标与本地化声明 | 品牌启动页替换模板；1024 图标人工复核且无 alpha；archive 含 `en`/`zh-Hans` | 最终签名 archive 再次复核资源目录与启动体验 | closed locally |

## 规则矩阵

| 当前规则与官方链接 | 适用性 | 结论 | 本地证据 | 外部证据 | 缺口 |
| --- | --- | --- | --- | --- | --- |
| [2.1 App Completeness](https://developer.apple.com/app-store/review/guidelines/#app-completeness) | 核心流程、崩溃、占位内容 | high risk | 功能审核 passed；质量门 passed；启动模板警告已消除 | 无真机/最低系统/最终签名/ASC | 补最终候选的设备矩阵与完整提交资料 |
| [2.3 Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata) | 名称、截图、描述、构建身份 | blocked | 截图尺寸/alpha 与版本号通过；图标现已完整可见 | 无正式 ID、URLs、ASC 字段、最终截图来源 | 建立生产身份与完整中英元数据 |
| [3.1 Payments](https://developer.apple.com/app-store/review/guidelines/#payments) | 免费应用、无数字内容购买 | pass for current scope | 无 IAP、订阅、付费入口或外部购买引导 | ASC 价格仍未配置 | 若变现变化必须重审 |
| [3.2.1(viii) Financial Services](https://developer.apple.com/app-store/review/guidelines/#financial-services) | 储蓄金额与金融语言 | review required | 本地手动记录；无银行连接、资金托管/转移、信贷、投资或建议 | Apple 对最终元数据的分类判断未知 | 保持工具边界，避免金融服务/收益承诺 |
| [4.1 Copycats](https://developer.apple.com/app-store/review/guidelines/#copycats) | 参考产品存在 | review required | 双轨节奏、恢复决策、版本时间线与 Loot 的储蓄罐呈现不同；未打包竞品素材 | 名称/图标商标清查缺失 | 归档权利和独立设计证据 |
| [4.2 Minimum Functionality](https://developer.apple.com/app-store/review/guidelines/#minimum-functionality) | 是否只有网页/模板/静态内容 | pass for local candidate | 离线可写数据、重算、恢复策略、版本历史、删除与复制输出 | 无 App Review | 最终包保持全部本地功能 |
| [4.3 Spam](https://developer.apple.com/app-store/review/guidelines/#spam) | 储蓄类同质化 | review required | 差异化内部评分 4.0/5，非换皮；单目标恢复闭环可操作 | 类目拥挤度与开发者其他 App 未核 | 商店页突出恢复策略与不可改写历史 |
| [4.8 Login Services](https://developer.apple.com/app-store/review/guidelines/#login-services) | 第三方登录要求 | not applicable | 无账号、无登录 | 无 | 后续加入登录需重新评估 |
| [5.1 Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy) | 本地财务相关输入、隐私 URL/问卷 | blocked | App manifest 声明不跟踪/不收集；UserDefaults 理由 `CA92.1`；无敏感权限 | 无公开政策、ASC 问卷、最终 Privacy Report | 发布政策、完成问卷并以最终 archive 生成报告 |
| [5.2 Intellectual Property](https://developer.apple.com/app-store/review/guidelines/#intellectual-property) | 名称、图标、文案与竞品参考 | review required | 自制 SVG/界面/文案；竞品素材只用于研究 | 无商标或名称清查 | 发布前完成人工权利复核 |
| [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/) | 提交 SDK 与平台基线 | pass for local SDK, recheck at submission | archive: Xcode 26.5、`iphoneos26.5`、最低 iOS 15.0；Mach-O `minos 15.0` | 提交日期的有效门槛可能变化 | 上传前重新打开官方页面并重建 |

## 身份、隐私与依赖观察

- Bundle/签名：版本 `1.0.0 (1)`、最低 iOS 15.0；Bundle ID 仍为占位值；Archive 未签名、无 provisioning profile。
- 加密出口声明：最终 Archive 的 `ITSAppUsesNonExemptEncryption` 为布尔 `false`（plist 中等价于 `NO`）。
- 本地化：Archive 的 `CFBundleLocalizations` 包含 `en` 与 `zh-Hans`；用户输入内容不会因语言切换被翻译。
- 数据流：SharedPreferences JSON 保存目标、事件、计划版本和显示偏好；主动复制时写系统剪贴板。未发现账号、后台、银行、广告、分析或网络功能。
- 依赖：Archive 仅列出 App、Flutter、`shared_preferences_foundation` frameworks。依赖清单不是运行时无网络证明。
- Privacy manifests：App、Flutter 和 shared_preferences manifests 均可解析；App 声明无 tracking、无 collected data，并为 UserDefaults 使用 `CA92.1`。最终仍须核对 [Privacy manifests](https://developer.apple.com/documentation/BundleResources/privacy-manifest-files)、[required-reason API](https://developer.apple.com/documentation/BundleResources/describing-use-of-required-reason-api) 和 Xcode Privacy Report。
- 截图：iPhone 6.9 英寸候选为 1320×2868，iPad 13 英寸候选为 2064×2752，均为无 alpha PNG；具体可接受槽位应按 [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) 在提交时重新核验。
- App Store 隐私：本地草案不能替代 App Store Connect 的 [App privacy details](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)。

## 证据

- 最终本地质量门：`docs/release/evidence/automation/20260929T175103+0800/QUALITY_GATE.md`。
- iOS 15 配置后机械预检：`docs/release/evidence/automation/preflight-20260929T180000+0800/RELEASE_PREFLIGHT.md`。
- iOS 15 定向验证：`docs/release/evidence/automation/ios15-20260929T180240+0800/IOS15_VALIDATION.md`。
- 功能与 UI 证据：`docs/release/FUNCTIONAL_REVIEW.md`、`docs/release/EVIDENCE_REGISTER.md`。
- 差异化与权利边界：`docs/product/DIFFERENTIATION.md`、`docs/product/CONTENT_RIGHTS.md`。

本报告依据 2026-09-29 打开的 Apple 官方规则形成，但不是 Apple 审核结论。上传、处理、TestFlight 可用、提交审核及审核结果均未执行、未验证。
