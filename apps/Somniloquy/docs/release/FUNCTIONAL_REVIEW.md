# Somniloquy 功能审核报告

审核日期：2026-10-08
独立审核结论：`passed`（静态、单元/Widget 自动化与列出的模拟器目视层）。未发现开放 P0/P1；不代表真机后台长录音、签名发布或 App Store 通过。

## Findings

| 优先级 | 发现 | 修复与验收 | 状态 |
| --- | --- | --- | --- |
| P1 | 停止后的待核对草稿无法跨重启恢复，且可能进入正式归档 | 初始化恢复最新未核对草稿；正式归档只读取 `reviewedSessions`；Controller/Widget 测试覆盖保留、恢复与删除 | closed |
| P1 | 晨间核对缺少不误写的退出路径 | 系统返回与“稍后核对”均提供继续、保留草稿、永久删除；保留时未保存编辑不写入 | closed |
| P1 | `pending` 候选可能被保存为“已核对” | 任一候选未标注时阻断保存并显示双语提示；详情同时排除 pending | closed |
| P1 | 横屏/大字下停止按钮可能不可达 | 录音页改为可滚动最小高度布局；568×320、1.3x 字号测试确认停止按钮可见，系统返回弹出同一停止确认 | closed |
| P1 | 删除顺序可能在文件删除失败后留下 UI 无法再清理的孤儿音频 | 恢复为先删音频、成功后再移除索引；故障注入测试证明失败时索引和音频均保留，重试后均清除 | closed |
| P2 | 部分启动后插件抛错可能留下未知录音状态 | 外层失败路径统一取消录音并清理已分配音频；故障测试覆盖 | closed |
| P2 | 中文删除确认和录音语义存在硬编码英文 | 删除取消使用系统本地化；录音状态语义进入中英字典 | closed |
| P2 | PRD 的本地背景统计未实现 | 仅对已核对卡片的本地背景标签聚合计数；删除后由当前会话重算 | closed |
| P2 | 保存失败测试没有完成真实重试 | 测试解除故障后再次保存，验证 reviewed 状态、marker 清除和内容保留 | closed |

## 核心闭环

| 环节 | 结论 | 证据与边界 |
| --- | --- | --- |
| 输入/同意/权限拒绝 | passed | Widget 覆盖取消重开、同意后请求权限、拒绝不创建 marker/session；模拟器目视中英文说明和系统权限路径 |
| 录音与候选处理 | passed | `record` AAC、明显录音状态、12 小时上限；检测器测试覆盖校准、阈值、冷却期、24 条上限；真实整夜后台仍待真机 |
| 人工核对/撤销 | passed | 候选必须逐条标注或忽略；退出可继续、保留或永久删除；零候选可保存笔记 |
| 持久化/恢复/删除 | passed | 真实临时目录覆盖写入、重载、单晚删除、中断清理和删除失败重试；系统设备备份副本不由应用删除 |
| 历史与背景回看 | passed | 正式归档只显示已核对卡片；背景统计只来源于已核对本地标签 |
| 中英文/深色/响应式 | passed within evidence | iPhone SE 中文明暗、英文设置、iPad Pro 中文 NavigationRail 已目视；Widget 覆盖 320pt/1.3x 与 834pt 平板 |
| 离线/隐私边界 | passed statically | 依赖中无网络、账号、广告或分析 SDK；文案说明不主动上传、设备备份可能包含本地数据、非医疗定位 |

## UI 与交互验收矩阵

| 页面/状态 | 设备/语言/外观 | 路径 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| 今晚入口 | iPhone SE 3 / iOS 18.3 / 中文 / 明暗 | 空状态、主操作首屏可见 | passed | `docs/release/evidence/runtime/iphone-se-zh-tonight.png`、`iphone-se-zh-dark-tonight.png` |
| 录音说明与正在录音 | iPhone SE 3 / 中文 | 同意、权限、录音指示、停止 | passed | `docs/release/evidence/runtime/iphone-se-zh-recording.png`；系统麦克风真实模拟器流，不代表真机后台 |
| 晨间核对与草稿 | iPhone SE 3 / 中文 | 停止、稍后核对、保留、恢复、保存 | passed | `docs/release/evidence/runtime/iphone-se-zh-review.png` + Widget 测试 |
| 设置与隐私 | iPhone SE 3 / 英文 | 语言切换、隐私/医疗边界、危险操作 | passed | `docs/release/evidence/runtime/iphone-se-en-settings.png` |
| 平板布局 | iPad Pro 11-inch M4 / iOS 18.3 / 中文 | NavigationRail 与主操作 | passed | `docs/release/evidence/runtime/ipad-pro-11-zh-tonight.png` |
| 横屏大字录音 | 568×320 / 英文 / 1.3x | 停止可达、系统返回确认、继续录音 | passed by Widget | `test/widget_flow_test.dart`；未做实体设备目视 |

## 自动化结果

`docs/release/evidence/automation/20261008T162136+0800/QUALITY_GATE.md`：

- format-check：passed
- flutter analyze：passed，无问题
- flutter test：passed，16 项
- Android debug APK：passed
- iOS release Archive（无签名）：passed

## 未测试层

- iOS 15 实体设备、锁屏/后台整夜、来电/闹钟/音频中断、低存储、电池与温升、12 小时边界。
- VoiceOver/TalkBack、完整 Dynamic Type 档位和实体设备横屏。
- 最终文件保护等级、系统备份恢复、卸载后行为。
- Distribution 签名、安装、上传、处理、TestFlight 与 App Review。
