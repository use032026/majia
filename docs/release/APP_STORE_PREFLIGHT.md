# 回声页 · EchoPage App Store 预检报告

审核日期：2026-09-30
范围：本地源码、32 个测试、iOS 18.3 模拟器、Android Debug、iOS 无签名 Release Archive、当前 Apple 官方规则。未进入 App Store Connect。
结论：`blocked / high_risk`。Flutter MVP 和功能门禁完成，但当前不是可提交候选。

## 阻断与风险

| 优先级 | 阻断/风险 | 当前证据 | 进入下一门禁的条件 | 状态 |
| --- | --- | --- | --- | --- |
| P0 | Bundle ID 为 `com.example.diary` 占位 | 机械预检 blocker；Archive Info.plist | 确认生产身份并在源码/Archive 一致验证 | open |
| P0 | Archive 无签名/无 embedded profile | `codesign`: code object is not signed at all | 用有效 App Store Distribution 配置生成并验证 Archive | open |
| P0 | 无公开 Privacy URL、Support URL、法定主体/联系信息 | 机械预检两个 blocker；政策仍是 draft | 发布稳定 HTTPS 页面，并在 App 内和 ASC 配置一致链接 | open |
| P0 | ASC 元数据、隐私回答、年龄分级、类别、定价与地区未建立 | 按要求未登录/上传 | 由账号持有人完成并逐项对照最终 binary | open |
| P0 | 没有商店合规截图集 | 现有截图含 alpha，且只是内部运行证据 | 从最终签名候选采集当前规格的 iPhone/iPad 中英文核心闭环截图 | open |
| P1 | 日记品类拥挤，存在 4.2/4.3 最低功能/模板化风险 | 差异化分 3.9/5；MVP 原生能力有限 | 前三张截图和 Review Notes 证明“未来问题→回声→关闭/续期”，不是普通日记换皮 | open |
| P1 | 工作名/图标未做名称、商标和权利检索 | 仅有项目内原创权利说明 | 完成目标地区名称/商标/ASC 名称可用性清查 | open |
| P1 | 真机、iOS 15、VoiceOver、系统 backup/restore 未验证 | 功能报告明确缺失 | 最终签名候选完成真机/最低系统/辅助功能/备份边界矩阵 | open |
| P1 | 中国大陆首发的备案/合规适用性未确认 | intake 假设包含中国大陆；本轮无法律结论 | 由负责主体依据当前分发地区和业务取得专业确认 | open |
| P2 | 项目非 Git，缺少提交级可追溯性 | preflight warning | 纳入受控仓库，以 commit/tag 绑定 Archive | open |

## 规则矩阵

| 当前规则与官方链接 | 适用性 | 结论 | 本地证据与缺口 |
| --- | --- | --- | --- |
| [2.1 App Completeness](https://developer.apple.com/app-store/review/guidelines/#app-completeness) | 高 | blocked | 功能门禁通过，但真机、生产 URL、完整元数据、签名候选缺失。 |
| [2.3 Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata) | 高 | blocked | 尚无 ASC 记录；现有截图不是提交素材；必须准确披露免费、无账号、系统备份边界。 |
| [3.1 Payments](https://developer.apple.com/app-store/review/guidelines/#payments) | 低 | pass for current scope | 免费、无 IAP/订阅；若商业模式变化需重审。 |
| [4.1 Copycats](https://developer.apple.com/app-store/review/guidelines/#copycats) | 高 | conditional | 未复用竞品品牌/截图/文案；工作名和商标未清查。 |
| [4.2 Minimum Functionality](https://developer.apple.com/app-store/review/guidelines/#minimum-functionality) | 高 | high_risk | 跨时间反思闭环提供具体效用，但通知、文件导出、锁定等原生深度延期。 |
| [4.3 Spam](https://developer.apple.com/app-store/review/guidelines/#spam) | 中 | conditional | 独立数据模型和流程降低模板化风险；仍需证明不是同类日记批量换皮。 |
| [4.8 Login Services](https://developer.apple.com/app-store/review/guidelines/#login-services) | 不适用 | pass | 无账号/第三方登录。 |
| [5.1 Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy) | 高 | blocked | 无追踪/分析/后台，manifests 存在；但缺公开政策 URL、App 内链接、ASC 回答和最终 Privacy Report。 |
| [5.2 Intellectual Property](https://developer.apple.com/app-store/review/guidelines/#intellectual-property) | 高 | conditional | 图标为项目内原创 SVG/导出；名称/商标清查未完成。 |
| [2026 SDK minimum](https://developer.apple.com/news/upcoming-requirements/?id=04282026a) | 高 | pass | Apple 当前要求 Xcode 26+/iOS 26 SDK；Archive 为 Xcode 26.5 / iOS 26.5 SDK。 |
| [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) | 高 | blocked | SE 750×1334 尺寸本身受支持，但现有 PNG 含 alpha；缺当前主设备规格和完整本地化集合。 |

## 身份、隐私与依赖观察

- Archive：`com.example.diary`，`1.0.0 (1)`，minimum iOS 15.0，iPhone+iPad，arm64，unsigned。
- 依赖仅 Flutter 与 `path_provider_foundation`；Release Android manifest 未声明 INTERNET/广告 ID/相机/位置/通知权限。
- 主 App manifest 声明不跟踪、不收集；Flutter framework 声明 File Timestamp 与 System Boot Time required-reason APIs；path_provider manifest 可解析。最终仍需 Xcode Privacy Report。
- Android 默认 Auto Backup 可能包含应用文件；iOS 系统备份也由平台/用户控制。App、PRD 与政策草稿已准确披露“无开发者服务”不等于“无系统备份”。
- 现有 5 张截图是运行验收证据，不是 App Store marketing assets。

## 机械预检

- 报告：`docs/release/evidence/automation/preflight-20260930T105802+0800/RELEASE_PREFLIGHT.md`
- Verdict：`blocked`。
- Pass：AppIcon 1024 无 alpha、Archive 信息可解析、privacy manifests 存在、版本/构建号一致、指定工件存在。
- Blocker：占位 Bundle ID、Privacy URL、Support URL、代码签名。
- Warning：无 Git identity、候选截图含 alpha。

本报告不是 Apple 审核结论；按用户要求没有上传、处理、TestFlight 或 App Review 状态。
