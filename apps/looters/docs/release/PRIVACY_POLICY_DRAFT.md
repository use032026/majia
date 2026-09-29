# PaceJar · 节奏罐隐私政策草案

状态：仅供本地发行准备。发布前必须补充负责主体、受监控的联系邮箱和公开 HTTPS 地址，并按最终签名构建、SDK 清单、首发地区及适用法律复核。生效日期暂定为 2026-09-29。

## 我们处理什么

PaceJar 不要求账号。你输入的目标名称、币种符号、目标金额、已存金额、日期、储蓄或取出事件、跳过记录、计划版本和备注会保存在设备上的应用沙盒中。金额与备注可能反映个人财务情况，但应用不要求银行账号、支付卡、身份证明、精确位置、通讯录、健康或生物识别数据。

## 数据如何使用与传输

这些本地数据只用于计算和展示计划进度、恢复方案、时间线与复盘摘要。当前版本没有应用自有服务器，不连接银行，不创建账号，不集成广告或分析 SDK，也不把这些数据发送给开发者或第三方。

当你主动点击“复制摘要”时，应用会把可见的纯文本摘要写入系统剪贴板。之后的粘贴、同步或共享由操作系统及你选择的其他应用处理；请不要把剪贴板当作加密备份。操作系统级设备备份或迁移也受你的设备和云服务设置控制，不由 PaceJar 管理。

## 权限、跟踪与第三方组件

当前版本不请求相机、照片、麦克风、位置、通讯录、蓝牙或通知等敏感系统权限，不包含跨 App/网站跟踪，也不出售或分享个人数据。归档中嵌入 Flutter 与 `shared_preferences_foundation`；它们用于界面运行和本地偏好存储，不改变上述数据流。最终发布前仍须用 Xcode Privacy Report 和 App Store Connect 隐私问卷复核这一描述。

## 保留、删除与导出

数据会一直保留在应用沙盒中，直到你在设置中选择“删除全部数据”、卸载应用，或由操作系统清除。删除操作会清除当前目标、事件和计划版本，应用自身无法恢复。当前版本不提供云同步或文件备份。你可以在删除前复制复盘摘要，作为由你自行保管的纯文本记录。

## 儿童、金融服务与安全边界

PaceJar 是手动计划工具，不转移、托管、存入或提取真实资金，也不提供投资、信贷、收益承诺或个性化财务建议。产品并非专门面向儿童。请勿在自由文本中录入银行凭证、支付卡号、身份证号或其他不必要的敏感信息。

## 变更与联系

如数据处理发生实质变化，应先更新本政策和 App Store 隐私回答，再发布相应版本。正式发布前必须在此处写入负责主体、隐私/支持联系邮箱和稳定公开的 HTTPS 隐私政策地址；这些信息当前缺失，因此本草案不能直接用于提交。

---

# PaceJar Privacy Policy Draft

Status: local release-preparation draft only. Before publication, add the responsible legal entity, a monitored contact address, and a public HTTPS URL, then re-check this text against the final signed build, SDK inventory, launch regions, and applicable law. Proposed effective date: September 29, 2026.

PaceJar requires no account. Goal names, currency symbols, target and saved amounts, dates, deposit or withdrawal events, skipped periods, plan versions, and notes are stored in the app sandbox on your device. The app uses this information only to calculate and display pace, recovery choices, the timeline, and a recap.

The current version has no PaceJar backend, does not connect to a bank, and includes no advertising or analytics SDK. It does not transmit this local content to the developer or third parties. If you tap Copy recap, the visible plain-text recap is written to the system clipboard; later pasting, syncing, or sharing is controlled by your operating system and the apps you choose. Device backup and migration likewise depend on your platform settings.

The current version requests no sensitive system permissions and performs no cross-app or cross-website tracking. Data stays in the app sandbox until you use Delete all data, uninstall the app, or the operating system removes it. Deletion removes the current goal, events, and plan versions and cannot be undone by the app. There is no cloud sync or file backup in this version.

PaceJar is a manual planning tool. It does not move, hold, deposit, or withdraw real money and does not provide investment, credit, return guarantees, or personalized financial advice. Do not enter bank credentials, card numbers, government identifiers, or other unnecessary sensitive information in free-text fields.

Before release, this section must identify the responsible entity, privacy/support email, and public policy URL. Until then, this draft is not publication-ready.
