# 证据登记

2026-10-28 当前配置说明：源码 iOS/Android 标识已统一为 `com.astfx.lite`；本次没有构建或运行新标识。以下为历史构建证据，其中占位 Bundle ID 的描述仅指当时的 archive。运营主体、邮箱、生效日与正式域名 `https://astfx1.com` 已获用户确认；中英文政策地址分别为 `https://astfx1.com/privacy.html?lang=zh` 与 `https://astfx1.com/privacy.html?lang=en`。应用默认使用 `https://astfx1.com/privacy.html` 并按当前语言设置 `lang`，构建时仍可覆盖 `PRIVACY_POLICY_URL`；这些配置事实本身不证明公共可达性。当前配置见 `../../release-kit.yml`。

记录时间：2026-09-08，Asia/Shanghai。当前目录及其父目录不是 Git repository，因此没有 branch/SHA；以下用路径、时间与 SHA-256 限定证据。

| 层级 | 证据 | 结果 | 证明上限 |
| --- | --- | --- | --- |
| 静态 | `flutter analyze --no-pub` | 通过，0 issues | 不证明运行态或平台集成 |
| 自动化 | `flutter test --no-pub --reporter expanded` | 32/32 通过 | 不证明真实 Files/分享/真机性能 |
| iPhone 模拟器 | iPhone 17 Pro / iOS 26.5 最终 debug 启动 | 通过；恢复此前保存项目，中文队列、质量分、隐私入口可见 | debug 模拟器；截图含 alpha，不是 ASC 素材 |
| iPad 模拟器 | iPad Air 11-inch (M4) / iOS 26.5 最终 debug 启动 | 通过；响应式队列、图表和前 5/总行数可见 | debug 模拟器；截图含 alpha且非 13-inch ASC 尺寸 |
| iPad 分享 | iOS 26.5 系统 popover，两个文稿 | 先前运行证据通过；未选择目的地 | 证明平台 share sheet/popover 形态，不证明最终构建外部传输或清理 |
| Android 构建 | `flutter build apk --debug` | 通过 | debug APK，不是 Play 发布候选 |
| iOS 构建 | `flutter build ipa --release --no-codesign` | archive 通过；未生成 IPA | Release arm64，但无签名、profile、Team，不能上传或真机分发 |
| iOS 设置 | archive Info.plist | Xcode 26.5 / iphoneos26.5 / iOS 13.0 / 1.0.0 (1) / en + zh-Hans | Bundle ID 仍为占位符 |
| 隐私清单 | archive 内主 App、Flutter、file selector、path provider、share plus 的 `PrivacyInfo.xcprivacy` | 全部 `plutil -lint` 通过 | 未生成最终签名 archive 的 Xcode Privacy Report |
| 依赖边界 | archive Frameworks 清单 | 仅 App、Flutter、file_selector_ios、path_provider_foundation、share_plus | 静态包清单，不是抓包 |
| 图标 | 1024×1024 AppIcon | PNG，`hasAlpha: no` | 未完成名称/图标商标权利检索 |

## 最终工件

| 工件 | 时间/摘要 |
| --- | --- |
| `build/app/outputs/flutter-apk/app-debug.apk` | SHA-256 `a36d129c91a9d7abe1d301978c168eab57c20201d499fe78fe9b7ebd1c8bf0ab` |
| `build/ios/archive/Runner.xcarchive` | 2026-09-08 15:22:06 +0800；159.5 MB；无签名 |
| archive `App.framework/App` | SHA-256 `546951d6e86c34faa76316b44fedd856e63de33b65220db3a70c2d0d28e33628` |
| iPhone 最终截图 | SHA-256 `b82415c4afebe25717e99b1f36b583ef7c2508430d0eb133561705793b82fce8` |
| iPad 最终截图 | SHA-256 `9dcb354c72a96f6989f7eeaa74a25faf3cfe7d5833391c04a68e243b63a33a07` |

归档生成晚于 `lib/`、`ios/Runner/` 与 `android/app/` 中全部文件；之后只新增/更新报告与模拟器截图，没有修改产品代码。

## 明确缺失

生产 Bundle ID、Apple Team/profile、分发签名、IPA、真机、最低 iOS、Privacy Report、ASC 元数据、合法截图集、上传接受、TestFlight、App Review 与商标检索均没有证据。未上传 App Store，符合本轮停止条件。
