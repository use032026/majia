# ReaderEdit App Store 预检报告

审核日期：2026-09-30

范围：当前本地 Flutter 源码、29 项测试、iPhone 17e / iOS 26.5 模拟器、Android debug APK、Xcode 26.5 / iOS 26.5 SDK 生成的 unsigned archive、机械预检与 Apple 公开规则。未使用生产证书/账号，未访问 App Store Connect，未上传。

结论：`blocked`。小说创建、章节编辑、长文导入入口和旧数据迁移已纳入 MVP；功能宽度降低了原先 4.2 风险。但仍不是可上传 candidate，且旧商店截图已不能代表当前书架首页。

## 阻断与风险

| 优先级 | 阻断/风险 | 当前证据 | 进入下一门禁的验收条件 | 状态 |
| --- | --- | --- | --- | --- |
| P0 | placeholder Bundle ID | source/archive 均为 `com.example.readerEdit` | 使用已注册且与 App ID、ASC、profile、archive 一致的生产 ID | open |
| P0 | unsigned archive / 无 embedded profile | `codesign` 验证失败；无 Team/profile | 有效 App Store distribution archive，核对签名、entitlements、profile 与 expiry | open |
| P0 | 无公开 Privacy Policy URL 与 Support URL | 机械预检 blocker；App 内只有本地隐私说明 | 发布稳定 HTTPS 页面，在 ASC 填写并在 App 内提供链接 | open |
| P1 | ASC metadata/privacy answers 未建立 | 本轮未访问 ASC | 完成名称、分类、年龄分级、描述、关键词、版权、地区、隐私回答和 Review Notes 独立复核 | open |
| P1 | 商店截图已过时且集合不完整 | 现有 6.9-inch/13-inch 各一张首页候选来自新增书架前；机械尺寸/alpha 虽通过，内容已不代表当前版本 | 从最终签名候选重新拍摄书架、导入、章节阅读编辑、读者修订，每设备/语言形成完整集合 | open |
| P1 | 无最终签名构建实体设备验证 | 仅模拟器与 unsigned archive | 目标 iPhone/iPad、最低 iOS 15 验证首启、真实 Files 导入、长文编辑、持久化/删除、剪贴板和中断恢复 | open |

## 本轮新增预检观察

- iOS archive 新增 `file_selector_ios.framework`，其 `PrivacyInfo.xcprivacy` 存在且可解析；这不替代最终 Xcode Privacy Report 和 ASC privacy answers。
- 文件导入由系统 Files 选择器发起，应用不申请全盘文件权限；用户选中文本后，内容复制到 ReaderEdit 本地工作区。
- Android 合并产物最低版本变为 API 24（Android 7.0），源码已显式固定，商店兼容性说明应一致。
- 文件内容可能包含私人创作，但当前实现无账号、自有后台、分析、广告或主动网络传输；隐私政策需新增文件导入、编码/大小和本地副本说明。
- 新功能没有新增 IAP、订阅、登录、UGC 社区或内容发布审核义务。

## 规则矩阵

| 当前规则与官方链接 | 适用性 | 结论 | 本地证据 | 缺口 |
| --- | --- | --- | --- | --- |
| [2.1 App Completeness](https://developer.apple.com/app-store/review/guidelines/) | 全部提交 | blocked | 书架→章节→阅读编辑→精修闭环、29 tests、双平台本地构建通过 | 生产身份、签名、真机 Files 导入、ASC 记录缺失 |
| [2.3 Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/) | 名称/描述/截图/版本 | blocked | 版本 1.0.0+1，旧截图尺寸合规 | 旧截图不再准确；metadata 未建立 |
| [3.1 Payments](https://developer.apple.com/app-store/review/guidelines/) | 数字购买 | not_applicable | 无 IAP、订阅或付费解锁 | 商业模式变化时重审 |
| [4.1 Copycats](https://developer.apple.com/app-store/review/guidelines/) | 产品、名称、素材 | medium_risk | 自有视觉/资产；离线阅读编辑接 reader-signal 精修 | 新增书架/章节后与类别共性增加；商店材料须突出连续精修差异，名称/图标未做正式商标检索 |
| [4.2 Minimum Functionality](https://developer.apple.com/app-store/review/guidelines/) | 持续效用 | low_to_medium_risk | 可维护多本小说/章节、长文导入、阅读编辑、修订历史与本地恢复 | 缺整本导出、重排/拆分和真机极限长文证据 |
| [4.3 Spam](https://developer.apple.com/app-store/review/guidelines/) | 重复/换皮 App | local_low_account_unknown | 独立模型、流程、迁移和视觉 | 无 Git 历史；未核对账号下其他 App |
| [4.8 Login Services](https://developer.apple.com/app-store/review/guidelines/) | 第三方登录 | not_applicable | 无账号与登录 | 增加登录时重审 |
| [5.1 Privacy](https://developer.apple.com/app-store/review/guidelines/) | 数据、政策、删除 | blocked | 本地工作区、删除恢复、文件选择器和剪贴板边界明确；privacy manifests 可解析 | 公开 URL、App 内链接、最终 Privacy Report、ASC 回答和真实文件提供方验证缺失 |
| [5.2 Intellectual Property](https://developer.apple.com/app-store/review/guidelines/) | 名称/素材权利 | review_required | 原创品牌图与差异化报告 | 正式商标/权利清查未做 |
| [当前提交 SDK 基线](https://developer.apple.com/news/upcoming-requirements/?id=02032026a) | 2026-04-28 起 | passed_locally | Xcode 26.5、iOS 26.5 SDK、最低 iOS 15 | 最终签名 archive 需同基线重验 |

## 身份、依赖与隐私

- Archive：Bundle ID `com.example.readerEdit`，version `1.0.0`，build `1`，MinimumOSVersion `15.0`，未签名。
- Archive frameworks：`App`、`Flutter`、`file_selector_ios`、`path_provider_foundation`、`shared_preferences_foundation`。
- Privacy manifests：App、Flutter 与上述三个插件的 manifests 均被机械解析；presence 不是行为审计结论。
- 数据流：输入/导入小说与章节、读者承诺/信号/备注/修订 → app sandbox JSON；明确复制时 → 系统剪贴板；无自有后台。
- 无账号，因此应用内账号删除要求不适用；小说、章节、修订与全部数据删除均为本地操作。
- 当前唯一新增运行态平台验证是 iOS 系统 Files 选择器可打开/取消；未选择实际文件，不证明第三方文件提供方完整路径。

## 差异化与参考产品结论

参考产品“作家助手”包含码字、章节、发布、社区、同步与运营。ReaderEdit 现在也具备类别必需的小说/章节结构，因此差异不再是“没有书架”，而是无账号离线导入、阅读时编辑与可回溯 reader-signal 精修的连续路径。4.1 从较低上调为 `medium`；4.2 因持续小说工作区从 `medium` 降为 `low_to_medium`。[参考产品页面](https://apps.apple.com/cn/app/%E4%BD%9C%E5%AE%B6%E5%8A%A9%E6%89%8B/id1044537226)

## 当前证据

- 最终质量门禁：以 `docs/release/EVIDENCE_REGISTER.md` 登记的最新 `QUALITY_GATE.md` 为准。
- 最新机械预检：`docs/release/evidence/automation/preflight-20260930T120134+0800/RELEASE_PREFLIGHT.md`，`blocked`。
- 运行态：`docs/release/evidence/runtime/iphone17e-chapter-read-zh-light.png`；另有 AX 记录证明创建、保存、重启持久化与 Files 选择器打开。
- 机械通过：App Icon、archive info、privacy manifests、archive/source identity/version、旧截图 dimensions/alpha、请求工件存在。
- 机械 blocker：Bundle ID、Privacy URL、Support URL、签名/profile。

本报告不是 Apple 审核结论，也不证明上传、处理、TestFlight 或 App Review。根据停止条件，本轮没有执行任何上传或提交。
