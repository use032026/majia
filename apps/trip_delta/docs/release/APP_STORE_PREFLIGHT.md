# 旅程差额 / Trip Delta App Store 预检报告

> 2026-10-15 云构建更新：iOS `com.tripdelta.lite.app` 的 1.0.0 (2) 已签名打包并上传 ASC，上传 `COMPLETE`、处理 `VALID`。见 [当日 ASC 上传记录](IOS_ASC_UPLOAD_2026-10-15.md)。下方 2026-09 预检结论和表格是历史快照；Android 仍使用 `com.tripdelta.lite`。此记录不代表已提交 App Review 或上架。

> 2026-10-14 隐私更新：中英文政策已在 `gotripdelta.com` 公开并接入 App；下方“无公开隐私政策 URL”是 2026-09 预检的历史发现。公开支持 URL 与商店隐私回答仍需核对。

> 2026-10-14 范围更新：新增本地备份文件选择插件和功能流程后，以下旧 Archive、依赖及隐私检查仍是历史证据；正式候选必须对最终构建重跑。`blocked` 结论未改变，未上传 App Store。

审核日期：2026-09-18。独立 Store Reviewer 结论：**`blocked`，当前不可作为上架候选**。范围为本地源码、10 项测试、iOS 模拟器、Android Debug APK、未签名 iOS Archive 与机械预检；无实体设备、签名 IPA、App Store Connect、TestFlight、上传或 App Review。Apple 最终决定不可由本报告保证。

> **2026-09-21 复检：仍为 `blocked`。** 产品核心已完成旅行日期/当地币种、快捷记账、估算/最终入账与复盘归因，13 项测试及构建通过；这降低 4.2 实用性和 2.3 准确描述风险。新 Archive 仍明确报出 `com.example.tripDelta`、默认 App Icon、默认 Launch Image，且关闭签名后不会生成 IPA。Apple 当前 5.1.1 仍要求 App Store Connect 元数据和 App 内都有易访问隐私政策链接；Support URL 仍须有真实联系方式。未上传 App Store。

## 阻断与风险

| 优先级 | 发现与用户/审核影响 | 当前证据 | 进入下一门禁的验收条件 | 状态 |
| --- | --- | --- | --- | --- |
| P0 | 历史 Archive 使用占位 Bundle ID `com.example.tripDelta`；当前 iOS 源码为 `com.tripdelta.lite.app` | 旧 Archive Info.plist、旧机械预检；当前 `ios/Runner.xcodeproj/project.pbxproj` | 最终签名 Archive 与 ASC 均使用当前 ID，核对 Team 与品牌 | source_closed / release_open |
| P0 | 无公开隐私政策 URL、Support URL；App 内隐私页无公开政策链接 | `lib/screens.dart`、`PRIVACY_POLICY_DRAFT.md`、机械预检 | 发布责任主体审核的稳定 HTTPS 页面，App 内易达链接，ASC 字段与内容一致 | open |
| P0 | Archive 未签名、无分发描述文件；未生成可提交 IPA | `evidence/automation/20260918T115136+0800/ios-unsigned-archive.log`、`codesign --verify`、机械预检 | 正式签名 Archive/IPA 验证与签名配置审查；另获授权才考虑上传 | open |
| P1 | Flutter 默认图标及默认 Launch Image。1024 图标与本机 Flutter 模板 SHA-256 同为 `7770183009e914112de7d8ef1d235a6a30c5834424858e0d2f8253f6b8d31926`；外观/原创性与素材权利风险 | `ios/Runner/Assets.xcassets`、Archive 构建警告；机械 `app_icon=pass` 仅检查尺寸/alpha | 换原创图标和启动素材，重建 Archive、核对品牌/授权与构建警告 | open |
| P1 | 现有模拟器证据截图均带 alpha，且设备规格/内容并非完整商店素材集；不能直接提交 | 机械预检及 `evidence/*.png` | 从最终构建制作符合当前 Apple 设备规格、无 alpha 的中英功能截图 | open |
| P1 | ASC 隐私回答、双语元数据、类别/年龄分级、品牌权利及中国大陆分发要求尚无外部证据 | 当前无 ASC 项目或法律主体信息 | 逐项完成并与最终构建/地区一致；必要时咨询责任主体 | open |
| P2 | Application Support 可能纳入系统备份，绝对的“仅在此设备”文案会误导 | `lib/store.dart`、第一轮 Store Review | 已改为本机应用存储并注明可能进系统备份；最终政策仍待公开与审查 | copy_closed / policy_open |

## 规则矩阵

| Apple 官方规则 | 适用性及当前判断 | 证据与缺口 |
| --- | --- | --- |
| [2.1 App Completeness](https://developer.apple.com/app-store/review/guidelines/) | 核心 MVP 在已测范围可运行；提交完整性 `blocked` | 10 项测试与模拟器通过；签名、真机、元数据尚缺 |
| [2.3 Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/) | `blocked` | 占位 ID/模板图标；中英截图与商店文案待制作，不能宣称未实现的扫描、实时汇率等功能 |
| [3.1 Payments](https://developer.apple.com/app-store/review/guidelines/) | 当前不涉及 IAP/支付；最终商业模式若改变须复核 | 源码无订阅、广告、交易或支付 SDK；不能推论未来版本 |
| [3.2.1(viii) / 5.1.1(ix) 金融相关边界](https://developer.apple.com/app-store/review/guidelines/) | 是否适用有不确定性；**未作合规保证** | 产品是手动旅行预算/消费记录，不连接资金账户、不转移资金、不提供投资/贷款建议；最终描述与主体需复核 |
| [4.1 Copycats](https://developer.apple.com/app-store/review/guidelines/) | 产品主流程有类别预算基线的独立设计；模板图标仍有风险 | `../product/DIFFERENTIATION.md`；参考 TripCost/RoamSum 同源且未复用代码；原创资产和商标清查待做 |
| [4.2 Minimum Functionality](https://developer.apple.com/app-store/review/guidelines/) | 已实现可持久化的计划→支出→分类差额→复盘；审核结论未验证 | 功能审核、测试与模拟器；真实用户价值/完整设备覆盖未验证 |
| [4.3 Spam](https://developer.apple.com/app-store/review/guidelines/) | 暂无重复上架证据；提交前检查开发者账号同类 App | 当前没有 ASC/账号资料 |
| [4.8 Login Services](https://developer.apple.com/app-store/review/guidelines/) | 无账号/第三方登录，现有功能不触发 | 源码与运行路径；若未来加入登录重新审核 |
| [5.1.1 Privacy](https://developer.apple.com/app-store/review/guidelines/) | `blocked`：公开政策、App 内链接与 ASC 隐私回答缺失 | 已有 App 内短文与本地政策草稿；系统备份边界已修正文案；正式审核待办 |
| [5.2 Intellectual Property](https://developer.apple.com/app-store/review/guidelines/) | 原创实现，无复用 TripCost 代码；默认 Flutter 图标与品牌权利待解决 | 本地图标与模板哈希一致；无公开许可证的参考库只读研究 |
| [当前 SDK 基线](https://developer.apple.com/news/upcoming-requirements/?id=04282026a) | Xcode 26.5 / iOS 26.5 SDK 满足当前已公布上传基线；上传未执行 | Archive Info.plist：iOS 最低 15.0、version 1.0.0+1；Apple 要求会变化，提交时重查 |

## 隐私、依赖与工件观察

- App 使用应用私有 Application Support 文件，保存 JSON；用户可删旅程和支出。无开发者后台、账号、分析或广告 SDK，源代码没有网络客户端。系统设备备份可能包含这些本机文件；**不能**据此宣称数据绝不离开设备。参见 [Apple 文件系统说明](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively)。
- Archive 内嵌 `App.framework`、`Flutter.framework`、`path_provider_foundation.framework`。Flutter 和 path_provider 的 `PrivacyInfo.xcprivacy` 均存在且可解析；这不替代最终 [Xcode Privacy Report](https://developer.apple.com/documentation/BundleResources/privacy-manifest-files)、[required-reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) 与 [ASC 隐私回答](https://developer.apple.com/app-store/app-privacy-details/)。[第三方 SDK 要求](https://developer.apple.com/support/third-party-SDK-requirements/)需按最终依赖重新核对。
- 终版质量门 `evidence/automation/20260918T115136+0800/QUALITY_GATE.md` 为 `passed`；机械预检 `evidence/automation/preflight-20260918T115236+0800/RELEASE_PREFLIGHT.md` 为 `blocked`。机械图标 `pass` 只说明 1024px/无 alpha；截图 alpha 警告及设备尺寸须按 [Apple 截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)重新制作。公开 [Support URL 字段](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)必须指向实际可用支持页。
- 当前 iOS 源码已有生产 Bundle ID `com.tripdelta.lite.app`，但本报告尚未记录该 ID 的最终签名 Archive、Apple Team/分发证书、App Store Connect 上传/处理/审核证据。中国大陆若作为发行地区，还需由发行主体核对当地备案/许可义务；本报告没有完成地区法律审查。

## 当前判断

**功能 MVP 完成且已检范围通过；上架预检 blocked。** 下一门禁以正式身份、原创素材、公开政策/支持页面、签名候选和真实设备验证为核心。完成这些工作仍不代表 Apple 会批准。用户本次明确要求停止于报告，不上传 App Store。
