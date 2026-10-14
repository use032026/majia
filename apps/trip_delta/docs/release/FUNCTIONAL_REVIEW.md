# 旅程差额 / Trip Delta 功能审核

> 历史审核说明：本报告的功能验收范围截至 2026-09-21。2026-10-14 新增估算核对门禁、复盘支出预填、账本筛选与本地备份；当前状态见 [差距与发布待办](GAP_BACKLOG.md)。下文“无导入/备份功能”属于当时结论。

审核日期：2026-09-18。独立 Functional Reviewer 终版结论：**`passed`（Flutter MVP 功能及已检 UI）**，无开放 P0/P1。自动化、模拟器、构建和未测试层分别记录。

> 2026-09-21 [产品体验复核](../product/PRODUCT_REASSESSMENT_2026-09-21.md)结论为 `needs_revision`：流程能走通不代表重复记账便捷、旅行场景足够具体或跨币种“实付”语义准确。本报告的功能结论保留其原测试范围。

> **2026-09-21 改版复验：** 上述产品问题已按 [改版结果](../product/PRODUCT_REVISION_RESULT_2026-09-21.md)处理。`flutter analyze` 为 0 问题，13 项测试通过；iPhone 16e / iOS 18.3 实操通过首页快捷记账、当地币种/汇率复用和预算即时更新；Android Debug APK、iOS Simulator App 与未签名 iOS Archive 构建通过。实体设备、iOS 15 与上架签名仍未验证。

## 发现与关闭

| 优先级 | 流程 | 第一轮发现与影响 | 修复及关闭证据 | 状态 |
| --- | --- | --- | --- | --- |
| P1 | 零支出对照 | 未录入时容易将计划与 0 的差额误称为节余 | 详情明确尚无支出，结束操作禁用；Widget 测试 `empty trip cannot be completed or claim a saving` | closed |
| P2 | 支出与复盘 | 完成后备注不易看到；长内容挤压主操作 | 完成详情保留备注，active 主动作前置；iPad 30 笔压力详情已观察中段 | closed（已检路径） |
| P2 | 金额 | JPY 上限与半分舍入存在误差风险 | 上限按币种位数限制；换算改用整数比率与 BigInt 半进位；domain 测试覆盖 0.5、0.05、7.1 | closed |
| P2 | 失败恢复与文案 | 异步保存时返回可能丢表单；支出空标题提示不准 | 写入中禁止返回并保留表单重试；文案纠正；Widget 测试覆盖失败/重试 | closed |

## 核心闭环

| 环节 | 结论 | 证据与边界 |
| --- | --- | --- |
| 输入、取消、失败 | passed | 计划/支出金额和汇率校验；Widget 覆盖取消、失败后保留与重试；真机键盘矩阵未测 |
| 固定基线与计算 | passed | 草稿预算可编辑，开始后锁定；整数最小货币单位计算分类/总差额；iPhone 16 现场显示 CNY 300 对 CNY 350、超 CNY 50 |
| 确认与撤销 | passed | 旅程/支出删除二次确认；复盘可重开纠错；Widget 覆盖删除取消与确认、完成重开 |
| 状态重算 | passed | 支出编辑/删除重算分类及总额；手填汇率快照持久；Widget/domain 测试 |
| 持久化与恢复 | passed（本地） | 先保存后更新内存；临时文件替换；坏文件拒载且不覆盖；文件测试及 iPhone 16 进程重启观察。无迁移/备份验证 |
| 输出 | passed | 主动复制文本总结到系统剪贴板；Widget 与模拟器主路径。外部接收 App 未测 |
| 中英、深色、响应式 | passed（已检矩阵） | iPhone 16 中英、深色/accessibility-medium；SE 和 iPad 首页压力截图、平板详情中段；完整字号矩阵未测 |
| 长内容与滚动 | passed（已检区域） | SE 长标题首页可读且新建按钮可达；iPad 30 笔详情分类与多笔备注可读，滚动至中段；最底部未截图 |
| 离线/隐私 | passed（源码及已检路径） | `lib` 无网络客户端或账号/分析 SDK；本机私有文件；剪贴板主动触发。未抓包/验证系统备份 |

## UI 验收矩阵

| 页面/状态 | 设备 | 语言/外观/字号 | 结果与限制 | 证据 |
| --- | --- | --- | --- | --- |
| 空首页、完成首页 | iPhone 16 / iOS 18.3 | 中文/英文、浅色 | 实际表单输入后完成，按钮和金额可读 | `evidence/iphone16-empty-zh.png`、`evidence/iphone16-completed-en.png` |
| 完成详情尾部与备注 | iPhone 16 / iOS 18.3 | 英文、浅色 | 现场滚动至备注/删除操作可读；未截图 | 模拟器现场观察 |
| 深色和大字详情 | iPhone 16 / iOS 18.3 | 英文、深色、accessibility-medium | 现场观察主动作与列表尾部可达；不代表完整 Dynamic Type | 模拟器现场观察 |
| 长标题首页 | iPhone SE 3 / iOS 18.3 | 英文、浅色、默认字号 | 标题换行、预算/实付完整、新建按钮可见；详情未检 | `evidence/iphone-se-stress-home-en.png` |
| 30 笔长标题/备注 | iPad Pro 11 M4 / iOS 18.3 | 英文、浅色、默认字号 | 首页与详情顶部/中段可读；最底部未截图 | `evidence/ipad11-stress-home-en.png`、`evidence/ipad11-stress-detail-en.png` |

## 自动化与未测试层

终版 `evidence/automation/20260918T115136+0800/QUALITY_GATE.md`：格式 0 变更、分析 0 问题、**10 项测试通过**，Android Debug APK 与未签名 iOS Archive 构建通过。11:32 的早期格式失败已修正，不计作终版。

模拟器截图早于最终系统备份文案修正；最终文案已通过静态、测试和 Archive 构建，尚无更新后的运行态截图。

SE 详情/大字、iPad 中文/深色、30 笔详情最底部、真实键盘遮挡与弹层关闭/重入全矩阵、VoiceOver/TalkBack、完整 Dynamic Type、横屏、实体设备、iOS 15、Android 运行、低存储/后台中断均未验证。无导入/备份功能，卸载可能丢本地记录。签名分发、TestFlight 和 App Review 未做。
