# PaceJar · 节奏罐功能审核报告

审核日期：2026-09-29

独立 Functional Reviewer 结论：`passed`，未发现开放 P0/P1。结论覆盖源码、unit/widget 测试及本轮已操作的 iOS 模拟器路径；不代表真机、VoiceOver/TalkBack、签名、上传或 App Store 审核通过。

## Findings

| 优先级 | 需求/流程 | 发现 | 用户影响 | 证据 | 修复验收标准 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | 本地载入 | 非 `FormatException` 的读取失败原会落入空状态并允许覆盖旧记录 | 潜在本地数据丢失 | `loadFailure` + retry-only 页；Controller + Widget 回归 | 失败期间无 goal 写入，重试后恢复原记录，`saveCalls=0` | closed |
| P1 | 过期恢复 | 过期目标原可追加一个仍在过去的 keep-date 计划 | 成功提示后仍无法恢复 | Calculator 拒绝过期 keep-date，UI 禁用并解释；unit/controller/widget 回归 | 无效操作不追加版本，可行方案日期在未来 | closed |
| P2 | 序列化 | 领域对象原依赖 `assert` 防护 0 周额、负事件和非法取出历史 | Release 下可接受语义损坏数据 | 显式 `FormatException` + 损坏矩阵单测 | 所有非法记录进入 corrupt 隔离，无除零/负余额 | closed |
| P2 | 完成态删除 | 清除失败原无可见反馈 | 用户无法判断是否已删除 | `ErrorBanner` + `failClear` Widget 回归 | 失败时原记录保留并显示重试，成功后进入干净创建页 | closed |
| P2 | 平台回归 | 尚未完成真机、屏幕阅读器、低存储/后台中断和 Android 模拟器运行 | 实际设备问题仍可能存在 | 本报告“未测试层” | 使用最终签名候选在目标设备补齐证据 | open |

## 核心闭环

| 环节 | 结论 | 证据与边界 |
| --- | --- | --- |
| 输入/取消/失败 | passed | 金额边界、表单保留、按钮/遮罩取消重入、保存/载入/删除失败均有 unit/widget 证据 |
| 核心处理 | passed | 整数 cents；计划/实际双轨；跳过当周立即进入 recovery；恢复预览纯函数且可重现 |
| 用户确认/撤销 | passed | 记录弹层支持取消；计划仅在确认后追加；永久删除需二次确认 |
| 状态重算 | passed | 新事件/计划后立即重算；App resumed 通知刷新；跨周运行尚无真机证据 |
| 持久化/恢复/删除 | passed | save-before-commit、版本 JSON、date-only 截止日、损坏隔离，模拟器重装 App 后数据仍可读 |
| 输出/分享 | passed with limit | 复盘摘要与剪贴板失败 unit 证据；未在真机验证系统剪贴板 |
| 中英文/深色/响应式/无障碍 | passed with limit | 中英切换与深色模式已操作；320×568@2x Widget、iPhone 17 Pro Max 及 iPad Pro 13 模拟器已看；未做 VoiceOver/TalkBack |
| 页面层级/长内容/滚动可达性 | passed with limit | iPhone 节奏/恢复/时间线和 iPad 宽屏已复核；1000 条压力数据未运行 |
| 弹层/路由关闭及重入 | passed with limit | 按钮与遮罩取消后重开为空；未验证拖拽/系统返回和保存中关闭 |
| 离线/隐私边界 | passed with limit | 无账号、后端、分析、广告或银行 SDK；未做网络封包真机观测 |

## UI 与交互验收矩阵

| 页面/状态 | 设备与系统 | 语言/外观/字号 | 内容压力与交互路径 | 结果 | 截图/日志/测试 |
| --- | --- | --- | --- | --- | --- |
| 空状态/创建/节奏 | iPhone 17 Pro Max, iOS 26.5 Simulator | 中文/浅色/系统字号 | 创建 12,000 目标，记录 250，跳过当周 | passed | `evidence/screenshots/iphone-17-pro-max-pace-zh-final-raw.png` |
| 记录弹层 | iPhone 17 Pro Max, iOS 26.5 Simulator | 中文/浅色 | 打开、取消、重开、保存存入与跳过 | passed | CUA AX 运行记录 + `core_flow_widget_test.dart` |
| 恢复选择 | iPhone 17 Pro Max, iOS 26.5 Simulator | 中文/浅色 | 保持日期/周额/自定，预览周额与日期 | passed | `store-screenshots/zh-iPhone-6.9/02-recovery.png` |
| 时间线 | iPhone 17 Pro Max, iOS 26.5 Simulator | 中文浅色 + 英文深色 | 2 事件 + 2 计划版本 | passed | `store-screenshots/zh-iPhone-6.9/03-timeline.png`；`en-iPhone-6.9/01-timeline-dark.png` |
| 宽屏节奏 | iPad Pro 13-inch (M5), iOS 26.5 Simulator | 中文/浅色 | 同一数据集（模拟器容器拷贝植入） | passed | `store-screenshots/zh-iPad-13/01-pace.png` |
| 2× 大字小屏 | Widget 320×568 logical px | 中文/2× | 节奏主操作与记录弹层 | passed | `responsive_accessibility_test.dart` |

## 关闭记录与自动化

1. 首轮独立审核为 `needs_revision`：1 个 P0 和 1 个 P1。修复后第二轮为 `passed`。后续又关闭损坏态契约、删除失败反馈和过期文案。
2. 首次全量门禁暴露图标文件名错误，Android 资源合并失败；重新生成后通过。Store 复核又发现 SVG 曲线路径未进入 raster 与默认 LaunchImage，改为兼容几何图标和品牌启动页后再次跑全量门禁。
3. `docs/release/evidence/automation/20260929T175103+0800/QUALITY_GATE.md`：format passed，analyze 零问题，29 tests passed，Android debug APK 与 iOS unsigned archive passed，启动模板警告已消失。

## 未测试层

- 实体 iPhone/iPad/Android，iOS 15 最低系统，低内存/低存储，后台中断和真实跨周恢复。
- VoiceOver/TalkBack、完整 Dynamic Type、横屏、键盘焦点恢复、拖拽/系统返回关闭。
- 真实剪贴板失败、系统备份/还原、1000 条时间线、Android 运行态。
- 签名 Release、TestFlight、App Store 上传/处理/审核；本次按要求没有上传。
