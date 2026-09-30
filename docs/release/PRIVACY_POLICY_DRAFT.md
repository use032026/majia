# 回声页 · EchoPage（工作名，未做商标可用性确认） Privacy Policy Draft

Status: local draft only. It must be reviewed against the final app, final SDK inventory, launch regions, applicable law, and the responsible legal entity before publication.

Effective date: 2026-09-30

## Product and account model

- Product: 回声页 · EchoPage（工作名，未做商标可用性确认）
- Account model: 无账号
- Backend/offline model: 离线优先，无应用自有后台
- Monetization: 免费且无 IAP；如有变化必须重新审核

## Data handled

用户主动输入的日记正文、标题、未来问题、后记和变化标记，以及语言和外观设置，会以 JSON 文件保存在应用沙盒中。当前版本没有账号、开发者自有后台、分析 SDK、广告 SDK、远程配置或应用内购买，也不会把日记内容发送给开发者。

日记可能包含用户自愿写入的私人内容。产品不要求姓名、联系方式、身份、健康、金融、儿童、精确位置或通讯录数据，也不作诊断或治疗承诺。用户仍应避免在不需要时写入敏感个人信息。

## Permissions

无运行时权限

当前版本不申请相机、照片、麦克风、位置、通知、通讯录或跟踪权限。若后续版本增加权限，本政策、App Store 隐私回答与应用内说明必须在发布前同步更新。

## Collection, tracking, sharing, and third parties

按 2026-09-30 的当前源码与依赖清单，应用不包含账号、广告或分析服务，不进行跨应用跟踪，也不向开发者或第三方业务服务传输日记内容。应用使用 Flutter 框架和 `path_provider` 取得平台提供的应用文档目录；最终发布前仍需用最终 Archive 的依赖清单、Privacy Manifest 和 Xcode Privacy Report 复核本段，并据此填写 App Store Connect 隐私问卷。

操作系统提供商可能依据用户的系统设置和其自身政策处理设备备份、iCloud/Google 备份、设备迁移或恢复。此类系统服务不是开发者自有的同步服务，开发者不能读取其中的日记内容。

## Retention, deletion, export, and consent withdrawal

- 内容会保留在当前安装的应用沙盒中，直到用户在 App 内删除、清空数据，或按平台行为卸载 App。
- 普通删除先移入“最近删除”，用户可恢复。永久删除、清空最近删除和清空全部会净化当前安装中的主数据文件、待写文件与应用内恢复备份；这些操作无法在 App 内撤销。
- 历史设备/iCloud/Google 系统备份可能仍含较早副本。系统备份的保留、删除、迁移与恢复由操作系统和用户设置控制，开发者不能替用户查看或删除。
- 应用不提供开发者自有的云同步、自动备份或文件导入。用户只有在主动选择“复制完整记录”时，内容才会写入系统剪贴板；随后由用户选择的其他应用和操作系统负责该副本。
- 因为没有账号或开发者服务器，不存在服务器端账号删除入口。用户可在设置中清空当前安装的全部内容，并在系统设置中管理平台备份。

## Contact

发布前必须填写负责主体的法定名称、持续监控的隐私/支持联系方式，以及与 App Store Connect 完全一致的稳定公开 HTTPS 隐私政策 URL。当前草稿没有这些生产信息，不能直接发布。
