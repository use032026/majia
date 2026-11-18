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

## STMini 分批接入：第三批本地库存与显式页面渲染

各批实际接入、验证与待办统一追加至 [STMini 接入记录](docs/development/stmini-integration-log.md)。

当前只编译可运行的 foundation 子集，并非完整 Mini runtime。来源固定为 `stmini_flutter/main` 的 `b4462f63a33acf6c3fff63f0e67b3713bc00dff8`，依赖位于本 App 的 `packages/stmini_flutter`，以相对 path 解析。`UPSTREAM.json` 分别记录原样源、资源、来源哈希和阶段适配文件。

首批原样生产源码为 5 文件、304 物理行、13,390 字节；第二批修改其中事件所有权和地区资源解析两个文件后，它们改列派生源，累计仍逐字等上游的是 3 文件、217 行、10,040 字节。完整 main 的生产源码分母为 113 文件、20,683 行、823,442 字节，对应原样比例为 2.6549%、1.0492%、1.2193%。第三批累计另列 8 份派生源（1,270 行、66,639 字节）及 7 份本地生产 adapter/helper（1,188 行、42,342 字节），App startup 消费代码（187 行、6,205 字节）单列。事件契约参考片段为 19 行/710 字节，不把片段或派生实现算成新增完整原样文件；语言 JSON、隐私声明、许可和配置不计为生产代码进度。这些比例仅表示源码集成量，不是功能完成度。用户已接受自然基础层小于 20%，不为凑比例携带未使用的容器。

启动保留原首页，在首帧后调用一次初始化；process 级共享服务保留初始化终态和至多一个 SDK 事件订阅，Host 卸载重挂不重复初始化，非共享服务由创建者取消。失败、重复通知或卸载不阻止原日笺应用。Android 实际执行 main 的 `StminiHostConfiguration` 配置与语言解析，由 `StminiRuntimeEvents` 管理事件；iOS 实际执行 `STMiniLocalization` 的本地语言资源解析/缓存。`foundationState` 回读原生阶段、真实初始化状态和宿主身份；能力标明 `local_inventory`、`local_renderer` 和 `localRendererAvailable=true`，`stage=foundation` 保留初始化兼容含义。`miniLoadingAvailable`/`webLoadingAvailable=false` 表示完整 `openMini`/`openWeb` 链接、下载、安装和 Bridge 仍未接入，并不否认显式本地 renderer。仅接受 Deynu packageName，尚未接入的参数或方法明确返回 unsupported；合法空库存来自真实原生目录读取，查询失败与空库存分别处理。

第二批将原生 `foundation_initialized` 通过同一个共享 Dart 事件流交给 startup 的只读内存诊断；多 listener 共用原生订阅，最后一个 listener 取消时可 await 取消结果。事件模型严格校验 `name/payload` 并深冻结；控制 channel 的 listen/cancel 失败局部处理，不改全局 Flutter 错误处理。两端 late-listen 回放当前真实原生状态，取消后旧排队消息不能误投新 owner。Android 仅复制当前载荷顶层；此链自产状态不再改动嵌套 list，不承诺任意可变嵌套载荷都深快照。

iOS 仅修复已存在的 pt-BR/pt-PT 资源及 zh-TW/zh-HK/zh-CN 等 alias 匹配，保留未知语言回退；不新增语言设置/持久化或 Deynu UI 语言。诊断只留白名单状态及通用问题标记，不保存原始错误或任意桥接载荷。

第三批增加本地只读 `installedPackages()`，统一返回严格的 `miniId/miniName/version/entry/icon` 元数据 List。Android 从私有 filesDir/STMini、iOS 从可信 home/Documents/STMini 读取；每次重新校验 manifest 与 installed record，不使用上游 iOS 的正向缓存。目录缺失时真实返回合法空库存且不创建目录；坏记录、ID/版本/入口不一致、非普通文件、符号链接或不安全路径不进入库存。读取有候选、文件及字符串上限，在后台串行执行，重复请求拒绝 busy，取消和截止结果只完成一次。Dart 模型不可变，格式错误和 null 不会被当作空库存。

生产 startup 在初始化成功后实际查询一次，5 秒超时或原生失败只记通用失败状态，合法空库存则记 available/count 0；Host 重挂不重复查询，dispose 后迟到结果不更新诊断。库存接口不公开远程 iconUrl/launchLink 或文件内容；页面执行仅由下面独立、显式的本地 renderer API 提供。版本只支持 1–8 段、每段 1–9 位十进制数字并作精确字符串一致性校验，不接入版本比较；不符合该严格阶段域的旧包只读拒绝，不迁移或修复。

此批修正固定来源的 iOS `{packages: List}` 与 Dart/Android 顶层 List 不一致、缺少 verified version，以及旧本地路径/缓存校验缺口。它们是移植前修正的来源缺陷，不能据此声称原线上 Deynu 已发生库存故障。当前接口是明确的阶段子集，不声称与完整 Mini 宿主 wire 或所有历史包兼容，也不把本地文件一致性检查称作签名或密码学完整性验证。

第三批另提供显式 `StminiLocalView(miniId, version)`，通过真实 Flutter PlatformView 注册到双端本地 WebView。Android 显式使用 hybrid composition，让替换后的 WebView 子视图参与原生视图合成；创建、焦点和方向变化分别接入 Flutter 与 SDK 的生命周期。创建仅接受这两个身份字段，controller 只提供无参 state/reload/goBack/close；没有任意 URL、路径或 JavaScript 执行入口。状态严格包含 phase、canGoBack、errorCode，ready 仅表示受验的当前本地主文档已 commit，不等于所有 DOM/静态资源完成。Dart controller 单生命周期归属，identity/controller 变化关闭旧 view 并重建。

Android 使用 `https://<miniId>.stmini.local`，iOS 使用 `stmini://<miniId>.stmini.local`。每个资源都重验绑定 ID/version/entry 及当前 manifest/record 的 channel 一致性，并复查锚定普通文件、逐层非符号链接和严格单次 UTF-8 路径解码。非法 authority、port、userinfo、query、跨包、编码 slash/backslash/percent 不回退网络。每 view 最多 4 reader、单资源 8MiB、4 秒协作截止，超额直接拒绝，预算持有至实际 bytes/stream 释放；这不是整个 WebView 的内存上限。当前身份失效使 view failed 并停止，普通缺图只拒绝资源；reload 仍绑定旧 version/entry，新身份必须显式新建 view。

本地 JavaScript、CSS、图片和交互属于真实执行能力。Android CSP 使用标准 `'self'` 表示当前精确文档 origin，兼容含 underscore 的合法阶段 ID；仍禁 file/content 访问与网络加载，iOS 使用 nonPersistent 数据仓库和本地 scheme handler；没有原生 JSBridge 或账号注入。iOS 的 custom-scheme CSP 允许 `stmini:` scheme 源，本包 host/路径/身份仍由唯一 handler 精确检查，不能称为 CSP 精确 host。远程主导航、可执行资源和已列 HTTP(S)/WS、file/content/data/blob/new-window 尝试按真实 OS 证据验证；WebRTC、UDP、DNS 和物理设备未覆盖，不声称所有浏览器网络通道完全封闭。

跨文档导航、返回和 reload 重新建立 WebView，以本包 native history 和 generation 隔离旧回调；同页 fragment 保持已提交状态，不启动假首屏超时。普通产品 main 仍只初始化并查询库存，不挂载 renderer。fixture、真 Engine 验证 target 和 native instrumentation 仅测试使用，不是产品资产或隐藏入口。

本批插件编译上述受限本地 WebView renderer，不包含完整 Mini/Web 容器、网页桥、ZIP 安装/解包或下载模块，不提供 Mini 链接、隐藏开关、自动打开页面或参考工程业务配置。Android 插件 manifest 不新增权限/Activity/Provider，宿主已有隐私页面和平台权限按原工程保留。iOS 保持宿主最低 15.0，插件仅依赖 Flutter，并携带 main 的语言与 PrivacyInfo 资源。日笺存储键/schema、主题和双语界面不变。上游 LICENSE 仍为 TODO 占位，原文保留，不据此声称已核实外部分发许可。

完整接入版另已固定储藏于 Git 对象，不以隐藏资产混入此批。后续每批按真实编译依赖扩展并更新来源清单与比例；未接入能力持续明确拒绝，不能据基础层已初始化推断完整 Mini 已可用。
