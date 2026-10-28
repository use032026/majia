# App Store 预检报告

2026-10-28 配置更新：当前源码的 iOS/Android 包标识已改为 `com.astfx.lite`，运营主体、联系邮箱和隐私生效日已补齐，正式域名已确认为 `https://astfx1.com`。用户提供的隐私政策地址为 `https://astfx1.com/privacy.html?lang=zh`（中文）和 `https://astfx1.com/privacy.html?lang=en`（英文）；应用默认政策地址为 `https://astfx1.com/privacy.html`，按当前语言设置 `lang`。公共可达性与托管日志实践需单独核验。本次仅做静态核对；以下 2026-09-08 构建、archive 和签名证据为历史记录，不能证明新标识已构建或注册。当前发布资料见 `../../release-kit.yml` 与 `../../artifacts/release-kit/OPEN_ITEMS.md`。

审核日期：2026-09-08  
范围：本地工程、模拟器、无签名 Release archive 与公开 Apple 规则；未登录 App Store Connect、未签名、未上传。  
结论：`blocked`，不能作为 App Store candidate；本地 MVP 可运行，但以下外部发布条件未满足。

## 阻断项

| 优先级 | 阻断 | 当前证据 | 进入 candidate 的验收条件 |
| --- | --- | --- | --- |
| P0 | 生产身份与签名 | Bundle ID 仍为 `com.example.cleantrail`；archive 的 SigningIdentity/Team 为空、无 profile、无 IPA | 用户提供自有 Bundle ID 与团队；生成 App Store 分发签名 archive；`codesign --verify --deep --strict` 通过 |
| P0 | 隐私与支持 URL | App 内隐私入口已在空态/项目态可见；只有本地政策草稿 | 发布中英文 HTTPS 隐私政策与支持页；填写 ASC URL 和隐私回答 |
| P0 | 商店元数据与截图 | 无 ASC 版本记录；当前模拟器证据 PNG 含 alpha，且不是所需 6.9/6.5-inch iPhone 与 13-inch iPad 完整截图集 | 从最终签名构建生成无 alpha 的必需尺寸截图；完成描述、关键词、分类、版权、年龄评级、Review Notes |
| P1 | 真机与最低系统 | 已在 iOS 26.5 iPhone/iPad 模拟器运行；未安装到实体设备、未覆盖最低 iOS 13 | 真机覆盖 Files provider、取消、重启恢复、分享、删除、离线、横竖屏、深色、大字与 VoiceOver |
| P1 | 最终隐私/二进制核验 | App 与三项插件/Flutter 的 PrivacyInfo 均进入无签名 archive 并通过 plist 校验 | 从最终签名 archive 导出 Xcode Privacy Report，复核 required-reason API、SDK 签名与 ASC 校验 |
| P2 | 名称与资产权利 | 图标和 UI 为本地原创；未复制参考产品品牌/素材 | 完成 CleanTrail/清迹名称与商标可用性、图标源文件、第三方依赖许可台账 |
| P2 | 商业模式 | 当前无 StoreKit/IAP，按免费 App 评估 | 若增加数字内容解锁、订阅或付费，再按 3.1 重新审核 |

## 规则矩阵

| 规则 | 结论 | 说明 |
| --- | --- | --- |
| 2.1 App Completeness | `conditional` | 有完整本地闭环、错误状态和内置审核样例；签名真机矩阵未完成 |
| 2.3 Accurate Metadata | `blocked` | ASC 元数据、合法截图集和生产 Bundle ID 缺失 |
| 3.1 Payments | `N/A` | 当前免费、无付费功能；前提变化即重审 |
| 4.1 Copycats | `conditional pass` | 核心结构是确认式修复与审计交付，不是 ChartPrism 图表制作器；权利清查待补 |
| 4.2 Minimum Functionality | `conditional pass` | 不是网页壳；具备本机导入、检查、修复、复检、撤销、恢复和双文件导出 |
| 4.3 Spam | `conditional pass` | 当前为单一独立产品；未核验开发者账号内其他 App |
| 4.8 Login Services | `N/A` | 不含账号或第三方登录 |
| 5.1 Privacy | `blocked` | 代码与 archive 未见收集/跟踪路径；公共政策 URL、ASC 声明与最终 Privacy Report 缺失 |
| 5.2 Intellectual Property | `high risk` | 未使用竞品资产；名称/商标和完整许可证审计未完成 |
| 2026 SDK baseline | `pass locally` | 当前 archive 使用 Xcode 26.5 / iOS SDK 26.5，满足 2026-04-28 起最低 SDK 基线 |

## 隐私与依赖观察

- 应用代码不含账号、广告、分析、后端或应用自建网络请求。
- 系统文件选择器只在用户选择后读取；系统分享面板只在用户点击导出后打开。
- 项目 JSON 包含源数据快照、工作副本和审计操作；临时导出位于独立目录，并在分享返回与下次启动/导出时清理。
- archive 只含 `App.framework`、`Flutter.framework`、`file_selector_ios`、`path_provider_foundation`、`share_plus`；未链接旧 file picker 的图片/相册依赖。
- `ITSAppUsesNonExemptEncryption=false` 与当前无自定义加密或网络服务相符；任何后续网络/加密能力都要重新判断出口合规。

## 官方依据

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Upcoming submission requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [Required Reason API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating)
- [Export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)

本报告不等于 Apple 审核结论；未上传意味着没有 ASC 处理、TestFlight 或 App Review 证据。
