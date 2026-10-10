# Almanac 功能审核报告

审核日期：2026-10-10

独立审核结论：`passed`（源码、自动化与已执行的模拟器路径）。三轮独立复核后未发现开放 P0/P1。该结论不扩大为实体设备、签名发布包或商店审核通过。

## Findings

| 优先级 | 需求/流程 | 发现 | 修复与验收证据 | 状态 |
| --- | --- | --- | --- | --- |
| P0 | FR-03 / 输入边界 | TextField 按用户感知字符计数，控制器原按 UTF-16 计数，表情可能在封笺时抛异常 | 统一为 grapheme 计数；140 个表情可保存，141 个在输入层截断；控制器与 Widget 回归 | closed |
| P0 | FR-01 / 日期轮换 | 前台跨午夜的短窗口可能把昨日选择提交给新日笺 | 30 秒定时与恢复前台刷新；直接提交旧 ID 时只生成新日笺、返回 false、显示双语重选提示；不会抛异常或误写 | closed |
| P1 | FR-04 / 写入失败 | 已封笺回看与设置写入失败缺少就地反馈 | 错误在当前页面显示，旧内存/磁盘不替换，可原地重试；反思和设置均有 Widget 回归 | closed |
| P1 | FR-04 / 损坏数据 | 已移除或未知 prompt ID 可能在渲染/导出时抛异常 | 载入时校验日期键、候选侧别、选中项与成句；未知 ID fail-closed 到恢复页且保留原始数据 | closed |
| P2 | FR-06 / 导出 | 中文导出曾出现英文 enum，用户文字可能破坏 Markdown | 三种回看结果中英文本地化；换行归一、Markdown 特殊字符转义；自动化回归 | closed |
| P2 | FR-08 / 大字号 | 固定摘要标签与不可滚动弹层有溢出风险 | 标签改为最小约束加内边距；弹层可滚动；360×640、200% 字号完成真实点击闭环 | closed |
| P2 | FR-02 / 设置 | 主题选中态可能引用旧数据对象 | 数据读取移入 AnimatedBuilder；深色选中图标回归 | closed |
| P2 | FR-08 / 辅助功能 | 模拟器树发现设置项存在重复的无标签子按钮 | 合并为单一具名、可选中语义按钮；iPad iOS 18.3 辅助功能树复验 | closed |

## 核心闭环

| 环节 | 结论 | 证据与边界 |
| --- | --- | --- |
| 输入/取消/失败 | passed | 空意图、140 字、141st emoji、弹层遮罩取消、保存失败均有回归 |
| 核心处理 | passed | 日期 + 安装种子 + 生成器版本确定性生成；365 天内容约束测试 |
| 用户确认/撤销 | passed | 封笺前必须各选一项；删除有二次确认；无账号/购买路径 |
| 自动复检或状态重算 | passed | 启动、恢复前台、定时器和直接点击竞态均处理日期变更 |
| 持久化/恢复/删除 | passed | 写成功后才提交内存；损坏读取锁定；清除保留偏好与安装种子 |
| 输出/分享 | passed with limit | Markdown 内容、顺序、本地化与转义有测试；系统剪贴板只在 iOS 模拟器操作路径中间接验证 |
| 中英文/深色/响应式/无障碍 | passed with limits | 自动化 + iPhone/iPad 实看；Android 仅启动页；VoiceOver/TalkBack 实际朗读未执行 |
| 页面层级/长内容/滚动可达性 | passed | iPhone 英文浅色长输入、中文深色；iPad 中文；360×640 200% Widget 闭环 |
| 弹层/路由关闭及重入 | passed | 回看取消、动画结束后重开、选择、笺册详情关闭均验证 |
| 离线/隐私边界 | passed at static scope | 无网络客户端、后台、账号、广告、分析或运行时权限；未做抓包与系统备份恢复测试 |

## UI 与交互验收矩阵

| 页面/状态 | 设备与系统 | 语言/外观/字号 | 内容压力与交互路径 | 结果 | 截图/测试 |
| --- | --- | --- | --- | --- | --- |
| 首次页、今日、封笺、回看、笺册详情 | iPhone 16 Pro / iOS 18.3 模拟器 | 英文浅色 / 100% | 选择、键盘输入、封笺、弹层、回看、详情关闭 | passed | `docs/release/evidence/ui/ios-iphone16pro-*` |
| 设置、已收笺 | iPhone 16 Pro / iOS 18.3 模拟器 | 中文深色 / 100% | 语言与主题切换、隐私与内容说明 | passed | `docs/release/evidence/ui/ios-iphone16pro-zh-dark-*` |
| 首次页、今日、设置语义 | iPad Pro 11-inch M4 / iOS 18.3 模拟器 | 中文浅色 / 100% | 宽屏布局、滚动末端、设置项 AX 名称与选中态 | passed | `docs/release/evidence/ui/ios-ipad11-*` |
| 首次页、今日 | iPad Pro 13-inch M4 / iOS 18.3 模拟器 | 英文浅色 / 100% | 13 英寸宽屏与 App Store 截图规格 | passed | `docs/release/evidence/ui/ios-ipad13-*` |
| 首次页 | Pixel 7 / Android 15 API 35 模拟器 | 英文浅色 / 100% | 安装、启动、可访问控件树 | passed, partial path | `docs/release/evidence/ui/android-api35-en-light-welcome.png` |
| 今日至回看闭环 | Widget 360×640 | 中文 / 200% | 选择、140 emoji、滚动末端、封笺、可滚动回看弹层 | passed | `test/widget_test.dart` |

## 自动化结果

- 最终质量门禁：`docs/release/evidence/automation/20261010T155447+0800/QUALITY_GATE.md`
- 结果：format、analyze、23 项测试、Android debug APK、iOS unsigned archive 全部通过。
- 独立审核：三轮；最终 P0/P1 清零，功能 verdict `passed`。

## 未测试层

- 实体 iPhone/iPad/Android、最低 iOS 15/API 24、低内存/低存储、真实磁盘满、系统终止写入。
- VoiceOver/TalkBack 实际朗读、完整 Dynamic Type 阶梯、横屏、RTL（产品不承诺 RTL）。
- 真实前后台跨午夜、手动改时区/日期、DST 边界；自动化只使用可控时钟。
- 系统备份/恢复、真实分享目的地与完整剪贴板生命周期。
- 生产签名、TestFlight、App Store Connect、Play Console 与审核。
