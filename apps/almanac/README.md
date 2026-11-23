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

## STMini 第六批：iOS 显式下载安装与更新

本批扩展 `packages/stmini_flutter` 的 iOS Mini 运行时；固定来源 `b4462f63a33acf6c3fff63f0e67b3713bc00dff8`，按行为适配最新上游 `46d1521db5ebebcabbee3304834a6739fc968afa` 的适用安全修复。Android 保留原 foundation、严格库存和受限 renderer。普通 `lib/main.dart` 仍为 Deynu 原首页，启动只初始化、订阅状态和读取库存；没有生产 Mini/Web URL、产品入口、隐藏开关、远程激活、相机扫码、账户或交易 provider。

| 能力 | iOS | Android |
| --- | --- | --- |
| stage / Mini 模式 | mini / mini | foundation |
| Mini 包模式 | download_install_update | local_only |
| 下载、安装、更新 | true，调用者显式 HTTPS 链接 | 均 false |
| 普通 HTTPS Web、Mini 内 H5、严格保活缓存 | true | false |
| 本地 renderer | true | true |

显式 `openMini` 支持首次网络安装、当前版本直接本地打开、兼容旧包先开并弱更新、不兼容旧包强制下载后打开。包内 `mini_downloadMiniProgramUpdate` 只更新当前已验证 root 的自身身份，保留现行 downloadUrl/isforce 信封；宿主更新检查服务未接入，`mini_checkMiniProgramUpdate` 明确返回 unsupported。没有后台自动轮询或生产源。

下载只接受无用户凭据和 fragment 的 HTTPS URL，重定向与最终响应再次校验；不降低 ATS/TLS，不加入 Debug HTTP 例外。真实 URLSession 进度、下载后处理和已验证本地根文档可见分别处理。ZIPFoundation 固定0.9.19。ZIP 输入最多80MiB，解包及最终包最多80MiB、最多4095个归档项；拒绝穿越、绝对路径、符号链接、重复及大小写冲突、非法类型、超限文件、错误ID/版本/entry/icon/manifest。版本最低线不得回退到不兼容旧包。安装在 staging 校验后按同包事务锁内重新读取已安装版本，原子替换失败回滚；旧/同版本保留已有较新包。

每次下载持有原操作的取消许可。关闭、隐藏、session换代或 engine teardown 撤销旧许可，提交与取消共享锁；迟到下载/安装结果不得改写新owner或关闭其加载层。弱更新不替换活动或保活 WK 的资源：根与本地H5栈共享严格复验的不可变 `MiniPackageSnapshot`，新磁盘包只供新冷启动使用，最后native consumer释放后清理快照。强更新保留精确native owner、更换WK与快照，旧文档立即撤权；失败提供原有关闭/重试。仅本root创建的精确failure alert可由host closeMini收尾，其他foreign UI仍保留。

普通Web转发的异步回包从原始请求捕获document/effect/session/channel绑定，到回包及最终JS投递再次校验。iOS默认反向receiver保留第五批处理，Android初始化不扩能力。

当前第六批已完成本机验证：Dart 格式与 analyze 通过，全量127项、隔离后67项回归通过；全新私有 iOS 模拟器原生74项零失败，真实HTTPS完成首装v1、保活同WK弱更落盘v2且运行仍用v1、关闭后冷开v2、最低版本3拒绝，以及普通Web两轮隔离。普通 `lib/main.dart` device Release构建通过，实际Mach-O保留下载/快照运行时并链接ZIPFoundation，未含Scanner/Tiercel/相机或测试fixture。普通Debug首启图为原引导，既有schema合成回访图为原日笺主页；不作真机或Release运行结论。

`SOURCE_MAP.json` 已按当前native/SDK/普通unsigned Release的精确输入重新认定：固定iOS来源86文件/15,317物理行，当前保守合格来源7,690行，保留第五候选833行，第六下载候选759行；较第五新增合格来源位置764、原位置不再字节相等38。派生snapshot/取消与document guard、Dart、测试、ZIPFoundation及无consumer镜像均零来源信用。非字节相等不代表行为未实现，来源行数不是功能完成比例；第五和第四历史统计独立保留。独立最终Review/cross、签名IPA及商店结果分列确认，当前验证不代替发行门禁。

iOS最低15.0、Pod13.0及已有显式保存相册用途/本地化保留；无新增启动权限请求。历史实现和失败证据见 [接入记录](docs/development/stmini-integration-log.md)。第六批已获构建上传及送审授权，但实际新增能力须准确披露，商店文本不由实现子任务修改；实际送审状态独立回读。
