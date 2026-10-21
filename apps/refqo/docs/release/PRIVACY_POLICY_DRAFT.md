# Refqo privacy policy draft — not a published policy
Date: 2026-10-21. Developer legal identity, real contact channel and public policy/support URLs must be supplied before publication. No legal or contact facts have been invented.

Refqo has no account, developer backend, advertising or analytics. Supply names, part codes, fit notes, quantities, linked appliance labels, dates, inventory events and preferences are stored in the app's local storage. They may reveal household information. We do not automatically send this library to a developer service.
The system file picker reads only the file the user selects. Backups are unencrypted, readable JSON. Export and shopping-list sharing use destinations selected by the user, whose handling may differ. System backups and file providers can use cloud storage; Android automatic backup is disabled in this build, while iOS system backup may apply. No broad storage, camera, contacts, location or notification permissions are requested.
The app keeps the prior local save for recovery and retains an unreadable original when explicitly restoring after corruption. “Erase local library” clears app-managed library/recovery files. It cannot delete copies already exported, shared or backed up by the system. Uninstalling may delete local data. Export a backup before device changes.
A sharing operation creates a temporary backup for the share sheet and removes it when the operation returns. Process interruption can leave a temporary cache copy until the next app launch or explicit erasure retries cleanup (or OS eviction); this is a retained local copy, not developer collection. This boundary must be reflected in the published retention policy.
No digital purchases, personalized recommendations, automatic compatibility checks, safety/lifespan advice or medical services are provided. Replacement dates are user-configured planning estimates.

## 中文草案
Refqo 无需账号，没有开发者后台、广告或统计服务。耗材、型号、适配备注、库存、设备标签、日期、流水和偏好设置保存在本机，可能涉及家庭资料，不会自动发送至开发者服务器。
仅通过系统文件选择器读取你选择的文件。备份为可读明文 JSON；分享目标与文件提供方可能使用云端。Android 自动备份已关闭，iOS 系统备份仍可能生效。不申请广泛存储、相机、通讯录、位置或通知权限。
应用保留上次本机保存副本；损坏恢复时保留原文件。“清除本机资料库”删除应用管理的资料与恢复文件，无法删除已导出、已分享或系统备份的副本。卸载可能删除本机资料，请提前备份。
分享返回后会清理临时备份；进程意外中断可能留下缓存副本，将在下次启动或主动清除时再次清理，系统也可能清理。正式发布前必须补齐真实开发者身份、联系方式和公开政策网址。
