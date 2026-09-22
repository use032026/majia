# 微成 · Steady21 App Store 预检报告

审核日期：2026-09-22
范围：最终本地源码、24 项测试、iOS 18.3 模拟器运行证据、Android Debug APK、iOS 26.5 SDK 无签名 Release Archive、依赖/隐私清单和当前 Apple 官方规则；未登录 App Store Connect、未签名、未上传、未提交。

最终 Store Reviewer 结论：`BLOCKED`，不是可提交 App Store 的候选包。功能审核已 `passed` 且无开放 P0/P1/P2；最终机械报告位于 `docs/release/evidence/automation/preflight-20260922T132538+0800/RELEASE_PREFLIGHT.md`，阻断集中在生产身份、签名、品牌资产、公开 URL、商店素材和 ASC 外部状态。

## 当前通过项

- Flutter 格式、静态分析、24 项测试、Android Debug 和 iOS Release `--no-codesign` Archive 全部通过。
- Xcode 26.5 / iOS 26.5 SDK 满足 2026-04-28 起的 Xcode 26+/iOS 26 SDK 提交工具链基线。
- Archive 为 arm64，版本 1.0.0 (1)，最低 iOS 15.0，支持 iPhone/iPad。
- 最终依赖未发现账号、网络传输、广告、分析或 IAP 代码；核心记录保存在本地 JSON。
- Archive 中 Flutter 与 `path_provider_foundation` 的 Privacy Manifest 存在且可解析；均声明无收集/跟踪，Flutter 声明 FileTimestamp 与 SystemBootTime required-reason API 理由。
- 差异化闭环已实现并通过本地功能审核：标准/最低行动、阻碍与恢复、7/14/21 复盘、非重叠称号、可冻结归档报告。

## 发布阻断

| 优先级 | 阻断/风险 | 当前证据 | 进入下一门禁的验收条件 | 状态 |
| --- | --- | --- | --- | --- |
| P0 | 占位 Bundle ID `com.example.steady21` | 源码和 Archive 一致，但机械预检明确 blocker | 正式 Bundle ID、App ID、Team、ASC App 记录和 profile 一致 | open |
| P0 | Archive 未签名 | `codesign` 显示 not signed；无 embedded provisioning profile | 生成并验证 App Store 分发签名 Archive | open |
| P0 | 无公开隐私政策和支持 URL | 脚本两项 blocker；设置页只有离线说明，无 URL/联系信息 | 公共 HTTPS 页面可访问，App 内与 ASC 均引用，内容与最终包一致 | open |
| P0 | 默认 Flutter AppIcon/启动占位 | Flutter Archive 日志明确警告；机械脚本的 icon pass 只证明 1024 尺寸/无 alpha | 替换原创资产，Archive 不再报 placeholder，并留存授权/来源 | open |
| P0 | ASC 必填状态不存在 | 未创建/检查版本、隐私、年龄、价格地区、审核联系人等 | 所有必填项完成并与最终构建/文案一致 | open |
| P1 | 当前运行截图不能作为商店截图 | 1170×2532、1668×2420，均带 alpha | 最终 UI 生成 iPhone 6.9/6.5 与（若支持）iPad 13-inch 合规无 alpha 图片 | open |
| P1 | App 内仍含内部候选措辞 | `copy.dart` 显示 “Local MVP candidate · not App Review approval” | 发布构建改为正常版本/产品说明，预检不再命中 preview wording | open |
| P1 | 工作名与素材权属未清查 | 市场报告明确工作名未做商标清查 | 最终中英名称、图标、字体与素材完成权属/重名检查 | open |
| P1 | 无真机/Validate | 只有 iOS 18.3 模拟器和无签名 Archive | 最终签名构建在真机完成主闭环并通过 Xcode Validate | open |

## App Review Guidelines 矩阵

| 当前规则 | 适用性 | 结论 | 本地证据 | 外部缺口 |
| --- | --- | --- | --- | --- |
| [2.1 App Completeness](https://developer.apple.com/app-store/review/guidelines/#performance) | 完全适用 | blocked | 功能审核和本地构建通过 | 默认资产、内部候选文案、无签名真机验证 |
| [2.3 Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/#performance) | 完全适用 | blocked | 产品/差异化/Review Notes 草案已写 | ASC 中英描述、关键词、截图、隐私与联系信息未建 |
| [3.1 Payments](https://developer.apple.com/app-store/review/guidelines/#business) | 当前无付费/IAP/外链购买 | not applicable | 源码、依赖和 UI 未发现支付 | 未来商业化需重审 |
| [4.1 Copycats](https://developer.apple.com/app-store/review/guidelines/#design) | 完全适用 | blocked | 未复制竞品品牌/截图/布局；差异化报告通过 | 默认 Flutter 图标须替换，名称/素材权属须清查 |
| [4.2 Minimum Functionality](https://developer.apple.com/app-store/review/guidelines/#design) | 完全适用 | passed locally | 完整行为实验与耐久报告闭环，功能审核通过 | Apple 仍有最终裁量；元数据须准确呈现差异 |
| [4.3 Spam](https://developer.apple.com/app-store/review/guidelines/#design) | 拥挤品类适用 | passed locally | 非模板换色；差异进入工作流/数据模型 | 需保持单一产品与差异化证据 |
| [4.8 Login Services](https://developer.apple.com/app-store/review/guidelines/#design) | 无账号/第三方登录 | not applicable | 无登录 UI/SDK | 若以后加第三方登录需重审 |
| [5.1 Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy) | 所有 App 适用 | blocked | 本地数据、无网络/分析；SDK manifests 已解析 | 公开政策/支持 URL、App 内链接、ASC 问卷、最终 Privacy Report |
| [5.2 Intellectual Property](https://developer.apple.com/app-store/review/guidelines/#legal) | 完全适用 | blocked | 未引入竞品资产 | 工作名、图标、字体和全部素材的权属/商标核查 |

## 身份、隐私与依赖观察

- Bundle ID/签名：`com.example.steady21`；Team/Signing Identity 为空；无 profile；版本 1.0.0 (1)，iOS 15.0。
- 数据流：用户文字和状态写入应用沙盒 JSON；无产品网络 client、账号、广告、分析或支付依赖；无敏感权限 usage description。
- Privacy Manifests：Archive 内 Flutter 与 path_provider manifests 有效；这不替代最终 Xcode Privacy Report 或 ASC App Privacy 问卷。
- App Privacy：当前实现支持在 ASC 回答“不收集数据”，但必须以最终签名包和所有最终 SDK 重新核对。
- 截图：现有三张 PNG 是运行证据，含 alpha 且尺寸不符合商店提交规格，不能上传。
- 图标：机械脚本只验证 1024px/无 alpha；Flutter 构建日志额外确认其仍为默认 placeholder，因此整体结论仍是 blocker。

## 当前官方依据

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)（访问：2026-09-22）
- [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/)（访问：2026-09-22）
- [Required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) 与 [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)（访问：2026-09-22）
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) 与 [Manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)（访问：2026-09-22）
- [App information / privacy URL](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)、[platform version / support URL](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)（访问：2026-09-22）
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)、[age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)、[submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)（访问：2026-09-22）

## 地区与证据边界

- 中英文不等于必须在中国大陆商店发布。若选择中国大陆 storefront，需在 ASC 核对 ICP 等当地资质是否适用；本轮没有完成该外部核验。
- 本报告不证明正式签名、真机安装、Xcode Validate、ASC 接收、TestFlight 可用或 Apple 审核通过。
- 未登录或更改 Apple 账号、证书或 ASC；未上传，符合用户停止条件。
