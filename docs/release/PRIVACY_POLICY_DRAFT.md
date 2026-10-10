# Almanac 隐私政策草案 / Privacy Policy Draft

状态：仅本地草案，不能直接发布。发布前必须由最终开发者主体审核，替换方括号内容，并按最终签名包、SDK 清单、首发地区与适用法律复核。

生效日期：2026-10-10

开发者/Developer：`[法定主体名称 / Legal entity name]`

隐私联系/Privacy contact：`[受监控的邮箱或联系表单 / Monitored email or form]`
公开地址/Public URL：`[稳定的公开 HTTPS URL / Stable public HTTPS URL]`

## 中文

### 产品与账号

Almanac 是离线优先的每日反思工具，不提供账号系统、广告、订阅或开发者自有后台。它使用本机规则组合项目原创的双语提示与短诗，让用户选择一项“宜/Try”、一项“忌/Skip”，可选写下一句意图并稍后回看。

### 应用处理的数据

- 本机安装种子：用于让同一设备同一天的内容保持稳定。
- 用户选择、可选意图、回看结果、语言和外观偏好。
- 以上内容保存在应用本地存储。当前实现不把这些内容发送到开发者服务器，也不包含广告或分析 SDK。
- 用户主动选择“复制岁时册”时，导出内容会进入系统剪贴板；之后由操作系统和用户选择的其他应用处理。
- 操作系统备份、设备迁移、系统诊断或用户主动复制可能使本地内容离开设备，这些流程由相应平台或用户控制。

Almanac 不要求用户输入身份、健康、财务、位置、联系人或儿童数据。意图字段是自由文本；请不要写入不希望保存在设备或系统备份中的敏感信息。

### 权限与第三方组件

当前版本不申请运行时权限。包内组件限于 Flutter 运行时和本地偏好存储组件。发布前将以最终签名包重新核对第三方 SDK、隐私清单与商店隐私回答。

### 保留、删除与导出

记录会留在应用本地，直到用户在设置中确认“清除全部日笺”、卸载应用，或由操作系统存储/备份机制处理。清除日笺会删除应用管理的选择、意图与回看记录，并保留语言、外观与安装种子。Markdown 复制是可读导出，不是可恢复备份。

### 儿童、跨境与变更

本产品不专门面向儿童。当前实现不向开发者服务器传输数据，因此没有由开发者发起的跨境传输；系统备份或用户主动复制不属于开发者服务器传输。若功能、SDK、商业模式或数据处理发生变化，本政策与商店披露必须在发布前同步更新。

### 联系

隐私问题请联系 `[隐私联系]`。发布版本必须在这里列出与商店开发者记录一致的法定主体与联系方式。

## English

### Product and account model

Almanac is an offline-first daily reflection tool. It has no account system, ads, subscriptions, or developer-operated backend. Local rules compose original bilingual prompts and verse so a user can choose one Try, one Skip, optionally write an intention, and reflect later.

### Data handled by the app

- A local installation seed keeps same-device, same-day content stable.
- User choices, optional intentions, reflection outcomes, language, and appearance preferences.
- This information is stored in the app's local storage. The current implementation does not send it to a developer server and includes no advertising or analytics SDK.
- When the user chooses to copy the folio, exported text is placed on the system clipboard and may then be handled by the operating system or apps the user selects.
- Operating-system backup, device migration, diagnostics, or user-initiated copying may move local content off the device under the platform's or user's control.

Almanac does not ask for identity, health, financial, location, contacts, or children's data. The intention field accepts free text; users should avoid entering sensitive information they do not want stored on the device or in system backups.

### Permissions and third parties

The current version requests no runtime permissions. Packaged components are limited to the Flutter runtime and local preferences storage. The final signed build, SDK inventory, privacy manifests, and store disclosures must be audited again before publication.

### Retention, deletion, and export

Records remain in local app storage until the user confirms Clear All Daily Leaves, uninstalls the app, or the operating system handles storage or backups. Clearing records removes app-managed choices, intentions, and reflections while retaining language, appearance, and the installation seed. Markdown copy is a readable export, not a restorable backup.

### Children, transfers, and changes

The product is not directed to children. The current implementation does not transmit data to a developer server, so the developer initiates no cross-border transfer. System backups and user-initiated copies are outside that developer-server flow. This policy and store disclosures must be updated before release if features, SDKs, monetization, or data handling change.

### Contact

For privacy questions, contact `[privacy contact]`. The published version must identify the responsible legal entity and contact method consistently with the store listing.
