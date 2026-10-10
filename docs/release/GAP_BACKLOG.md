# Almanac 差距与发布待办

生成日期：2026-10-10

代码停止条件已满足；以下均属于发布候选或外部资料，不授权上传。

## P0 — 发布阻断

| 来源发现 | 用户/政策影响 | 工作范围 | 验收标准 | 所需证据 | 外部输入 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| `com.example.almanac` 占位身份 | Apple/Google 不能作为真实新应用身份提交 | 确定唯一 iOS Bundle ID 与 Android applicationId | 源码、archive、AAB、商店记录一致 | 签名包 + 机械预检 | 开发者账号与最终 ID | open |
| iOS archive 未签名 | 不能安装到生产设备或上传 ASC | 配置真实 Team、证书与 profile 后重建 | `codesign --verify` 通过且 profile 匹配 | Signed archive + Organizer/ASC 前置检查 | Apple Developer 权限 | open |
| Android release 使用 Debug 证书 | 不能作为生产 Play candidate | 配置受保护的 upload key/Play App Signing | AAB 证书与 Play 记录匹配 | `apksigner`/Play Console | Android 发布密钥 | open |
| 无公开隐私/支持 URL | Apple 与 Google 都要求有效公开隐私信息；Apple 还需要支持联系路径 | 审核并发布政策与支持页 | HTTPS、非占位、可访问、与最终数据流一致 | URL 快照 + 商店字段 | 法定主体、联系信息、域名 | open |
| Google Play 素材不完整 | 当前仅一张 Android 首屏，不能完成 Play listing | 补至少第二张 Android 核心流程截图、512×512 store icon、1024×500 feature graphic、short/full description | 真实 Android 体验、无占位、与最终品牌/包一致 | Play listing 素材检查 | 最终品牌与生产包 | open |

## P1 — candidate 门禁

| 来源发现 | 用户价值/差异化 | 工作范围 | 验收标准 | 所需证据 | 成本 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| Apple 4.3(b) fortune telling 饱和类别高风险 | 若被视为运势/算命，即使功能完整也可能拒绝 | 元数据、截图、关键词与 Review Notes 坚持“文化反思，不预测”；不得承诺吉凶/择日/准确黄历 | 审核材料与应用行为一致，清楚展示选择→回看→笺册耐久闭环 | 最终元数据评审 | M | open |
| 4.2 最低功能仍属审核裁量 | 每日内容过轻可能被视为低效用 | 保留生成、选择、封笺、回看、历史、导出；不退化为单页随机句 | 真实截图与审核路径覆盖完整闭环 | 最终签名构建与 Review Notes | S | open |
| 名称/商标/内容权利未核验 | 可能引发 4.1/5.2 或商店记录冲突 | 检索 Almanac 名称与图标相似性；保存原创内容清单 | 无冲突或取得权利 | 法务/商标检索记录 | M | open |
| 中国大陆发行状态未确认 | 可能涉及 ICP、出版/宗教/民俗分类与主体资质 | 在确定首发地区和主体后做地区专项判断 | 书面地区策略与所需资质清单 | 法务/合规意见 | M/L | open |
| 隐私标签尚未由最终签名包审计 | “不收集”不能只由源码推断 | 审核最终 SDK、Privacy Report、Data Safety 与备份行为 | Apple/Google 回答与包/政策一致 | Archive privacy report + Play SDK/表单 | M | open |
| 商店控制台事实未建立 | 无类目、评级、出口合规、隐私问卷、Data Safety、最终 Review Notes 记录 | 在不上传的前提下完成双店字段草稿与账号条件清单 | 所有必填字段有来源且与最终包一致 | ASC/Play 草稿或导出 | 账号角色与外部事实 | M | open |
| Google 个人账号测试门槛未知 | 部分新个人开发者账号上生产前需 closed test | 确认账号类型/创建日期与适用门槛 | 若适用，完成 Play 要求的测试人数/天数 | Play Console 外部状态 | Google 开发者账号 | M | open |

## P2 — 提交质量

| 来源发现 | 改善目标 | 验收标准 | 证据 | 状态 |
| --- | --- | --- | --- | --- |
| 无实体设备/最低系统证据 | 降低兼容性与键盘/安全区风险 | iOS 15 实体或模拟器、API 24 设备完成核心闭环 | 设备日志 + 截图 | open |
| 辅助功能矩阵不完整 | 验证真实读屏、最大字号、横屏 | VoiceOver/TalkBack、完整 Dynamic Type、横屏无阻断 | 录屏/检查表 | open |
| 16 KB 仅包对齐检查 | 验证运行而非只验证格式 | 16 KB page-size emulator 启动并走核心路径 | `getconf PAGE_SIZE=16384` + 运行日志 | open |
| 无 Git 版本身份 | 提高构建与报告可追溯性 | 由项目所有者决定仓库归属并提交 | commit SHA 与 clean/known dirty 状态 | open |
| 截图来自 debug 模拟器 | 建立最终构建一致性 | 用最终签名 candidate 重新截取并重跑预检 | final build/screenshots hashes | open |

## 下一迭代切片

- 选择：发布身份与公开政策闭环。
- 原因：当前代码与功能门禁已通过，真正阻断是身份、签名、URL 和商店事实，而不是继续扩功能。
- 不包含：账号、广告、订阅、社交、AI、真实农历/择日算法，也不包含上传。
- 完成条件：真实 Bundle/Application ID、双端正式签名、公开隐私/支持 URL、最终隐私表单草稿、名称/首发地区决定齐备，机械预检不再因这些项目阻断。
