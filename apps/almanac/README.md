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

## STMini 分批接入：第四批完整原生容器与 Bridge

固定来源为 `stmini_flutter/main` 的 `b4462f63a33acf6c3fff63f0e67b3713bc00dff8`，App 通过相对 path 使用专属 `packages/stmini_flutter`。本批迁入完整原生 Mini 容器、MiniLink、版本门槛、下载/ZIP 原子安装、导航栈、保活池、启动覆盖层及 OnlineWeb，并接上 Dart SDK 与双端原生 Bridge。当前来源与派生适配以插件 `UPSTREAM.json` 和 `SOURCE_MAP.json` 为准；既往批次的精确来源量、签名和发行结果保留在 [STMini 接入记录](docs/development/stmini-integration-log.md)。来源行数表示来源集成规模，不表示功能完成率或每行都已执行。

普通 `lib/main.dart` 仍显示 Deynu 原首页。启动只初始化、订阅状态并读一次严格库存；没有 Mini URL、自动打开、隐藏开关、远程激活、业务账号或量化交易 provider。完整 SDK API 由显式调用者消费，测试 target 不进入普通产品构建。原生编入/注册、普通 Dart AOT 实际消费和真实测试 target 执行分别留证，不因源码存在就声称产品已有 Mini 页面入口。

### SDK 与能力边界

- `foundationState` 及 runtime 状态反映真实 `stage=mini` / `runtimeMode=mini`，Mini/Web 加载能力为 true；`openMini`、`openWeb`、关闭、Web session 通知与 handler 接线均进入原生实现。
- 完整原生 dispatcher 支持既有 CMS 回包、路由、UI、存储、宿主接口及平台能力。需要宿主业务 provider、权限或上下文的方法按合同失败；Deynu 不注入账号、交易或 legacy storage。不能把 provider 缺失概括为所有 Bridge 都 unsupported。
- 保留第三批严格五字段 `installedPackages()` List：`miniId/miniName/version/entry/icon`，每次复核 manifest/record/锚定普通文件，空目录不创建目录。接口不公开远程链接或文件内容，坏记录与查询失败不冒充空库存。
- 保留显式 `StminiLocalView(miniId, version)` 和单生命周期 controller；受限本地 renderer 与完整容器是不同调用面。原本地 renderer 继续使用严格资源身份、预算、取消、generation 和禁网边界。

完整 Mini 的运行下限是 `minSupportVersion ?? currentVersion`；ZIP 还须满足两项已声明版本。兼容下限内的弱更新可继续运行，强制更新失败不可打开低于下限的旧包；同版 kept，强同版可冷重载，低版更新不得覆盖磁盘高版。安装在提交前重读当前磁盘，原子替换失败回滚；Android 只有实际 changed 才发安装变化事件；iOS kept 若补充 launchLink，保留既有 Home 注册表通知。

完整本地资源逐次校验 Mini 身份与路径；iOS WK 绑定最初的 id/version/entry，流式读取仍复核，Android 保留域无效资源直接拒绝且不回退网络。异步回包、排队 UI、分享和相册写入使用最初 document generation/URL，权限返回后、真实写入前再核。Mini 与 ordinary HTTPS origin 的原生存储分别使用 SHA256 主体独立域，JS 不能选择宿主域或读取 Deynu `flutter.almanac_state_v1`。

### 构建、权限与验证

Android 宿主移除外部存储读写权限：API 24–28 的显式相册保存按无权限失败，API 29+ 使用 scoped MediaStore；系统实际保存尚未验证。Mini/OnlineWeb 组件为 non-exported；完整 native SDK 的可见能力必须按实际合并 manifest 与最终 APK 复核。iOS 最低版本仍 15.0，新增 Photos add 描述只供显式保存调用申请权限，未加入 camera/microphone 描述。完整依赖为 HXWRefresh 1.1.0、Masonry 1.1.0、SDWebImage 5.21.7、Toast-Swift 5.1.1、ZIPFoundation 0.9.20；语言资源和 Privacy 声明继续携带。原隐私政策路径、日笺 schema、主题与中英界面保持。

测试 fixture、Flutter 专用 target、原生 instrumentation 和报告 writer 仅用于验证。完整报告通过 nonce 和显式私有目录进行 probe/reader ack 后采集，不增加生产报告桥。模拟 URLProtocol/URLStreamHandler、真实模拟器 SDK/WebView、普通 unsigned Release 与签名 IPA 各自证明不同层级；真实 TLS/线上 Mini、物理设备、账号交易、系统相册写入和分享发送没有据此获得验证。实际逐项命令、失败和复测结论见接入记录；编译成功不能替代完整审核。

### 当前来源与本地验证

当前普通 Release 的全部模块输入、依赖锁、原生注册/链接与受控 SDK 消费均按当前源码 SHA 绑定。`SOURCE_MAP.json` 的准入来源合计为 13,514 条真实去重 source path+line；额外扣除所有此前引用范围后的第四批保守新增下界为 12,467，达到 10,342 的门槛。这两个量不可相加，也不表示每行各有保留机器码或已逐行执行。

| 平台 | 当前准入来源行 | 额外引用扣重后的新增下界 | 制品边界 |
| --- | ---: | ---: | --- |
| iOS | 8,562 | 8,011 | 本地无签名 Runner.app / 原生 framework |
| Android | 4,952 | 4,456 | Android APK |

固定来源分母 20,683 行分为 Android 实现 5,133、iOS 实现 14,981、headers 336 和 shared Dart 233。已知前三批同路径逐字子集为 320 行，当前保留 317、移出 3，当前相对该已知子集的新行是 13,197；这不是前三批全部来源量，跨路径派生和等价改行仍未知。Android 行数不得归入 iOS IPA；实际签名 IPA 的来源资格须另行核验。

当前 iOS 完整原生测试 40 项通过，Android JVM 92 项通过；双端完整 SDK 的两个 Mini 各有 17 项检查通过并正常关闭，iOS 的生命周期事件实际观测于 A，Android 于 B。Android 原生矩阵按源码、测试及锁逐 SHA 复用已执行结果，并非在每轮 SDK 验证重跑。普通双端 Release 已构建并验包：原生组件/链接、资源和权限边界正确，普通产品制品没有测试 fixture。最终 Dart 格式检查、静态分析和 119 项全量测试通过，之后五个文件的 50 项 fake 回归通过；50 项是重叠子集，不与 119 相加。这些是本地构建与受控运行证据，实际未覆盖范围仍以上述能力边界为准。

签名上传和商店结果由单独发行门禁记录。第五批仅本地完整整体验证和补缺，不签名、上传或送审。上游 `LICENSE` 的 TODO 原文保留，不据此声称已核实外部分发许可。保护的完整接入 stash 不用于本批恢复。
