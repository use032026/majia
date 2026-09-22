# 微成 · Steady21 功能审核报告

审核日期：2026-09-22
独立审核结论：`passed`。第三轮复核无开放 P0、P1、P2；结论覆盖源码、静态分析、24 项单元/Widget 测试和已记录的 iOS 模拟器观察，不外推到真机、签名上传或 App Review。

## Findings 与关闭记录

| 优先级 | 第一/二轮发现 | 修复与验收证据 | 最终状态 |
| --- | --- | --- | --- |
| P1 | 归档后完整报告、逐日记录和复盘不可回看 | 归档展开区现包含实验定义、统计、阶段、复盘、逐日记录；有 active 同时存在时仍可只读查看；Widget 回归覆盖 | closed |
| P1 | 改正/撤销后可能保留尚未达到的里程碑复盘，并在编辑时抛异常 | 保存/撤销会清理高于当前练习数的复盘；Sheet 捕获 `milestone_not_reached`；控制器与 Widget 回归覆盖 | closed |
| P2 | 今天明确暂停仍显示昨天的当前连续 | 明确暂停当天 `currentStreak == 0`；单元测试覆盖 | closed |
| P2 | 从暂停改正为完成可能残留隐藏恢复策略 | 不需要恢复时强制清空策略；恢复数只统计实际恢复练习；单元测试覆盖 | closed |
| P2 | “删除全部”声称删除设置，实际保留语言 | 文案改为删除实验与记录并明确保留语言；单元测试覆盖 | closed |
| P2 | 固定 24 小时日期差可能在夏令时边界误判 | 改为 UTC civil-day 序号；春/秋切换日期测试覆盖 | closed |
| P2 | 英语系统首次安装仍默认中文 | 无存档时按系统语言选择中文/英文，不支持语言回退中文；仓储测试覆盖英文默认 | closed |
| P1 | 归档后的时间型统计会继续衰减 | 归档统计以 `archivedAt` 冻结；长标题、较早归档日与 `100%` 回归断言覆盖 | closed |
| P2 | 归档长标题永久省略 | 折叠摘要可省略，展开报告展示无 `maxLines` 的完整标题 | closed |

最终明确：未发现开放 P0/P1/P2。

## 核心闭环

| 环节 | 结论 | 证据与边界 |
| --- | --- | --- |
| 输入/取消/失败 | passed | 创建、今日记录、复盘、删除确认均覆盖取消/返回；保存失败采用 save-before-commit，不改变旧状态 |
| 核心处理 | passed | 单一 active、标准/最低/暂停、阻碍与恢复、7/14/21 复盘、称号边界由领域测试覆盖 |
| 用户确认/撤销 | passed | 当日记录可改正与确认撤销；破坏操作有确认对话框 |
| 自动重算 | passed | 修改/撤销后统计和有效复盘从源记录重算；归档报告以归档日冻结 |
| 持久化/恢复/删除 | passed | JSON 往返、临时文件原子替换、损坏数据不覆盖、删除与语言保留有测试；真机重启未测 |
| 输出/分享 | passed in scope | 应用内报告和归档可回看；MVP 明确不含导出/分享 |
| 中英文/深色/响应式/无障碍 | passed with limits | 中英、系统深浅色、手机/平板和 1.6 倍文字已观察或测试；VoiceOver/TalkBack 未测 |
| 页面层级/长内容/滚动可达性 | passed | iPad 31 条压力数据可到报告尾部；320×568、1.6 倍文字 Widget 可到核心操作；归档长标题测试通过 |
| 弹层/路由关闭及重入 | passed | 创建、今日记录、里程碑复盘、删除确认覆盖关闭/取消/重开，不产生幽灵状态 |
| 离线/隐私边界 | passed in scope | 无网络、账号、分析、广告依赖；本地 JSON；未做真机飞行模式验证 |

## UI 与运行验收矩阵

| 页面/状态 | 设备与系统 | 语言/外观/字号 | 内容压力与路径 | 结果 | 证据 |
| --- | --- | --- | --- | --- | --- |
| 今日空状态、创建、今日记录 | iPhone 16e 模拟器 / iOS 18.3 | 中英、浅色/深色、系统较大字号 | 创建 -> 保存 -> 标准/最低记录 -> 改正/撤销入口 | 所检查路径无阻断或明显裁切 | `docs/release/evidence/runtime/iphone-16e-ios18_3-today-en-light.png`；运行观察 |
| 历程顶部与完整阶段路径 | iPad Pro 11-inch (M4) 模拟器 / iOS 18.3 | 英文/浅色 | 31 天、长标题/线索/行动、7/14/21 复盘 | 卡片响应式排列，内容可读 | `docs/release/evidence/runtime/ipad-pro-11-ios18_3-journey-top.png` |
| 历程长列表尾部 | 同上 | 英文/浅色 | 31 条逐日记录滚动到底 | 尾部可达，无底栏遮挡关键记录 | `docs/release/evidence/runtime/ipad-pro-11-ios18_3-journey-tail.png` |
| 紧凑屏与大字 | Widget 320×568 | 英文/1.6 倍 | 长双语内容滚动到核心按钮 | passed | `test/widget_test.dart` |
| 归档完整报告 | Widget | 中文长标题；归档日早于当前日 | 有新 active 时展开归档、查看定义/统计/复盘/记录 | passed；恢复按钮按单 active 规则禁用，但报告可读 | `test/widget_test.dart` |

## 自动化结果

- 最终门禁：`docs/release/evidence/automation/20260922T130811+0800/QUALITY_GATE.md`，verdict `passed`。
- 格式检查、`flutter analyze`、24 项 `flutter test`、Android Debug APK、iOS Release 无签名 Archive 均通过。
- 独立 Functional Reviewer 在最终代码上再次运行 analyze/test，结论 `passed`。

## 未测试层

- 实体设备、iOS 15 最低系统、Android 实机、低内存/低存储、后台中断、进程终止后的完整交互恢复。
- 真机飞行模式、跨时区、系统时间倒退、午夜前后运行；civil-day 逻辑有单测但不等于平台运行验证。
- VoiceOver/TalkBack、完整 Dynamic Type 阶梯、横屏、色觉与开关控制。
- 签名 Release、安装、公开 URL、ASC 元数据、上传、处理、TestFlight 与 App Review。
