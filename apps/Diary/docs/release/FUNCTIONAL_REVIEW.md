# 回声页 · EchoPage 功能审核报告

审核日期：2026-09-30
独立审核结论：`passed`（静态 + 自动化功能门禁）。未发现开放 P0/P1；本结论不等于完整 UI 矩阵、真机或 App Store 就绪。

## Findings

| 优先级 | 发现 | 用户影响 | 修复与证据 | 状态 |
| --- | --- | --- | --- | --- |
| P0 | 永久删除后旧正文可能留在应用内 backup 并在 current 损坏后复活 | 用户认为已删的私人内容重新出现 | `discardHistory` 同时净化 current/backup；两种 rename 故障注入验证失败时仍保留旧 current/backup | closed |
| P1 | 从 backup 恢复后的首次普通保存可能用损坏 current 覆盖 known-good backup | 下一次损坏时失去最后可读副本 | repository 记录恢复来源，恢复后不覆盖已知可读 backup；文件测试覆盖二次损坏 | closed |
| P1 | 普通编辑会重算回看日期或意外重开已关闭线索 | 用户时间线和状态被无意改变 | 编辑器保持原日期；已关闭线索需显式重新打开；Widget/控制器测试覆盖 | closed |
| P1 | “仅设备/无自动备份”与 iOS/Android 系统备份边界不符 | 隐私承诺可能误导 | App、PRD、政策草稿统一为“无开发者服务器；OS/用户系统备份、迁移、恢复可能含沙盒数据” | closed；真实 backup/restore 为 P2 缺口 |
| P2 | Echo 异步保存期间可由返回、遮罩或拖拽关闭 | 慢存储下草稿与结果状态不确定 | `PopScope` 阻止 pending save 时关闭；延迟仓库测试覆盖三种关闭方式，成功仅写一条 | closed |
| P2 | 可解析但语义矛盾的 JSON 不触发备份恢复 | 出现永不到期或重复线索 | Entry/Echo/Snapshot 加载校验开放/关闭状态、空白问题、重复 ID、locale/theme；语义损坏 current 回退 backup | closed |
| P2 | 最大 Dynamic Type 下 extended FAB 横向溢出 | 小屏用户无法识别主操作 | 高字号改为有 tooltip 的紧凑 FAB；3.2× Widget 路径与最终 iPhone SE AX XXXL 截图复核 | closed |

## 核心闭环

| 环节 | 结论 | 证据与边界 |
| --- | --- | --- |
| 输入/取消/失败 | passed | 正文必填；取消不写入；保存失败保持内存状态；32 个测试中的控制器/Widget 用例。 |
| 核心处理 | passed | `Entry → Future Question → Revisit → Echo → Close/Continue` 保持稳定 Entry ID 和历史 Echo。 |
| 用户确认/撤销 | passed | 编辑和 Echo 取消、软删除、恢复、永久删除/清空二次确认均有代码或测试；危险文案明确当前安装与系统备份边界。 |
| 状态重算 | passed | 到期只包含未删除、未关闭且有日期的开放线索；续期要求新日期。 |
| 持久化/恢复/删除 | passed | pending→current 原子替换、known-good backup、语法/语义损坏回退、双损坏锁写、删除净化应用内历史。未做进程杀死/低存储实测。 |
| 输出/分享 | passed with gap | 复制载荷由代码生成，平台失败会提示；未在实体设备验证真实剪贴板目的地。 |
| 中英文/深色/响应式 | passed for inspected states | 中英、深色、iPhone SE 3.2× Widget 路径；iPhone SE/iPad 运行截图。VoiceOver/TalkBack 未测。 |
| 弹层/路由关闭及重入 | passed | 空闲取消/遮罩/返回无写入；失败保留草稿；pending save 拦截返回/遮罩/拖拽。 |
| 离线/隐私边界 | passed for implementation | 主源码无网络/分析/广告依赖，Release manifest 无 Android INTERNET；系统备份行为由平台控制，未实测备份恢复。 |

## UI 与交互验收矩阵

| 页面/状态 | 设备与系统 | 语言/外观/字号 | 路径 | 结果与边界 | 证据 |
| --- | --- | --- | --- | --- | --- |
| 空首页 | iPhone SE 3rd / iOS 18.3 | 中文/浅色/标准 | 冷启动 | 通过；早期重复 CTA 已移除 | `evidence/runtime/iphone-se-empty-zh.png` |
| 创建→详情→Echo→关闭 | iPhone SE 3rd / iOS 18.3 | 中文 UI/浅色/标准；英文测试内容 | 实际点击与输入完成核心闭环 | 通过；模拟器中文输入法给英文插入视觉间距，不是数据逻辑缺陷 | `evidence/runtime/iphone-se-thread-closed-zh.png` |
| 设置/隐私 | iPhone SE 3rd / iOS 18.3 | 英文/深色/标准 | 切换语言、外观，读取隐私摘要 | 通过 | `evidence/runtime/iphone-se-settings-en-dark.png` |
| 首页最大字号 | iPhone SE 3rd / iOS 18.3 | 英文/深色/AX XXXL | 最终构建冷启动 | 紧凑 FAB 无横向溢出；内容需滚动，3.2× Widget 可进入详情/编辑/设置 | `evidence/runtime/iphone-se-home-en-dark-axxxl.png` |
| iPad 空首页 | iPad 10th / iOS 18.3 | 中文/浅色/标准 | 冷启动 | 内容宽度受限并居中，主操作可达 | `evidence/runtime/ipad-10-empty-zh.png` |

## 自动化结果

- 门禁报告：`docs/release/evidence/automation/20260930T105552+0800/QUALITY_GATE.md`
- `dart format --output=none --set-exit-if-changed lib test`：passed。
- `flutter analyze --no-pub`：passed，0 issues。
- `flutter test --no-pub --reporter expanded`：passed，32 tests。
- Android Debug APK 和 iOS unsigned Release Archive：passed。两者都不是商店发布证明。

## 未测试层

- 真实 iOS/Android 设备、iOS 15 runtime、VoiceOver/TalkBack、完整横屏矩阵。
- 进程终止/后台中断、低内存、低存储、大数据量和长周期使用。
- 真实 iOS/Android 系统 backup、迁移和 restore；真实剪贴板接收端。
- Android Emulator 运行态；签名 Release、上传、TestFlight、App Review。
