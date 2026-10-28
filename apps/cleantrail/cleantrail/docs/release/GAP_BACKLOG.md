# 差距与发布待办

## P0 — 发布前必须完成

1. iOS/Android 包标识已于 2026-10-28 按用户确认改为 `com.astfx.lite`；仍需核验商店注册、Apple Developer Team 与 App Store 分发配置。
2. 运营主体（独立开发者）、邮箱（evwascr0317@icloud.com）、政策生效日（2026-10-28）及正式域名 `https://astfx1.com` 已确认；中英文政策地址为 `/privacy.html?lang=zh` 与 `/privacy.html?lang=en`，应用默认使用 `https://astfx1.com/privacy.html` 并按当前语言设置 `lang`。仍需核验公共页面可达性、支持页、托管方及日志处理，并填写 ASC 对应 URL。
3. 在 App Store Connect 创建版本元数据，完成隐私问卷、年龄评级、类别、描述、关键词、版权和 Review Notes。
4. 用最终签名构建拍摄无 alpha 的 6.9/6.5-inch iPhone 与 13-inch iPad 截图集。

## P1 — candidate 门禁

1. 在真实 iPhone/iPad 与最低 iOS 13 测试 Files provider、取消/失败、5 MB 与组合规模边界、重启恢复、清除、分享双附件和临时文件清理。
2. 覆盖深色冷启动、横竖屏、2× Dynamic Type、VoiceOver、后台/前台和低存储失败。
3. 从最终签名 archive 导出 Privacy Report，核对主 App/Flutter/插件 manifests、required-reason API 和 SDK 签名。
4. 记录可复现 branch/SHA 或源码快照；当前父目录不是 Git 仓库，无法提供提交级追溯。

## P2 — 提交质量

1. 检索 CleanTrail/清迹商标、App Store 名称与域名；形成资产与依赖权利台账。
2. 用目标用户 CSV 做可用性测试，验证 500 问题上限、日期地域歧义与质量分解释是否清楚。
3. 明确免费策略；任何 IAP、订阅、云同步、分析或崩溃上传都会触发支付与隐私重新审核。

本轮明确不执行上传、TestFlight、ASC 提交或审核。
