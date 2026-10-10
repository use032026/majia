# Almanac App Store / Google Play 预检报告

审核日期：2026-10-10

范围：本地源码、自动化测试、iOS 18.3 iPhone/iPad 模拟器、Android 15 API 35 模拟器、Xcode 26.5 / iOS SDK 26.5 无签名 Archive、Android release APK/AAB。未执行实体设备、生产签名、App Store Connect、Play Console、TestFlight/内部测试或上传。

## 结论

代码与功能 verdict：`passed`。上架 verdict：`blocked / high_risk`。

阻断来自占位 Bundle/Application ID、iOS 无签名、Android Debug 证书、无公开隐私/支持 URL、无商店记录与法定主体事实。即使补齐这些机械项，Apple 4.3(b) 对 fortune telling 饱和类别的明确限制仍使“Almanac + 宜忌”定位保持高审核风险；应用必须靠真实的“选择→封笺→回看→笺册”行为和非预测元数据证明有显著差异，而不是依赖免责声明。

## 阻断与风险

| 级别 | 阻断/风险 | 当前证据 | 进入下一门禁的验收条件 | 状态 |
| --- | --- | --- | --- | --- |
| blocker | iOS/Android 使用 `com.example.almanac` | source + archive + AAB | 确定唯一生产 ID，三处一致 | open |
| blocker | iOS archive 未签名/无 profile | 机械预检 `code_signing_presence` | 真实 Team/profile，codesign 验证通过 | open |
| blocker | Android release 为 Debug 证书 | `CN=Android Debug` | 配置生产 upload key / Play App Signing | open |
| blocker | 隐私政策、支持 URL、法定主体与联系信息缺失 | 预检未传 URL；draft 含占位符 | 公开非占位 HTTPS 页面，可联系且内容与最终包一致 | open |
| blocker | Google Play listing 素材不足 | 仅一张 Android 首屏；无 512×512 Play icon、1024×500 feature graphic | 至少两张真实 Android 截图并补齐 Play 必需图文素材 | open |
| high | Apple 4.3(b) 明列 fortune telling 为饱和类别 | [Apple App Review Guidelines 4.3(b)](https://developer.apple.com/app-store/review/guidelines/) | 元数据不使用运势、吉凶、择日、准确黄历；审核路径展示耐久用户闭环 | open |
| high | 4.2 最低功能属于审核裁量 | 代码已含选择、回看、历史、导出 | 最终签名构建与截图完整呈现，而非单页随机内容 | open |
| high | 中国大陆发行要求未确认 | 无主体/首发区/许可事实 | 确定主体与地区后取得专项合规结论 | open |
| medium | 名称、商标、图标相似性与内容权利未外部核验 | 项目内内容原创声明 | 完成检索并保存权利记录 | open |
| medium | 隐私“不收集”仅有源码/依赖/manifest 证据 | archive 仅 Flutter + shared_preferences；无运行时权限 | 最终签名包 Privacy Report、SDK 审计、ASC/Play 表单一致 | open |

## Apple 规则矩阵

| 当前规则 | 适用性与结论 | 本地证据 | 外部缺口 |
| --- | --- | --- | --- |
| 2.1 App Completeness | `blocked`：代码完整，但身份、签名、URLs、元数据和 on-device 测试不完整 | 23 tests + simulated path + unsigned archive | 签名包、实体设备、ASC 记录 |
| 2.3 Accurate Metadata | `review_required`：候选截图是实际 app capture；不得宣传完整黄历、农历、节气、预测或联网能力 | 无 alpha iPhone/iPad PNG | 最终名称、副标题、描述、关键词、年龄分级、最终构建截图 |
| 3.1 Payments | `not_applicable`：无购买、订阅或付费数字内容 | 依赖/源码检查 | 若商业模式改变需重审 |
| 4.1 Copycats | `passed at product scope`：未复制参考产品书架/章节/便签阅读，独立闭环与数据模型成立 | `docs/product/DIFFERENTIATION.md` | 名称与图标商标检索 |
| 4.2 Minimum Functionality | `high_risk / review_required`：持续记录、回看和导出提高耐久价值，但审核仍有裁量 | DailyLeaf、Folio、Markdown、删除/恢复 | 最终 reviewer path 与用户价值表述 |
| 4.3 Spam | `high_risk`：4.3(b) 明列 fortune telling；不能以“民俗/娱乐”免责声明规避实际预测行为 | 应用明确非预测、无吉凶/评分/择日 | 最终元数据与 App Review 判断 |
| 4.8 Login Services | `not_applicable`：无账号或第三方登录 | 源码/依赖/运行态 | 商店说明保持一致 |
| 5.1 Privacy | `blocked externally`：本地实现与隐私 manifest 存在；Apple 要求隐私政策 URL 与准确隐私回答 | app manifest + Flutter/shared_preferences manifests | 公共 URL、法定主体、最终 Privacy Report、ASC 回答 |
| 5.2 Intellectual Property | `review_required`：内容与图标为项目原创，但没有外部名称/商标结论 | 内容库、SVG 与差异化报告 | 名称/商标/素材权利记录 |
| 当前 SDK 门槛 | `passed mechanically`：2026-04-28 起需 Xcode 26+ / iOS 26 SDK；archive 为 Xcode 26.5 / SDK 26.5 | archive Info.plist | 最终签名 upload validation |

官方依据（访问于 2026-10-10）：

- [Apple Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/)：当前上传最低 Xcode 26 与 iOS/iPadOS 26 SDK。
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)：2.1、2.3、4.1、4.2、4.3(b)、5.1、5.2。
- [Apple Manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)：iOS 隐私政策 URL 与 App Privacy 回答要求。
- [Apple Third-party SDK Requirements](https://developer.apple.com/support/third-party-SDK-requirements/)：最终依赖和 privacy manifest 责任。
- [Apple Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)：当前 iPhone/iPad 截图尺寸与必需设备层。

## 身份、隐私与依赖观察

- iOS：Bundle ID `com.example.almanac`（占位）；version `1.0.0 (1)`；minimum iOS 15.0；无 Team；archive 未签名。
- Android：applicationId `com.example.almanac`（占位）；minSdk 24、targetSdk 36；release AAB/APK 使用 Debug 证书。
- App 内没有网络客户端、账号、广告、分析、IAP 或运行时权限；只依赖 Flutter 与 `shared_preferences`。这只支持静态/包级结论，不替代抓包或商店隐私问卷。
- Archive 找到并解析了 app、Flutter、shared_preferences 的 privacy manifests。
- App 内设置页提供本地隐私和生成方法说明；公共政策仍缺法定主体与联系信息。
- 商店截图候选无 alpha，iPhone 1206×2622、11 英寸 iPad 1668×2420、13 英寸 iPad 2064×2752；已覆盖 Apple 当前 iPhone 与 13 英寸 iPad 尺寸层，但来自模拟器 debug 构建，需要最终签名 candidate 重拍或确认一致性。

## Google Play 补充预检

| 项目 | 结论 | 证据/缺口 |
| --- | --- | --- |
| Target API | passed | Google 自 2026-08-31 要求新 app/update target API 36；当前 targetSdk 36 |
| 最低版本 | product choice | minSdk 24，符合当前 Flutter 支持矩阵；非 Play 的统一最低门槛结论 |
| 64 位 | passed at bundle inventory | AAB 含 `arm64-v8a` 与 `x86_64`，并保留 `armeabi-v7a` |
| 16 KB page size | passed mechanically / runtime incomplete | release APK 通过 `zipalign -c -P 16`；未在 16 KB emulator/Play delivery APK 运行 |
| 签名 | blocked | release AAB/APK 使用 Android Debug certificate |
| Data Safety / privacy policy | blocked externally | 无 Play Console 记录；Google 要求每个 app 的准确 Data Safety 与公开隐私政策，即使 app 不访问敏感数据 |
| Store listing 素材 | blocked | 当前仅一张 Android 首屏；仍需至少第二张 Android 截图、512×512 icon、1024×500 feature graphic 与完整 listing 文案 |
| 开发者账号生产门槛 | unknown external state | 若为 2023-11-13 后创建的个人账号，可能适用 closed test 人数/时长要求；账号事实未提供 |
| 重复/低价值内容 | high review risk | 必须展示选择、回看、历史、导出，不应包装为随机诗句或简单 fortune app |

官方依据：

- [Google Play Target API Requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)：2026-08-31 起新 app/update target API 36+。
- [Android 16 KB Page Size Guidance](https://developer.android.com/guide/practices/page-sizes)：64 位设备与 Google Play 的 16 KB 支持要求。
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)：release key 与 Play App Signing 要求。
- [Google Play User Data Policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)：Data Safety、公开隐私政策及 app 内可访问政策要求。
- [Google Play Store Listing Requirements](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)：截图、商店图标、feature graphic 与 listing 素材。

## 机械预检

- 最终报告：`docs/release/evidence/automation/preflight-20261010T161049+0800/RELEASE_PREFLIGHT.md`
- 通过：app icon、archive metadata、privacy manifests、source/archive version identity、截图 alpha/尺寸、指定工件存在。
- 阻断：占位 Bundle ID、隐私 URL、支持 URL、iOS 签名。
- 警告：目录无 Git commit 身份。

本报告不预测 Apple 或 Google 的审核决定，也没有执行上传、处理、TestFlight、内部测试或发布。
