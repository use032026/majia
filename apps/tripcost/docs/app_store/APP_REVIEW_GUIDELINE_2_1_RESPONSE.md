# RhinoSmart App Review Guideline 2.1 Response Package

> Purpose: reply to Apple's "Guideline 2.1 - Information Needed - New App Submission" message and prepare reusable App Review Information notes.
>
> Scope: this is the current RhinoSmart response draft. Its functional reference baseline is Git `main` commit `883ae5b` (`1.0.0+1`), whose display name was RoamSum. Current-build consistency and physical-device evidence must be checked again before use. This document does **not** describe the separate `h5` branch or any Future Invest/trading surface.
>
> Branding refreshed: 2026-11-03. The prior document and neutral OCR sample are archived locally under `.codex-artifacts/branding-completion-20261103/legacy/app-review/`.
>
> Status: draft. Replace every `[[...]]` placeholder and complete the physical-device checks before sending. Do not state that a recording, device test, attachment, or service validation was completed unless it actually was.

## 1. Pasteable English reply to App Review

Use this block for **Reply to App Review**. After replacing the placeholders, paste the same factual content into **App Review Information > Notes** for this and future submissions.

Recheck the final UTF-8 byte count after inserting device names and filenames to stay within the App Review Notes limit; delete optional wording or an unused device line if necessary.

<!-- APP_REVIEW_REPLY_BEGIN -->

Dear App Review Team,

Thank you. We have provided the requested information and attached a physical-device recording and OCR sample.

1. Screen recording

Attachment: [[RECORDING_FILENAME.mov]]
Recorded on: [[DEVICE_MODEL]], [[OS_VERSION]]
Sample image: [[SAMPLE_IMAGE_FILENAME.png]]

The recording begins with launching RhinoSmart and shows onboarding, setup, camera/photo prompts, on-device OCR, cost comparison, DCC, saving an expense, and the trip budget/ledger.

RhinoSmart has no app account, paid content, IAP/subscription, ads, public UGC, social/report/block flows, or ATT. It does not request location, contacts, microphone, or notifications. Camera/Photos are requested only after the matching scan action. Optional iCloud sync uses the device Apple ID.

2. Devices and operating systems tested

Before submission:
- [[PRE_SUBMISSION_DEVICE_MODEL]] - [[PRE_SUBMISSION_OS_VERSION]]

Additional validation after your request:
- [[LATEST_OS_IPHONE_MODEL]] - [[LATEST_IOS_VERSION]]
- [[LATEST_OS_IPAD_MODEL]] - [[LATEST_IPADOS_VERSION]]

All listed devices are physical; Simulator checks are not included.

3. Functions, audience, problem, and value

RhinoSmart is a free, account-free travel cost assistant for international travelers. It scans prices/receipts with on-device Apple Vision OCR, with manual fallback. It uses dated daily rates, compares user-entered fee/reward rules, estimates DCC cost, tracks trip budgets/expenses, preserves historical snapshots, exports CSV/PDF/backups, optionally syncs structured data with iCloud, and provides a widget. Results are reference estimates, not payment execution or financial advice.

4. Setup and access instructions

No credentials are required. Tap "Skip" or complete onboarding/Quick setup. Set a home currency; add fictional rules under Settings > Payment Methods; create a trip with Trips > "+"; then tap Scan. Choose Compare or Record, select Camera or Photos, grant permission, use the sample, confirm/edit the amount/currency, and continue. Home provides manual input, Compare Payment Methods, and DCC. Saved expenses appear in Ledger and update the trip budget. Optional iCloud Sync and export/backup tools are under Settings. Manual entry remains available if OCR or permission is unavailable.

5. External services, tools, and platforms

Apple Vision performs OCR on-device. Optional iCloud/CloudKit sync stores structured data in the user's private database and excludes receipt originals. Frankfurter (using Cloudflare) supplies dated daily rates; requests contain currency/date parameters, not receipt, trip, or ledger data. WidgetKit/App Groups provide local summaries; Share Sheet handles exports. There is no authentication provider, payment processor, ad/analytics SDK, remote AI service, or UGC backend.

6. Regional differences

The same feature set is available in all App Store regions, localized in English and Simplified Chinese. There is no regional account, pricing, content, or feature restriction. Online rate refresh and optional iCloud sync depend on network/service availability; cached rates and manual entry remain available.

7. Regulated services and protected third-party material

Not applicable. RhinoSmart does not manage financial accounts, execute payments/exchange, provide trading/investment recommendations, or store card numbers, CVV, banking credentials, or identity documents. Payment methods are private user-entered calculation rules and results are dated estimates. There is no protected third-party material requiring authorization.

Support: https://tripcost.fit/
Privacy Policy: https://tripcost.fit/privacy.html

We appreciate your review and are available to provide any additional information.

Best regards,
[[DEVELOPER_OR_COMPANY_NAME]]

<!-- APP_REVIEW_REPLY_END -->

## 2. 必须替换的内容

发送前逐项替换，不允许保留双方括号：

| 占位符 | 填写要求 |
| --- | --- |
| `[[RECORDING_FILENAME.mov]]` | 实际上传到审核消息的 `.mov` 或 `.mp4` 文件名 |
| `[[DEVICE_MODEL]]` / `[[OS_VERSION]]` | 录屏所用真实设备及当时系统完整版本 |
| `[[SAMPLE_IMAGE_FILENAME.png]]` | 审核员可用于 OCR 的无敏感信息样例图片 |
| `[[PRE_SUBMISSION_DEVICE_MODEL]]` | 提交审核前确实测试过的设备；不得把 Simulator 写成真机 |
| `[[PRE_SUBMISSION_OS_VERSION]]` | 对应设备在提交前的实际系统版本 |
| `[[LATEST_OS_IPHONE_MODEL]]` | 收到审核消息后用于最新版 iOS 复核的真实 iPhone |
| `[[LATEST_IOS_VERSION]]` | 录屏当天该设备安装的完整 iOS 版本 |
| `[[LATEST_OS_IPAD_MODEL]]` | 因 App 支持 iPad，建议填写实际验证的 iPad；没有验证前不要虚构 |
| `[[LATEST_IPADOS_VERSION]]` | 对应 iPadOS 完整版本 |
| `[[DEVELOPER_OR_COMPANY_NAME]]` | App Store Connect 中的开发者或公司名称 |

如果提交前只测试过一台真机，就只写一台；收到审核要求后完成的测试应放在 “Additional validation after your request” 下，不要倒填成提交前证据。

## 3. 真机录屏脚本

### 录屏准备

- 使用与审核提交相同的 TestFlight/App Store Connect Build，不使用 Debug 包或包含调试入口的本地包。
- 使用真实设备，并升级到录制当天可用的最新正式系统。
- 删除并重新安装 App，确保出现首次引导，并让相机/相册权限回到首次请求状态。
- 将系统语言设为 English，避免审核员需要翻译。
- 关闭通知预览、勿扰无关来电和其他可能暴露个人信息的内容。
- 使用虚构行程、虚构支付方式和无敏感信息样例票据。
- 录屏必须从主屏幕点击 RhinoSmart 图标、启动 App 开始，不要从 App 已打开的页面开始。

### 建议镜头顺序

1. **启动与引导**：从主屏幕点击 RhinoSmart；展示三页引导和 Quick setup。
2. **基础设置**：选择 Home Currency，例如 USD。
3. **支付方式**：在 Quick setup 或 Settings > Payment Methods 添加两种虚构支付方式。
4. **创建行程**：Trips > `+`，创建 `App Review Sample Trip`，填写目的地、日期、当地币种和预算。
5. **相册权限与 OCR**：点击中心 Scan > Compare > Photos，展示相册权限提示，选择样例图，确认识别金额和币种。
6. **支付成本比较**：继续到 Compare Payment Methods，展示手续费、返现及预计成本差异。
7. **DCC**：返回 Home，输入金额和币种后打开 DCC，展示它只是参考计算，不执行支付或换汇。
8. **相机权限**：再次进入 Scan > Camera，展示相机权限提示；可对另一台屏幕或打印样例拍摄。
9. **扫描记账**：切换到 Record，扫描/选择票据，确认商户、金额、日期，然后保存消费。
10. **行程与账本**：展示 Ledger 中的新记录，以及对应 Trip Budget 已更新。
11. **可选功能**：Settings > iCloud Sync，说明它使用设备 Apple ID；Settings > Data，展示 CSV/PDF/备份入口和系统 Share Sheet。
12. **结束**：返回 App 首页。不要用剪辑隐藏错误、等待状态或权限弹窗。

录屏不必追求广告视频效果，重点是连续、可复现、无跳步。若视频过长，可分为 `01-core-flow.mov` 和 `02-permissions-and-settings.mov`，但第一段必须从启动 App 开始，并在审核回复中列出两个附件名。

## 4. 建议的虚构演示数据

仅用于录屏和审核复现，不包含真实银行卡或个人信息：

### 样例价格图

可复用的中性 OCR 样例：`artifacts/app-review/rhinosmart-app-review-sample-receipt.png`。图片不包含旧应用名称或图标；文件名已随品牌更新。

在白色背景上清晰显示：

```text
APP REVIEW SAMPLE
TOKYO STORE
TOTAL JPY 1,200
2026-08-24
```

### 行程

- Name: `App Review Sample Trip`
- Destination: Japan
- Home currency: USD
- Local currency: JPY
- Budget: USD 2,000
- Dates: 使用录屏当天附近的日期，确保行程出现在 Current & upcoming 中

### 支付方式

`Travel Rewards (Fictional)`：

- Type: Credit Card
- Network: Visa
- Billing currency: USD
- Foreign fee: 0%
- Rate markup: 0.2%
- Cashback: 1.5%

`Everyday Card (Fictional)`：

- Type: Credit Card
- Network: Visa
- Billing currency: USD
- Foreign fee: 3%
- Rate markup: 0.5%
- Cashback: 0.5%

在视频或说明中明确这些是用户自行输入的计算规则，不是 RhinoSmart 提供、发行或推荐的金融产品。

## 5. App Store Connect 操作顺序

1. 进入 **Apps > RhinoSmart > App Review**，打开当前 Unresolved Issues。
2. 点击 **Resolve > Reply to App Review**。
3. 粘贴第 1 节英文正文，替换所有占位符。
4. 点击 **Attach File**，上传真机录屏与样例图。
5. 返回当前版本的 **App Review Information > Notes**，粘贴同一份事实说明，供本次及未来审核使用。
6. `Sign-in required` 保持关闭，因为 App 不需要 RhinoSmart 账号；不要填写虚构账号。
7. 检查 Contact Name、国际格式电话号码和邮箱均可联系。
8. 若只是审核资料问题，可在补全信息后继续使用同一 Build；若真机复核发现崩溃、CloudKit Production 不可用、iPad 阻断问题或上传包与 `main` 不一致，则先修复并提交新 Build。

## 6. 发送前发布核对

- [ ] 第 1 节不存在任何 `[[...]]` 占位符。
- [ ] 录屏来自真实设备、最新正式系统，并从启动 App 开始。
- [ ] Device/OS 清单只包含真实完成的测试，提交前与补测证据分开写。
- [ ] iPhone 核心流程通过；由于当前支持 iPad，iPad 核心流程也已实际验证。
- [ ] 相机、相册首次授权、拒绝后的手动回退均验证。
- [ ] Frankfurter 在线刷新和离线/手动回退均验证。
- [ ] CloudKit Production 环境、正式 Container 和真实 Apple ID 同步已验证；否则不要把同步描述成已通过。
- [ ] CSV/PDF/备份与 Share Sheet 在真机验证。
- [ ] 支持页和隐私政策可公开访问，并包含真实联系方式。
- [ ] 回复中没有“实时汇率”“保证最低成本”“保证到账”等无法支持的承诺。
- [ ] 实际上传 Build 确认为原生 `main` 版本，不包含 `h5` 分支或未披露的交易功能。
- [ ] 所有样例数据均为虚构，不包含真实姓名、卡号、票据或 Apple ID 信息。

## 7. 事实边界与当前证据

本文件的功能说明以 `883ae5b` 历史源码与合规文档为参考，文案中的当前名称为 RhinoSmart。以下事实须与实际待提交版本重新核对，不能由品牌替换推断本次已验证：

- 无 RhinoSmart 登录、内购、订阅、广告或公开 UGC。
- 相机/相册按用户操作请求；OCR 使用本机 Apple Vision。
- 结构化 iCloud/CloudKit 同步为可选功能，票据原图不进入 CloudKit。
- 汇率来自 Frankfurter 公共 API，并可能经过 Cloudflare。
- 支付方式仅保存用户输入的名称和费用规则，不保存卡号、CVV 或银行凭据。
- 汇率、支付成本和 DCC 均为参考估算，不执行金融交易。

当前不能由本文档代替的证据：真机最新版系统录屏、实际设备测试清单、CloudKit Production 双设备验证、iPad 真机验证、Archive/TestFlight 与上传 Build 一致性。完成这些验证后，才可把相应占位符改成确定陈述。

## 8. Apple 官方依据

- App Review Guidelines 2.1 要求完整元数据、可访问的服务以及真机稳定性验证：<https://developer.apple.com/app-store/review/guidelines/>
- App Review Information 的 Notes 用于填写测试设置和账号等审核信息，最多 4000 bytes：<https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information>
- 审核消息可以附加录屏和支持材料；若属于元数据问题，可修正后继续使用同一 Build：<https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/reply-to-app-review-messages>
