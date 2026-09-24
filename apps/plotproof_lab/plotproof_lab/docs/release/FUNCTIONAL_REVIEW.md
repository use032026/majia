# PlotProof Lab（图证实验室）功能审核报告

审核日期：2026-09-09

独立审核结论：`passed`。代码与自动化审核范围内无开放 P0/P1；该结论不覆盖实体设备、系统读屏、签名分发或 App Store。

## Findings

| 优先级 | 需求/流程 | 第一轮发现 | 修复与验收证据 | 状态 |
| --- | --- | --- | --- | --- |
| P1 | FR-04 保存失败 | 保存异常会挡住解析 | 解析与对照先展示，结果标记未保存并可重试；失败不写入内存完成态；Widget 与控制器测试覆盖 | closed |
| P1 | FR-02/03 公平对照 | `fairParameter` 未形成可见的初始/公平双快照 | 八关均展示两张同数据快照；公平关使用中性“另一种公平表达” | closed |
| P1 | FR-03 坐标与因果语义 | 轴范围/单位不完整；因果关通过删点暗示“第三变量” | 坐标显式标出范围和单位；因果关保持数据点不变并单独补充气温语境 | closed |
| P1 | FR-05 暗色对比 | 核心容器文字仅约 1.43:1 | 全部语义容器显式使用配套前景色；浅色/暗色对比度单测均不低于 4.5:1 | closed |
| P1 | FR-03 放大率可信度 | 计算使用数据高值而绘图使用轴上界，显示 24.8×/9.8× 与图形不一致 | 公式强制接收与 painter 相同的 `axisMaximum`；精确断言 95–100 为 20.0×、70–82 为 6.8×、完整范围均为 1.0× | closed |
| P2 | FR-04 损坏数据恢复 | 无明确恢复入口；首次清除失败后入口可能消失 | 顶部错误卡提供二次确认重置；`clear` 错误保留准确文案和可重复入口；失败一次再成功测试覆盖 | closed |
| P2 | FR-05 大字号 | 旧 Chip 在英文 2.5× 字号下截断 | 改为可换行状态卡；390×844、2.5× Widget 无 overflow，最终模拟器截图可见完整文本 | closed |

## 核心闭环

| 环节 | 结论 | 证据与边界 |
| --- | --- | --- |
| 发现与输入 | passed | 学习页可见四类八关；必须先提交判断，控件才解锁 |
| 核心处理 | passed | 坐标、相关、样本和风险计算为确定性纯 Dart；数值单测覆盖 |
| 反馈与纠错 | passed | 调参后显示同数据对照、结论边界、检查清单和合成数据声明 |
| 失败与恢复 | passed | 保存失败不伪造完成；可重试；损坏状态可确认清除并处理再次失败 |
| 持久化与复练 | passed | SharedPreferences 保存尝试与语言；最近错误进入队列，正确重试移除 |
| 删除 | passed | 设置页二次确认后删除本地作答；无账号或云端删除语义 |
| 中英文/主题/响应式 | passed within tested matrix | 中英文切换、浅/深色、手机/平板首页、2.5× 大字均有自动化或模拟器证据 |
| 离线/隐私边界 | superseded; current HEAD requires revalidation | 原证据证明当时构建无业务网络；当前源码已增加匿名 HTTPS 题目包读取，但仍无账号、广告、分析或学习记录上传。最终 Archive 与网络行为尚未重验。 |

## 独立复审

第一轮结果为 `needs_revision`（4 个 P1、2 个 P2）。完成两轮修订后，独立复审确认所有 P0/P1 关闭，且未发现新的代码级 P2/P3，最终判定 `passed`。

## 自动化结果

- 最终门禁：[QUALITY_GATE.md](evidence/automation/20260909T124324+0800/QUALITY_GATE.md) / [quality-gate.json](evidence/automation/20260909T124324+0800/quality-gate.json)
- `dart format --output=none --set-exit-if-changed lib test`：passed
- `flutter analyze --no-pub`：passed
- `flutter test --no-pub --reporter expanded`：25 项 passed
- `flutter build apk --debug --no-pub`：passed
- `flutter build ipa --release --no-codesign --no-pub`：passed

## 未测试层

- 未跑实体 iPhone/Android、最低 iOS 15 设备、后台终止恢复、低内存或低存储。
- 未跑 VoiceOver/TalkBack、最大 Dynamic Type、横屏和每关 iPad 全流程。
- 最终模拟器证据覆盖 iPhone 深色英文大字首页与 iPad 浅色中文首页；完整作答链由 Widget 自动化覆盖，不能替代最终代码的逐页视觉验收。
- 未做签名 Release、安装包真机安装、TestFlight、App Store Connect 或 App Review。
