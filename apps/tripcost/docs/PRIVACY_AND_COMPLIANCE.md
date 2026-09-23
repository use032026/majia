# TripCost 隐私、数据流与发布合规清单

> 适用版本：V1.0；复核日期：2026-09-23

## 1. 用户可见隐私政策（简体中文）

TripCost 无需注册账户，也不保存完整卡号、CVV、身份证件或银行登录信息。行程、消费、设置和票据图片默认保存在本机；OCR 使用 Apple Vision 在本机执行，票据原图不会上传。

启用 iCloud 同步后，行程、消费、支付方式、汇率快照引用和用户设置等结构化数据会发送到用户自己的 CloudKit 私有数据库。票据原图不进入 CloudKit。关闭同步不会删除本地数据。

市场参考汇率请求会发送到 Frankfurter 公共 API。Frankfurter 当前声明 API 本身不收集个人数据；其公共服务使用 Cloudflare，可能收集基础分析信息。CSV、PDF 和备份均在本机生成，只有用户在 iOS 系统分享面板中选择目标后才会离开应用。行程摘要 PNG 仅在用户点击“保存到相册”后添加到系统照片图库；是否通过 iCloud 照片同步由用户的系统设置决定。

相机与相册读取权限仅在用户点击相应扫描入口后请求；相册仅添加权限仅在用户点击“保存到相册”后请求。定位和通知不是 V1.0 的必要权限。

## 2. User-facing privacy policy (English)

TripCost does not require an account and does not store full card numbers, CVV, identity documents, or banking credentials. Trips, expenses, settings, and receipt images are stored on this device by default. OCR runs locally with Apple Vision, and original receipt images are not uploaded.

When iCloud sync is enabled, structured data such as trips, expenses, payment methods, rate-snapshot references, and user settings is sent to the user’s private CloudKit database. Original receipt images are excluded. Turning sync off does not delete local data.

Market reference-rate requests are sent to the Frankfurter public API. Frankfurter currently states that its API does not collect personal data; its public service uses Cloudflare and may collect basic analytics information. CSV, PDF, and backups are generated locally and leave the app only after the user chooses a destination in the iOS share sheet. A trip-summary PNG is added to the system photo library only after the user taps Save to Photos; iCloud Photos synchronization follows the user's system settings.

Camera and photo-library read access are requested only after the user chooses the matching scan action. Add-only photo-library access is requested only after the user taps Save to Photos. Location and notifications are not required in V1.0.

## 3. 免责声明 / Disclaimer

- 汇率和费用估算仅供参考，不构成金融或投资建议。
- 汇率为每日参考数据，可能来自缓存或存在延迟；不得描述为实时汇率。
- 银行、卡组织、支付机构和商户政策可能变化，授权日与清算日也可能不同。
- 实际入账以发卡行、卡组织、支付机构和商户最终处理结果为准。
- DCC 比较不保证具体交易结果，也不保证绝对最低成本。
- Rates and cost estimates are reference information, not financial or investment advice.
- Rates are daily reference data and may be cached or delayed; they must not be marketed as real-time rates.
- Final posted amounts are determined by the issuer, card network, payment provider, and merchant.
- DCC comparisons do not guarantee a transaction result or the lowest possible cost.

## 4. 数据流清单

| 数据 | 默认位置 | 外发条件 | 接收方 | 清理边界 |
| --- | --- | --- | --- | --- |
| 行程、消费、支付方式、设置 | Drift 本地数据库 | 用户开启 iCloud 同步 | 用户的 CloudKit 私有数据库 | “清除全部数据”删除本地库、同步状态和墓碑 |
| 票据原图 | App 私有目录 | V1.0 不外发 | 无 | 可单独清除；全量清除也会删除 |
| OCR 图片内容 | 本机内存/临时路径 | 不外发 | Apple Vision 本机框架 | 扫描流程结束后不作为云数据保存 |
| 汇率请求 | 不包含账户或票据 | 在线刷新汇率 | Frankfurter 公共 API，经 Cloudflare | 汇率缓存可随全量清除删除 |
| Widget 摘要 | App Group 最小只读 JSON | 主 App 更新摘要 | 本机 Widget Extension | 全量清除先删除共享快照 |
| CSV/PDF/备份 | App 临时目录 | 用户主动使用 Share Sheet | 用户选择的系统目标 | 系统/临时目录生命周期管理 |
| 行程摘要 PNG | 生成时位于本机内存 | 用户主动点击“保存到相册” | 系统照片图库 | 由用户在“照片”中管理；iCloud 照片同步遵循系统设置 |

## 5. 权限与配置复核

- `NSCameraUsageDescription`：英文基线与 `en`/`zh-Hans` 本地化用途字符串已配置，说明本机识别且不上传。
- `NSPhotoLibraryUsageDescription`：英文基线与 `en`/`zh-Hans` 本地化用途字符串已配置，说明本机识别且不上传。
- `NSPhotoLibraryAddUsageDescription`：英文基线与 `en`/`zh-Hans` 本地化用途字符串已配置，说明保存用户生成的行程摘要。
- 相机/相册读取权限由扫描页的用户操作触发，相册仅添加权限由摘要预览页的保存按钮触发；启动、首页、设置页不预先请求。
- 未声明定位、通讯录、麦克风、跟踪等非必要权限。
- V1.0 支付方式模型仅保存费用规则、名称、卡组织和账单币种，不包含卡号、有效期、CVV 或银行凭据字段。

## 6. Provider 与发布复核

- Frankfurter 官方文档在 2026-08-17 表示公共 API 可商业使用、无 API key，并要求同时关注底层 provider 的条款；V2 默认结果可能由多家 provider 混合。
- App 内和导出文件展示每笔保存的 `sourceName` 与汇率日期，不把参考汇率描述为实时数据。
- M9 上架前必须根据实际返回的 provider 集合再次核对署名/再分发条款；这一步不能由本次静态实现替代。
- App Store 文案不得使用“保证到账”“实时汇率”“绝对最优/最低”等表达。

参考：[Frankfurter 官方文档](https://frankfurter.dev/)、[Apple 相机用途字符串](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription)、[Apple 相册用途字符串](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryusagedescription)。
