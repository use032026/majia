# ReaderEdit 功能审核报告

审核日期：2026-09-30

结论：`passed_with_boundaries`。用户指出的两个核心缺口已关闭：产品现在具备本地小说/章节创建与编辑能力，并能从系统文件选择器导入长文本，在章节阅读页原位切换编辑。静态分析、29 项测试、Android debug、iOS unsigned archive 和 iPhone 17e 模拟器创建/编辑/重启持久化均通过；真实外部文件选取后的端到端导入、实体设备和极限长文性能仍是明确边界。

## 本轮发现与关闭记录

| 优先级 | 发现 | 修复与验收证据 | 状态 |
| --- | --- | --- | --- |
| P1 | 只有临时修订会话，无法创建和维护整本小说 | 新增 `Novel`/`NovelChapter`、书架、小说详情、新建/删除章节；schema v2 与旧 v1 兼容 | closed |
| P1 | 长文本只能复制/粘贴，不能导入 | 新增系统文件选择器、TXT/MD/Markdown、UTF-8/UTF-16 解码、8 MiB/200 万字符/1000 章保护、常见章节标题切分 | closed_with_runtime_boundary |
| P1 | 导入或创建后不能在阅读时直接修改 | 章节阅读页右上角切换编辑；保存后回到阅读；未保存返回确认；重启后内容仍在 | closed |
| P2 | 小说和旧修订若分开存储，可能破坏原子恢复语义 | 工作区 JSON 升级为 schema v2，同一原子快照保存小说和修订；v1 读取与备份恢复测试通过 | closed |
| P2 | 文件选择器引入新的平台/隐私依赖 | 固定 `file_selector 1.1.0`；Android 显式 API 24；iOS archive 中插件 privacy manifest 可解析 | closed_with_release_boundary |

`closed_with_runtime_boundary` 表示业务解析、Store 和 Widget 路径已自动化，iOS 模拟器已确认系统选择器可以打开，但本轮没有在 Files 中选择一份真实外部文稿并完成复制入库；因此不能把模拟输入等同于真实文件提供方全链路证明。

## 核心闭环复核

| 环节 | 结论 | 证据与边界 |
| --- | --- | --- |
| 创建小说 | passed | 模拟器创建 `Fog Harbor`，进入空章节列表；Widget 覆盖表单和路由 |
| 创建章节 | passed | 模拟器创建 `Chapter One` 后直接进入编辑；Store/Widget 覆盖 |
| 阅读时编辑 | passed | 模拟器输入两段正文、保存回阅读，页面显示 74 字符；重启应用后书架仍显示 1 章/74 字符 |
| 导入入口 | passed_with_boundary | iOS 系统 Files 选择器可打开/取消；实际文件内容通过注入式 Widget 测试进入两章，非真实提供方选择 |
| 编码与切章 | passed | UTF-8、UTF-16LE、空文件、中文/Markdown 标题、无标题单章均有单元测试；误把“第一章正文”识别为标题的初版缺陷已修复 |
| 导入事务 | passed | 先完整解码/规划，后一次持久化；失败不产生半本小说；Store 保存失败保持旧可见状态 |
| 旧数据迁移 | passed | 真实 schema v1 文件读入后小说为空，下一次写入 schema v2 时保留旧修订并新增小说 |
| 删除/恢复 | passed | 小说、章节和全清空使用不保留旧快照的提交；原有会话删除恢复测试继续通过 |
| 章节到读者修订 | passed_with_limit | 合适章节可预填现有创建页；超出 30,000 字符或 2–80 段时提示使用直接编辑/先拆章 |
| 中英文/深色/小屏 | passed_with_boundary | 现有 320×720、1.6× 英文深色测试通过；新增书架核心文案均双语；新增页面尚未完成全设备截图矩阵 |

## 自动化与构建

- 最终质量门禁：`docs/release/evidence/automation/20260930T120051+0800/QUALITY_GATE.md`，`passed`。
- 最终结果：format-check、`flutter analyze`、29 tests、Android debug APK、iOS release no-codesign archive 全部通过。
- 关键新增测试：小说导入规划、UTF-16 解码、schema v1→v2、Store 创建/导入/编辑/失败不提交、Widget 创建小说/章节/阅读编辑/两章导入。

## 运行态检查

设备：iPhone 17e 模拟器，iOS 26.5，中文浅色。

1. 首页可见“我的小说”、导入、创建小说及独立的“读者视角修订”分区。
2. 创建小说与章节后直接进入章节编辑；保存后完整正文在阅读视图可选择，编辑入口可达。
3. 返回书架显示小说、章节数和字符数；终止并重新启动 App 后数据仍存在。
4. 导入按钮成功展示系统 Files 选择器，取消后返回原页面且数据不变。
5. 章节阅读截图：`docs/release/evidence/runtime/iphone17e-chapter-read-zh-light.png`。

## 未测试层与后续风险

- 未在实体设备或实际 Files/iCloud/第三方文件提供方选择文稿；未验证安全作用域、超大文件读时峰值和不同提供方取消/错误行为。
- 未实测 GBK/GB18030；当前只接受严格 UTF-8 与带 BOM UTF-16。
- 未验证 200 万字符在低内存设备上的编辑流畅度；这是输入保护上限，不是性能承诺。
- 未实现章节重排、合并、拆分、小说/章节重命名入口或导出整本小说；当前可编辑章节标题，但需进入章节编辑页。
- 未做 VoiceOver/TalkBack、最低 iOS 15、Android 7.0 实机、低存储、进程中断、真实剪贴板跨 App 粘贴。
- 未签名、未上传、未经过 TestFlight/ASC 处理或 App Review。
