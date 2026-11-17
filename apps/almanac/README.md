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

## STMini 分批接入：第二批基础事件与地区资源修复

各批实际接入、验证与待办统一追加至 [STMini 接入记录](docs/development/stmini-integration-log.md)。

当前只编译可运行的 foundation 子集，并非完整 Mini runtime。来源固定为 `stmini_flutter/main` 的 `b4462f63a33acf6c3fff63f0e67b3713bc00dff8`，依赖位于本 App 的 `packages/stmini_flutter`，以相对 path 解析。`UPSTREAM.json` 分别记录原样源、资源、来源哈希和阶段适配文件。

首批原样生产源码为 5 文件、304 物理行、13,390 字节；第二批修改其中事件所有权和地区资源解析两个文件后，它们改列派生源，累计仍逐字等上游的是 3 文件、217 行、10,040 字节。完整 main 的生产源码分母为 113 文件、20,683 行、823,442 字节，对应原样比例为 2.6549%、1.0492%、1.2193%。另列两份派生源（121 行、4,941 字节）及 5 份本地生产 adapter/helper（470 行、17,244 字节），App startup 消费代码单列。事件契约参考片段为 19 行/710 字节，不把片段或派生实现算成新增完整原样文件；语言 JSON、隐私声明、许可和配置不计为生产代码进度。这些比例仅表示源码集成量，不是功能完成度。用户已接受自然基础层小于 20%，不为凑比例携带未使用的容器。

启动保留原首页，在首帧后调用一次初始化；process 级共享服务保留初始化终态和至多一个 SDK 事件订阅，Host 卸载重挂不重复初始化，非共享服务由创建者取消。失败、重复通知或卸载不阻止原日笺应用。Android 实际执行 main 的 `StminiHostConfiguration` 配置与语言解析，由 `StminiRuntimeEvents` 管理事件；iOS 实际执行 `STMiniLocalization` 的本地语言资源解析/缓存。`foundationState` 回读原生阶段、真实初始化状态和宿主身份；能力标明 Mini/Web loading 不可用。仅接受 Deynu packageName，尚未接入的参数或方法明确返回 unsupported，不返回空包或假成功。

第二批将原生 `foundation_initialized` 通过同一个共享 Dart 事件流交给 startup 的只读内存诊断；多 listener 共用原生订阅，最后一个 listener 取消时可 await 取消结果。事件模型严格校验 `name/payload` 并深冻结；控制 channel 的 listen/cancel 失败局部处理，不改全局 Flutter 错误处理。两端 late-listen 回放当前真实原生状态，取消后旧排队消息不能误投新 owner。Android 仅复制当前载荷顶层；此链自产状态不再改动嵌套 list，不承诺任意可变嵌套载荷都深快照。

iOS 仅修复已存在的 pt-BR/pt-PT 资源及 zh-TW/zh-HK/zh-CN 等 alias 匹配，保留未知语言回退；不新增语言设置/持久化或 Deynu UI 语言。诊断只留白名单状态及通用问题标记，不保存原始错误或任意桥接载荷。

本批的 STMini 插件不编译 Mini/WebView 容器、网页桥、ZIP 安装/解包或下载模块，不提供 Mini 链接、隐藏开关、自动打开页面或参考工程业务配置。Android 插件 manifest 不新增权限/Activity/Provider，宿主已有隐私页面和平台权限按原工程保留。iOS 保持宿主最低 15.0，插件仅依赖 Flutter，并携带 main 的语言与 PrivacyInfo 资源。日笺存储键/schema、主题和双语界面不变。上游 LICENSE 仍为 TODO 占位，原文保留，不据此声称已核实外部分发许可。

完整接入版另已固定储藏于 Git 对象，不以隐藏资产混入此批。后续每批按真实编译依赖扩展并更新来源清单与比例；未接入能力持续明确拒绝，不能据基础层已初始化推断完整 Mini 已可用。
