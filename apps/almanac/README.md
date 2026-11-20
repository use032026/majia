# Deynu

Deynu 是一个离线优先、无账号的中英文 Flutter 日常反思应用。它借用传统“宜/忌”的简洁形式，但不提供运势、吉凶、择日、真实农历或完整日历。

核心流程：阅读当天稳定生成的原创提示与短诗 → 选择一项 Try/宜和一项 Skip/忌 → 写可选意图 → 收笺 → 回看 → 在本地笺册留存或复制为 Markdown。

## 应用名称

应用对外名称统一为 **Deynu**（中英文界面均使用该名称）。项目目录 `apps/almanac`、Dart 包名、Bundle/Application ID、网站域名和本地存储键继续沿用现有值。历史运行截图及构建证据记录的是改名前的版本。

## 平台

- iOS 15.0+
- Android minSdk 24 / targetSdk 36
- 简体中文与英文
- 无账号、应用后台、广告、分析或订阅；核心功能离线可用

## 在线隐私协议

- 从“设置 → 隐私政策”进入，中文和英文分别使用 `https://www.almanac1.com/privacy.html?lang=zh` 和 `https://www.almanac1.com/privacy.html?lang=en`。
- iOS 只在主动点击入口后，由 App 的 URLSession 获取协议内容，再交给 App 内的 WKWebView 展示，保留原网址、语言参数和网页资源。系统在需要时显示该 App 的联网授权提示，是否弹出由设备及既有授权状态决定。
- 网页加载失败时可重试或复制网址，关闭后返回原页面；无法打开原生页面时仍保留原有本地数据说明和重试入口。
- Android 保持原有系统浏览器视图。打开协议不会携带日笺、意图或回看记录，也不改变其他业务逻辑。

## 本地运行

```sh
flutter pub get
flutter run
```

## 验证

```sh
dart format --output=none --set-exit-if-changed lib test packages/stmini_flutter/lib
flutter analyze
flutter test
```

完整可复现质量结果见 `docs/release/evidence/automation/20261010T155447+0800/QUALITY_GATE.md`。

## 文档

- 产品与验收：`docs/product/PRODUCT_BRIEF.md`
- 市场证据：`docs/product/MARKET_EVIDENCE.md`
- 差异化报告：`docs/product/DIFFERENTIATION.md`
- 功能审核：`docs/release/FUNCTIONAL_REVIEW.md`
- 商店预检：`docs/release/APP_STORE_PREFLIGHT.md`
- 证据登记：`docs/release/EVIDENCE_REGISTER.md`
- 发布待办：`docs/release/GAP_BACKLOG.md`

## 发布边界

iOS 已接入 `Deynu iOS Release` 签名构建/上传流程和 `ASC Existing Build Release` 复用构建送审流程，使用 `almanac-production` Environment。构建来源、版本、构建号及 App Store Connect 处理/审核状态以对应运行证据为准；本地测试通过不替代签名包、设备验证或商店结果。

新版本按当前发布配置在审核通过后自动发布。修改源码配置不会公开发布仍待手动发布的历史版本；这类历史版本必须另行核实并取得发布授权。商店更新说明仅使用已存在的 App Store 语言，不因 App 支持中英文而自动新建商店语言，也不默认覆盖描述或截图。旧预检文档和运行截图保留为历史证据，不代表当前发布状态。

## STMini 分批接入：第五批 iOS 缓存、转场与独立 Web

固定来源为 `stmini_flutter/main` 的 `b4462f63a33acf6c3fff63f0e67b3713bc00dff8`，App 通过相对 path 使用专属 `packages/stmini_flutter`。第五批仅扩展 iOS：合格已有本地 Mini 的 FIFO2 缓存、显式空默认白名单 continuous 保活、当前 owner 快照/自定义转场，以及显式 SDK 普通 HTTPS Web。Android 保留原 foundation/严格库存/受限 renderer，没有新增完整 Mini/Web 接入。

普通 `lib/main.dart` 仍为 Deynu 原首页，启动仅初始化、订阅状态并读取严格库存。没有生产 Mini/Web URL、页面入口、隐藏开关、自动打开、远程激活、账户或量化交易 provider。原生注册/编入、普通 Dart AOT 消费和专用测试 target 执行分别留证；未被普通首页调用的 Dart SDK 方法不据此声称保留于普通 AOT。

### SDK 与平台能力

| 合同 | iOS | Android |
| --- | --- | --- |
| 初始化事件 / stage | `runtime_initialized` / `mini` | `foundation_initialized` / `foundation` |
| `miniLoadingAvailable` | `true`，仅合格已有本地包 | `false` |
| `webLoadingAvailable` | `true`，显式普通 HTTPS Web | `false` |
| `miniChildWebAvailable` | `true`，活动 Mini 内 H5 | `false` |
| `closedMiniCacheAvailable` | `true`，strict identity/session warm reuse | `false` |
| `localRendererAvailable` | `true` | `true` |
| 下载 / 安装 / 更新能力 | 均 `false`，`miniPackageMode=local_only` | 均 `false` |

- `openMini` 只读打开已有本地包。非空下载地址、强制更新、缺包、身份失效或低于版本 floor 均明确失败，不回退 HTTPS、不修复目录、不写包 metadata。旧更新方法返回字符串 `code=0`、明确 `data.msg` 和 `supported=false`。
- 关闭 Mini 同步撤销根与全部 H5 的 native effect lease，再按 FIFO2 或显式白名单缓存。warm reuse 重查完整有界包 bytes、ID/version/entry 和 session 代次，实际可见后才授新 epoch，旧异步许可永久失效。内存警告、FIFO 淘汰、内容进程终止和 engine detach 释放对应 runtime；session 换代清除旧缓存并撤销旧许可。不能因透明保活 host 仍在 window 就认定可调用原生能力。
- iOS `openWeb/closeWeb/notifyWebSessionChanged` 消费独立普通 HTTPS Web，不继承 Mini 权限。宿主标题/导航栏配置不改调用者 URL。host replacement 与 Mini 子页等 URL FIFO 分开；被替换/取消请求明确失败，覆盖期间 host open/close 返回 `web_covered`，session count 为0。当前 stable 可见文档才可 fresh grant；关闭/卸载只处理原 owner，不关闭 unrelated foreign UI。
- iOS 初始化在 native invoke 前安装默认反向 receiver，不安装业务 provider。没有 handler 的 ordinary Web 请求标准失败 `code=0`，不会因没有 listener 悬空；显式 provider 跨重复初始化保留。Android 初始化不新增默认 receiver，完整 Mini/Web 方法继续 `unsupported_capability`。
- 主 frame、当前文档/HTTPS origin、原始 generation 与 native owner lease 在接收和异步回包处均校验。存储按 Mini/origin 的 SHA256 独立域隔离，JS 不能选择宿主域或访问 `flutter.almanac_state_v1`；没有宿主 token/profile fallback 或标准 defaults 镜像。

### 包、权限与验证边界

本批不包含 Mini 下载、ZIP 安装或更新，也没有 ZIPFoundation/Tiercel 依赖。用户指定的真实 URLSession 下载、原子安装/更新属于第六批最终本地范围；安全 scoped 镜像仅在有实际 consumer 时接入，可为0。LBX/Camera/Scanner 和截图 fallback 持续排除；没有调用者的 Tiercel、旧非原子 helper 或卡片不会为来源行数恢复。

iOS App 最低版本15.0、Pod13.0不变。原显式图片保存使用 iOS14+ add-only 与旧宿主 Photos fallback，真实 Read/Add 保存用途及英文/简体中文本地化保留；无 Camera/Microphone 用途，启动不请求权限。依赖仍为 HXWRefresh1.1.0、Masonry1.1.0、SDWebImage5.21.7、Toast-Swift5.1.1。

当前 Dart 全量127项、analyze、format check通过。最新任务私有 iPhone16/iOS18.2 完整原生61项重新执行全部通过，包含正式关闭后同 instance warm reopen 的 visibility-before-appShow 顺序、后台时长一次消费、关闭/文档换代/session换代后旧排队 ticket 拒绝及 appHide 即时投递回归。此次纠正 WarmActivationTicket 使用通用 UINavigationController 导致外部覆盖保护无法编译的问题，在消费边界明确验证 STWebNavigationController 类型。真实两个已有 Mini 各18项页面/CMS检查、两个受控 HTTPS Web 文档各12项检查全部通过，包含 CSS/JS/pixel、iframe transport 正控与 native 拒绝、storage、缺 provider 标准失败、session与关闭重开不同文档；前后台 appHide/show 观测通过。执行记录为 takeover1120v2，普通 main 已恢复，私有模拟器、loopback TLS server 和临时合成 CA/keys 已清理。没有改 ATS 或生产信任策略。

普通 `lib/main.dart` 无签名 device Release 构建及实际逐 Mach-O 包扫描通过，缓存/runtime host/转场/Web 等核心类型实际链接；无 Camera/Scanner、ZIPFoundation/Tiercel 或测试 fixture 残留。Android host/插件34个 tracked 文件与本批基线逐字相同，未新增 Android 构建或设备验证。以上不证明物理设备交互手势、真实相册写入、分享发送、线上 Mini、签名 IPA 或商店结果；实际签名包与发行由独立门禁另核。

### iOS 来源统计

固定 native iOS 分母86文件/15,317物理行，Android、共享 Dart、测试、资源、local guard 改写、supporting UI 和无 consumer 代码不计来源信用。当前27核心路径与普通 Release 输入、实际链接及 native/SDK consumer 的精确 SHA 求交后，累计合格6,964行；第五批批准候选中的实际合格833行（Web158、cache457、transition218）。相对已知 C3 source 集合新留存841行、未再逐字留存59行；这不是功能损失、功能百分比或每行机器码/执行覆盖。

第六批真实下载、解压安装和更新尚未实施/构建/consumer 合格；可选安全镜像仅有实际消费者时接入。逐字来源行数排除安全改写，因此不作为两批工作量或功能完成百分比；最终两批比例须第六完成后实测。详细 path+line/交并与限制见 `SOURCE_MAP.json`、`UPSTREAM.json`，历史 C3 统计独立保留。

历史过程见 [STMini 接入记录](docs/development/stmini-integration-log.md)。第五批按当前授权在独立门禁通过后继续提交审核；第六先仅本地。上游 `LICENSE` TODO 原文保留；保护的完整接入 stash 未用于恢复。
