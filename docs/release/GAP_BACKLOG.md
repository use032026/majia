# PaceJar · 节奏罐差距与发布待办

生成日期：2026-09-29

## P0 — 发布阻断

| 来源发现 | 用户/政策影响 | 工作范围 | 验收标准 | 所需证据 | 负责人/外部输入 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| `com.example.paceJar` 是占位 Bundle ID | 无法与 ASC 生产记录匹配 | 确定唯一生产 ID，同步 Runner/Tests/ASC | archive 与 ASC ID 一致，无 placeholder | 签名 archive + ASC 记录 | 用户/Apple Developer 账号 | open |
| unsigned archive，无 embedded profile | 不可校验或上传 | 用 App Store distribution 身份签名并检查 entitlements | `codesign --verify` 通过，profile/team/expiry 正确 | 签名 archive/IPA 及校验日志 | 用户/Apple Developer 账号 | open |
| 缺公开 Privacy URL / Support URL | 5.1 与 ASC 元数据阻断 | 定稿隐私文案、负责主体与支持页，用 HTTPS 发布 | 无登录可访问，内容与最终 SDK/数据流一致 | URL 现场打开 + ASC 字段 | 用户/法务/网站 | open |
| 名称和权利未清查 | 2.3/4.1/5.2 风险 | 对 PaceJar/中文名/图标做名称可用性与商标检查 | 生产名称已选定且权利记录归档 | 查询记录 + ASC 名称 | 用户/法务 | open |

## P1 — candidate 门禁

| 来源发现 | 用户价值/差异化 | 工作范围 | 验收标准 | 所需证据 | 成本 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 缺真机与 VoiceOver 验收 | 直接影响可用性与 2.1 稳定性 | iPhone/iPad 真机，最低系统可行设备，VoiceOver/Dynamic Type | 核心闭环、删除、剪贴板、后台恢复有设备日志/截图 | 真机证据 | M | open |
| ASC 元数据/隐私问卷未建 | 影响 2.3/5.1 准确性 | 中英描述、关键词、审核备注、年龄分级、App Privacy | 与签名最终构建、权限、SDK 一致 | ASC 字段导出/截图 | M | open |
| 中国大陆发布条件未确认 | 可能阻断中国大陆上架 | 核对当前 ICP/备案与主体匹配要求 | ASC 当前界面和官方要求证据闭环 | 官方记录 | M/L | open |
| 无 commit 级身份 | 最终截图/归档/源码不能强绑定 | 将工程进入受控 Git 历史，从指定 SHA 重建 | 报告、archive、截图都记录同一 SHA | Git SHA + known state | S | open |

## P2 — 提交质量

| 来源发现 | 改善目标 | 验收标准 | 证据 | 状态 |
| --- | --- | --- | --- | --- |
| Xcode Privacy Report 未生成 | 复核 manifest 合并与 required-reason APIs | 用最终签名构建生成并人工核对 | 归档报告 + SDK manifest | open |
| 截图只有有限页面/本地化 | 提高 2.3 元数据准确性 | 从最终签名 SHA 生成中英 iPhone/iPad 完整组 | 尺寸/无 alpha/页面来源清单 | open |
| Android 只有 debug build | 如需 Play 交付，避免 debug signing | 生产 applicationId、release signing 与 AAB 单独门禁 | 本次不在 App Store 提交范围 | open |

## 本轮已关闭

| 来源发现 | 修复 | 证据 | 状态 |
| --- | --- | --- | --- |
| SVG 曲线路径未进入 AppIcon raster | 改用导出器兼容的基本几何，并人工查看 1024 与 180px 图标 | 1024 PNG RGB 无 alpha；最终机械预检 app_icon passed | closed |
| 默认 Flutter LaunchImage 与白色启动页 | 生成品牌 LaunchImage 1x/2x/3x，并使用暖灰品牌背景 | 最终 iOS 构建无默认启动图警告 | closed |
| Archive 未显式列出支持语言 | 添加 `CFBundleLocalizations` 的 `en` 与 `zh-Hans` | 最终 Archive Info.plist 可解析两项 | closed |

## 下一迭代切片

- 选择：“生产身份 + 签名候选包”。
- 原因：产品与本地质量门已过，当前 P0 集中在生产身份、法务 URL 和签名。
- 不包含：不加账号、广告、订阅、社区、银行连接或 AI；不自动上传。
- 完成条件：唯一 Bundle ID、已发布的隐私/支持 URL、签名 archive 与隐私报告通过本地预检，真机/VoiceOver 核心闭环有证据；仍不上传，除非用户另行授权。
