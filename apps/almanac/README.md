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

## STMini 分批接入：第四批 iOS 本地 Mini 与 Android 基础容器

固定来源为 `stmini_flutter/main` 的 `b4462f63a33acf6c3fff63f0e67b3713bc00dff8`，App 通过相对 path 使用专属 `packages/stmini_flutter`。iOS 只读打开合格的已有本地 Mini，保留活动导航栈、根首文档启动覆盖层、Mini 内 H5、CMS Bridge 和独立域存储；关闭后重开生成新的 controller/document，使用正常 UIKit fullScreen 转场。独立 Flutter OnlineWeb 呈现、关闭后保活缓存、自定义快照转场和未消费的卡片组件已移除。Android 暂不接入第四批完整 Mini/OnlineWeb，保留第三批严格库存、受限本地 renderer 和事件 lease，仅补真实不支持回包与能力字段。

LBX 扫码组件及其两张专用图、Mini HTTP 下载、ZIP 解包安装、安装更新实现和 Tiercel 下载树已移除；第五批也不自动恢复，除非用户以后明确重提。来源与派生适配以插件 `UPSTREAM.json`、`SOURCE_MAP.json` 为准，历史批次证据保留在 [STMini 接入记录](docs/development/stmini-integration-log.md)。来源行数表示来源规模，不表示功能完成率或每行都已执行。

普通 `lib/main.dart` 仍显示 Deynu 原首页。启动只初始化、订阅状态并读一次严格库存；没有 Mini URL、自动打开、隐藏开关、远程激活、业务账号或量化交易 provider。SDK 由显式调用者消费，fixture target 不进入普通产品构建。原生编入/注册、普通 Dart AOT 消费和实际测试 target 执行分别留证。

### SDK 与平台能力

| 合同 | iOS | Android |
| --- | --- | --- |
| 初始化事件 / stage | `runtime_initialized` / `mini` | `foundation_initialized` / `foundation` |
| `miniLoadingAvailable` | `true`，仅合格已有本地包 | `false` |
| `webLoadingAvailable` | `false` | `false` |
| `miniChildWebAvailable` | `true`，仅活动 Mini 内 H5 | `false` |
| `closedMiniCacheAvailable` | `false`，关闭重开 fresh document | `false` |
| `localRendererAvailable` | `true` | `true` |
| 三项包下载/安装/更新能力 | 均 `false`，`miniPackageMode=local_only` | 均 `false` |

- iOS `openMini` 仍返回 `Future<void>`。任何已接受别名或重复参数中的非空下载地址，即使已有合格包也明确 `unsupported`；强制更新意图拒绝。缺包、身份失效或低于 `minSupportVersion ?? currentVersion` 明确失败，不回退 HTTPS、不创建/修复目录、不写包 metadata。Home 只由已验证本地 ID/version 构造只读链接，旧 record 的远程 launchLink 不触发下载或被重写。
- iOS 旧 `mini_checkMiniProgramUpdate`、`mini_downloadMiniProgramUpdate` 继续识别，回字符串 `code=0`、明确 `data.msg` 与 `supported=false`，不伪造已安装或进度成功。独立 `openWeb/closeWeb/notifyWebSessionChanged` 和连续保活方法也明确不支持。
- iOS 保留其余 CMS 回包、路由、UI、scoped storage 与宿主接口。`getUserInfo` 直接使用宿主 provider，旧宿主 profile/token 缓存和 WebStorage 镜像适配移除；标准 `mini_notifySessionChanged`、活动子页通知、document epoch 失效及原始安全 lease 保留。Deynu 没有账号/交易 provider，相关方法按合同失败。
- Android `openMini/openWeb/closeMini/closeWeb/notifyWebSessionChanged` 明确返回 `unsupported_capability`；不以本地 renderer 冒充完整 Mini 或普通 Web 容器。
- 两端严格五字段 `installedPackages()` List 为 `miniId/miniName/version/entry/icon`，每次复核 manifest/record/锚定普通文件；空目录不创建目录，坏记录与查询失败不冒充空库存。`StminiLocalView(miniId, version)` 和单生命周期 controller 保留资源身份、预算、取消、generation 与禁网边界。

iOS 完整本地容器逐次校验身份与路径，WK 绑定最初 id/version/entry，流式读取继续复核；异步回包、排队 UI、分享和相册写入使用最初 document generation/URL，权限返回后及真实写入前再核。活动根首文档可见才关闭启动覆盖层；子页、外部 Web、旧回调不得关闭新启动。Mini/HTTPS origin 的存储使用 SHA256 独立域，JS 不能选择宿主域或读取 Deynu `flutter.almanac_state_v1`。移除包安装不影响普通 scoped storage 写入、App 原隐私网页网络或显式图片保存。

### 构建、权限与验证

Android 完整 Mini/OnlineWeb 组件及其媒体保存实现不在本批构建中，不宣称其权限/系统行为通过。iOS App 最低版本仍 15.0，Pod 仍支持 13.0；显式保存路径在 iOS14+ 申请 add-only，旧宿主 legacy Photos 授权 fallback 保留，因此 Read/Add 用途使用真实保存措辞并提供英文/简体中文本地化。Camera 用途随扫码实现移除，无 microphone 用途，启动不请求这些权限。依赖为 HXWRefresh 1.1.0、Masonry 1.1.0、SDWebImage 5.21.7、Toast-Swift 5.1.1；ZIPFoundation 及专属锁记录移除。语言/Privacy 资源、原隐私政策路径、日笺 schema、主题及中英界面保留。

fixture、Flutter 专用 target、原生 instrumentation 和报告 writer 仅用于验证；本地包由 runner/test 在生产接口之外生成。iOS 完整报告通过 nonce regular-file probe/reader ack 采集，不增加生产报告桥。受控 loopback 正控与拒绝计数只证明指定端口观测范围。当前源码的 Dart 全量测试 122 项、私有 iOS 模拟器原生测试 37 项通过；两个已有本地 Mini 各 18 项 CMS/页面检查通过，包含实际 iframe transport 与 native gate、包操作拒绝、前后台及关闭。普通目标恢复与私有设备清理已核。Android 第三批基础 renderer 的新原生 instrumentation 和实际 FlutterEngine 默认后端路径通过，普通 main 已恢复、私有 AVD 已清理。双端普通 Release 构建与实际包检查通过，不借旧完整范围的验证。iOS 首轮增量 App 曾残留未链接的 ZIPFoundation framework，隔离完整旧 App 输出后重新生成并逐 Mach-O 核验，当前包无该残留。Android Release 维持第三批无 INTERNET、Camera 和广泛存储权限的 manifest，未增加完整 Mini 组件。

真实 TLS/线上 Mini、物理设备、账号交易、系统相册写入、分享发送及签名 IPA/商店结果未由这些本地测试证明。

### iOS 来源统计

固定分母为原生 iOS 86 文件 / 15,317 行（14,981 行实现与 336 行 headers），新增目标为 4,596–6,126 行。原完整 main 的 113 文件 / 20,683 行仅为历史参考；Android、共享 Dart、local adapters、supporting UI、资源、测试、no-caller/declaration 和 Release 排除代码不计本次 iOS 来源。仅统计 byte-equal source spans；扣所有旧参考的保守新增下界与相对已知同路径前三批子集的新增上界须整体入窗。已知前三批子集不代表前三批全部；cross-path/equivalent-derived 来源仍未知，不能据此倒推历史总量。

当前普通 Release 输入、真实 native/SDK 消费者与精确 SHA 求交后的 iOS 资格覆盖 25 个核心路径：累计 6,182 行，已知同路径前三批子集 80 行、保留交集 79 行；保守新增下界 5,632 行、相对已知子集的新增上界 6,103 行，整体落在目标内。详细范围与资格边界见 `SOURCE_MAP.json`；这不是每行机器码或每方法执行覆盖。资格只归当前本地无签名 App/framework，实际签名 IPA 另核。最后仅两处多余 EOF 换行机械清理，保留原测试观测 SHA 并以全文 body 字节一致证明复用语义执行证据；普通 iOS Release 已按新 SHA 重建，未将旧运行结果改称新 SHA 执行。

第五批仅本地整体验证和补缺，不签名、上传或送审，也不恢复已删能力。上游 `LICENSE` 的 TODO 原文保留，不据此声称已核实外部分发许可。保护的完整接入 stash 不用于本批恢复。
