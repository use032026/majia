# FilePeek App Store / Google Play 预检

> 2026-10-21 产品显示名已统一为 Fylto；下述记录保留当时的名称与验证结果，不代表 Fylto 构建的运行证据。

> 2026-10-12 历史预检快照，记录更名前的 FilePeek 构建与身份；2026-10-13 已更名为 FileRecheck。此页的旧名称和占位 ID 发现不代表当前源码状态，当前验证见 `RENAME_VALIDATION_2026-10-13.md`。

审核日期：2026-10-12。Store Reviewer 结论：**`blocked`（仅针对上架提交）**。本地功能审核和构建门禁的结论见 `FUNCTIONAL_REVIEW.md` 与自动化报告。本次没有登录、上传、提交或修改任何商店记录。

## 发布阻断与风险

| 优先级 | 项目 | 当前证据 | 下一门禁 |
| --- | --- | --- | --- |
| P0 | 生产身份 | 主 App、iOS 分享扩展、App Group、Android applicationId 仍为 `com.example.filepeek` / `group.com.example.filepeek`。 | 确定拥有的名称和标识，同步修改所有平台身份与配置，重新归档并核对 entitlements。 |
| P0 | 签名发行包 | 只有 iOS 无签名 Archive 和 Android debug APK；Android release 不再使用 debug signing，但没有生产 keystore 或 AAB。 | 获取生产签名、分发证书和 profiles，验证 iOS 正式 Archive/IPA 与 Android release AAB 的包名、版本、SDK、签名和 16 KB 兼容性。 |
| P0 | 对外法律与联络页面 | 没有公开隐私政策及支持 URL；仓库内仅有草稿，应用内只有简短隐私说明。 | 法律主体确认后发布稳定 HTTPS 页面，在应用与商店元数据填入真实链接并核对内容。 |
| P0 | 上架素材及平台申报 | 没有从最终发布构建产生的商店截图、完整文案、App Privacy、Play Data safety、年龄分级或审核附件。 | 使用最终构建实拍并验证截图，准备双语元数据和示例文件，逐项完成平台表单。 |
| P1 | 名称相似 | 中国区已有 [FilePeek Markdown Viewer](https://apps.apple.com/cn/app/filepeek-markdown-viewer/id6784750750)，其页面也描述 JSON/CSV、Files/分享和离线；本项目仍以 FilePeek 作工作名。 | 提交前核查名称/商标与搜索结果，采用可区分的正式名称；用真实截图说明“工作副本修正→复检→报告”闭环。不能仅凭此断言侵权或拒审。 |
| P1 | 平台运行与辅助功能 | iPhone 17 Pro/iOS 26.2 已操作 Files 和格式功能；iPhone 16 Pro/iOS 18.3 已验证分享扩展保存带空格文件名、主 App 从后台返回与冷启动读取及 App Group 清理。Android API 35 模拟器已验证系统文件选择和 JSON/CSV/TXT 的 ACTION_SEND。最低系统、API 36 设备和真机未跑。 | 覆盖 Android API 36 和实体设备、最低系统、Dynamic Type、VoiceOver/TalkBack、低存储及中断。 |
| P1 | 最终 SDK 与隐私行为 | Archive 内若干第三方框架的 PrivacyInfo.xcprivacy 已解析，尚无最终 Xcode Privacy Report、SDK 行为核查、Play Data safety 和 16 KB 实测。 | 基于最终签名包核对全部 SDK、required-reason API、数据流和原生库页面尺寸。 |

## 当前官方规则矩阵

| 官方规则 | 适用性与本地证据 | 结论 |
| --- | --- | --- |
| [Apple 2.1 App Completeness](https://developer.apple.com/app-store/review/guidelines/) | 35 项测试及 iPhone 模拟器核心流程有利；身份、公开链接、真机和最终包缺失。 | blocked |
| [Apple 2.3 Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/) | 功能声明可从代码验证；商店截图、描述和 App Privacy 未最终制作。 | blocked |
| [Apple 2.5.15 Files/iCloud](https://developer.apple.com/app-store/review/guidelines/) | 系统 Files picker 在模拟器导入本地文件；iCloud 提供方与真机未验证。 | review_required |
| [Apple 分享扩展边界](https://developer.apple.com/forums/thread/764570) | Apple DTS 明确 Share Extension 不允许直接唤起主 App，绕过 `UIApplication` 限制可能影响审核。当前扩展只保存到 App Group 并提示用户手动打开 FilePeek，主 App 在启动/返回前台读取；iOS 18.3 后台恢复与冷启动均已实测。 | supported_design；真机仍待核对 |
| [Apple 3.1 Payments、4.8 Login Services](https://developer.apple.com/app-store/review/guidelines/) | 当前免费、无 IAP、无账号或第三方登录。 | 当前流程不触发相关实现要求；发行前再核对 |
| [Apple 4.1/4.2/4.3 与 5.2](https://developer.apple.com/app-store/review/guidelines/) | 原创界面及自制图标，导入→工作副本→复检→报告构成独立效用；名称与竞品近似。 | 有差异化依据，名称/素材仍需审核 |
| [Apple 5.1 Privacy](https://developer.apple.com/app-store/review/guidelines/) | 离线处理、无自有后台；公开政策、最终依赖数据实践与平台隐私回答缺失。 | blocked |
| [Apple iOS SDK 提交基线](https://developer.apple.com/news/?id=ueeok6yw) | 2026-04-28 起需 iOS 26 SDK；当前无签名 Archive 显示 `iphoneos26.5`、Xcode 26.5。iOS 15 是本项目最低安装版本，不是 Apple 指定的提交 SDK 下限。 | 构建 SDK 达标，发行包仍 blocked |
| [Google Play 目标 API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-EN) | 2026-08-31 起新应用需 target API 36；工程 compile/target 36、min 24。 | 配置达标，发布 AAB 未验证 |
| [Google 文件权限](https://support.google.com/googleplay/android-developer/answer/10467955?hl=en) 与 [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en-en) | 使用系统选择器/ACTION_SEND，主 Manifest 未申请广泛文件权限；Android API 35 模拟器确认 JSON 选择和 JSON/CSV/TXT 分享入站。Play 表单、API 36 和真机未验证。 | review_required |
| [Android 16 KB 页面兼容](https://developer.android.com/guide/practices/page-sizes) | 目前只有 debug APK，尚未对最终 AAB/原生库与设备做兼容验证。 | review_required |

## 构建、身份与依赖边界

- `1.0.0+1`；iOS 最低 15.0，Android 最低 API 24。它们是支持范围选择，不是 Apple/Google 明文规定的最低用户系统版本。
- Flutter 3.35.7、Dart 3.9.2、Xcode 26.5；iOS Archive 的 `DTSDKName=iphoneos26.5`。Android target SDK 36。
- 主要包：`file_picker 10.3.10`、`receive_sharing_intent 1.8.1`、`share_plus 11.1.0`、`path_provider 2.1.5`。机械预检发现 Framework Privacy Manifest，但“存在且可解析”不证明声明完整。没有开发者服务器、广告、分析或账号代码；最终包仍需隐私报告。
- `tool/generate_icons.py` 产生自制 1024px 无 alpha 图标及平台尺寸；视觉与原创性仍需最终品牌审核。机械预检的图标绿灯只证明尺寸/alpha。
- 最终本地门禁见 `docs/release/evidence/automation/20261012T184622+0800/QUALITY_GATE.md`；机械预检见 `docs/release/evidence/automation/preflight-20261012T184717+0800/RELEASE_PREFLIGHT.md`，结论 `blocked`。预检对模拟器原始 PNG 报 alpha 警告；这些截图是运行证据，并未作为商店素材。预检的 `blocked` 是本地机械与证据判断，不是 Apple/Google 的审核决定。

## 明确未发生

无生产签名 IPA/AAB、无实体设备证据、无 App Store Connect/Play Console 申报或上传、无 TestFlight/Play 测试轨道、无平台处理结果或人工审核结论。**不上传 App Store** 是本次任务边界。
