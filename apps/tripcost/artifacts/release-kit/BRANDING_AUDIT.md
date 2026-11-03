# RhinoSmart 品牌更新核对

核对日期：2026-11-03（Asia/Shanghai）。本报告仅覆盖本地项目与发布资料。

## 已更新

- iOS、Android、中英文应用名称、小组件、权限文案、隐私加载提示、导出标题、相册名和导出/备份文件名使用 RhinoSmart。
- App Icon 原始文件与用户提供的 2048 × 2048 PNG 字节完全一致；28 个平台、启动页及网站/商店派生资源均使用此原图。
- Website 首页与隐私页的双语文案、标题、元数据、页头/页尾、favicon、Apple touch icon、Open Graph 图片及产品示意中的图标均已同步。
- 根据用户确认应用已上架，Website 首屏与底部已同步为“已登陆 App Store / Available on the App Store”和“现已上架 / Available now”。
- App Store 12 张成图和 3 张联系表已重生成；Google Play 10 张手机成图和 2 张宣传图已重新合成并检查，联系表与替代文本已同步。品牌中性的 Play 手机成图可与旧版本字节一致。
- 当前产品文档、审核回复草稿、素材来源清单、事实快照以及仓库级 Android/iOS 发布显示名已同步。
- 本地 ASC 元数据已准备 `en-US`、`zh-Hans` 的名称 RhinoSmart，工作流的远程元数据开关仍默认关闭。

| 素材 | 数量 | 尺寸及模式 |
| --- | --- | --- |
| App Store iPhone 6.5 | 4 | 1242 × 2688，RGB |
| App Store iPhone Dynamic Island | 4 | 1206 × 2622，RGB |
| App Store iPad 13 | 4 | 2064 × 2752，RGB |
| Google Play 手机 | 10（每种覆盖文案语言各 5 张） | 1080 × 1920，RGB |
| Google Play feature graphic | 2（中英文） | 1024 × 500，RGB |
| Google Play listing icon | 1 | 512 × 512，RGBA，alpha 全为 255，小于 1024 KB |

## 图片来源与保留范围

网站/引导插画、审核用虚构回执、App Store 原始 Flutter 界面渲染及 Android 原始模拟器截图均逐组检查；这些图片没有旧名称或旧 App Icon，予以复用。App Store 成图保留实际 Flutter 界面，仅更新品牌叠层与背景；Dynamic Island 组由 6.5 英寸成图适配。本轮没有重新捕获原生模拟器或真机界面，也未将 Flutter widget 渲染声称为原生设备验证。

工程目录 `apps/tripcost`、Dart package/类名、Bundle ID、Android application ID、App Group、CloudKit、已有数据库/偏好键、生产域名 `tripcost.fit` 和签名环境标识继续保留，保证现有安装、数据和发布配置的兼容性。明确注明日期/提交的历史 QA 内容、审核资料原件归档及通用发布脚本测试夹具保留历史名称；它们不是当前对外品牌素材。

## 验证

- 发布资料自动检查：18 项通过，0 错误、0 警告，详见 `QA_REPORT.md`。
- 共享英文描述：1745/4000 字符；Apple 关键词：78/100 UTF-8 字节；Play 简短描述：67/80 字符。
- 本轮 Flutter 定向测试：15 项通过（导出、备份/恢复、隐私地址、汇率客户端）。上一轮本地化/启动/摘要等 23 项测试已通过。
- 发布配置现有测试：14 个测试、337 个断言通过；工作流 YAML、Android 目录 JSON 和 Ruby 语法检查通过。
- Website 已在本地浏览器核对首页、隐私页的中英文切换及新图标加载；可见正文无旧品牌。全量商店成图及联系表通过独立视觉复核。
- `git diff --check` 通过，原始 UI 素材未更改。

格式要求复核来源：[Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)、[Google Play preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)。

## 外部状态

本次品牌更新未部署网站、修改线上商店资料、上传安装包或提交审核。Git 交付状态以实际提交及远程核验记录为准。法律主体、最终公开联系方式、网站主机等既有未确认事项仍记录于 `OPEN_ITEMS.md`。

本地浏览器截图、图片审计联系表、测试日志及旧审核模板原件保存在 `.codex-artifacts/branding-completion-20261103/`，不作为新设备或上线证据。
