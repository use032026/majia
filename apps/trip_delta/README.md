# Trip Delta / 旅程差额

离线优先的中英文旅行预算应用。用户可在出发前按类别规划预算，旅行中快速记录当地币种支出，并在结束后比较计划、估算折算和最终入账金额。

## 功能闭环

- 建立带日期、目的地、本位币和当地币种的行程，设置五类预算；首笔支出锁定预算基线。
- 首页分为“当前”和“历史”：当前页突出正在记录的旅程并直达新建表单，历史页按复盘时间排列并可按旅程名或目的地搜索。
- 快速记账并复用手填汇率；行程详情展示预算概览与最近三笔支出，完整预算对照和全部支出进入独立页面；在支出列表按类别、日期或待核对状态筛选。
- 外币支出先按汇率估算，需逐笔填写最终金额或明确确认估算金额，才能完成复盘。
- 对照类别差额、主要支出并记录原因；按最终总支出与原总预算的比例展示七档复盘评语；下次可选择原预算或本次最终支出作为可编辑的新计划。
- 主动导出 JSON 备份，并预览后合并或替换导入。合并时保留本机同 ID 旅程；替换会覆盖全部本机记录。

## 产品边界

- Flutter，iOS / Android
- 本地 Application Support 文件持久化
- 备份文件由用户选择保存位置；无自动云同步
- 无账号、后台、广告或分析 SDK
- 手填汇率可按旅程复用，不依赖在线汇率
- 中文和英文
- 隐私页可加载在线 HTTPS 政策；旅程的规划、记账与复盘仍可离线使用
- iOS、Android 图标共用 [`assets/brand/app_icon.svg`](assets/brand/app_icon.svg)；调整后运行 `bash tool/generate_app_icons.sh` 更新各尺寸资源

## 在线隐私政策地址

应用默认按当前语言加载已发布的[中文隐私政策](https://gotripdelta.com/privacy.html?lang=zh)或[英文隐私政策](https://gotripdelta.com/privacy.html?lang=en)。构建时仍可用 `--dart-define=TRIP_DELTA_PRIVACY_URL=<HTTPS 地址>` 覆盖共同网址，或用 `TRIP_DELTA_PRIVACY_URL_ZH`、`TRIP_DELTA_PRIVACY_URL_EN` 分别覆盖；只接受 HTTPS。在线加载失败会显示本地数据摘要，并提供重试；回到应用时也会再试一次。

## iOS 在线 Web 首页开关

iOS 使用 `stmini_flutter/mini_web` 的 Web-only 容器。本机独立偏好默认关闭，
旧安装无偏好、文件损坏或读取失败时均按关闭处理，保留原有旅程、引导和数据恢复流程。
在当前页“当前 / Current”标题连续按住满 **5 秒**，保存本机偏好后直接切换网页首页，
不显示设置弹窗或确认开关。未满时间松开、移出或取消不会切换。没有新增普通首页按钮。

开启时先保存本机偏好，成功后移除旅程根界面，切换到 Web 准备页并打开网页。
后续冷启动先读取该偏好，开启时直接进入 Web 根，不创建或闪现旅程界面。
偏好独立于旅程数据和 JSON 备份，不改变旅程、语言或引导数据。
Web 模式没有关闭开关入口，也不提供返回旅程的原生按钮或其他恢复手势。
默认在线地址与参考工程 Verdant Frame 相同：`https://h5.globalsmartchoose.com/polymer/h5app/#/`。

```dart
final webHost = TripDeltaWebHost();
// Web 根在 Flutter 首帧后初始化，并明确隐藏首页的原生导航栏。
await webHost.initialize();
await webHost.openHome(showNavigationBar: false);
// 宿主销毁时释放 Bridge handler。
webHost.dispose();
```

Web 根负责服务实例和原生事件订阅的生命周期，旅程根不会提前释放 Web 根的服务。
Web Bridge 的 `getPackageName` 返回实际 iOS 宿主身份 `com.tripdelta.lite.app`。
Android 本批不接入：依赖不注册 Android 插件、不包含 Android 原生源码，
宿主在 Android 不初始化或调用 STMini channel；显式打开会报告平台不支持。
Android 原有旅程业务和工程配置保持原样。
与参考相同，原生承载为全屏 Web 导航栈，首页隐藏导航栏；这不是替换 UIWindow 根控制器。
子页继续按现有 H5 `/web` 参数和内部路由协议导航、返回及侧滑，不猜测 Dart 栈深。
普通 Bridge 的 `close` 在子页 pop、在根页可 dismiss 原生栈；根关闭后仍只显示 Web 重试页，
不返回旅程，也不循环自动重开。Web 准备失败可在该页显式重试。
该页覆盖初始化、原生呈现、事件流错误和根关闭状态；`openHome` 完成只证明原生呈现完成，
不等于 H5 文档加载成功。现有组件未向 Dart 提供 WKWebView 加载失败事件，
真实网页网络错误由容器原生加载层显示失败和重试，不能据 mock 声称已验证断网或线上 H5 业务。
内部路由仍仅允许同首页 origin 请求，每次显式 H5 导航独立，不按 URL 去重。
仅接受 HTTPS，不放开 ATS/Android cleartext，不复制参考工程的包名、账号或认证快照。
普通 Bridge 支持打开、关闭、无凭据会话变化通知及诊断应答，未知方法返回失败。
主 frame、当前页面来源及生命周期由原生 Web Core 处理；未接入 Mini 下载、离线包或 `openMini`。

为使干净 checkout 与 CI 可复现，依赖使用应用内 `packages/stmini_flutter` 的发行源码快照，
不依赖本机相邻目录。来源固定为 `mini_web` 的
`0ee3118f1998ba0cec8f12c377ce01d079b86914`，逐文件 SHA-256 和升级步骤见
[`UPSTREAM.json`](packages/stmini_flutter/UPSTREAM.json)。快照仅保留 Dart/iOS 所需文件，
插件 pubspec 裁掉 Android 注册，其余上游文件原样保留；来源及适配差异在清单中明确。
LICENSE 当前未声明开源许可，
不将其描述为某种开源许可证。后续升级需更新来源清单并重新核对 Dart、iOS 及 Android 未接入边界。

iOS 继续使用工程原有的 15.0，满足插件最低 13.0。
本次底层接入测试不等于线上 H5 登录、实际 WebView 或真机验收；相关限制以交付记录为准。

### 网页首页冷启动画面

网页模式的 Flutter 准备页和原生 WebView 使用安卓 `newsclient/dev/dev_s86` 的中英文全屏启动图，
不叠加转圈。中文（含简繁体）使用中文图，其余语言使用英文图。H5 手动语言优先；
没有手动选择时跟随当前系统语言。容器只观察 H5 现有的 `language` / `language_user_set`，
独立保存手动语言供下次启动使用，不修改 H5 源码或复制账号数据。
iOS 最初的系统 LaunchScreen 仍为原生旅程品牌；读取到网页偏好后进入上述网页启动画面。
首页复用 H5 现有的 `futrenapp:startup-complete` 事件，
在事件后的两次动画帧回调后移除原生遮罩；不以原生呈现完成或 `didFinish` 替代 H5 就绪。
H5 的 `futrenapp:startup-failed`、主文档网络失败或 25 秒超时会显示原生重试入口。
重试重新加载首页，保持网页模式与原旅程数据。配置仅用于首页控制器，普通子页使用默认文档加载层。
本次没有调整活动 iframe 的 Bridge 调用方式。

图片来源固定为 `newsclient/dev/dev_s86@77aec95ba8471293688ed4d54f77a6343220e3ad`：
`app/src/main/res/drawable-xxxhdpi/ic_splash_logo_full.png` 与 `ic_splash_logo_full_en.png`。
App 配置只提供 Flutter asset 路径；STMini 不包含 s86 图片或业务品牌。

内置组件已同步到上述上游提交，逐文件哈希记录在 `UPSTREAM.json.files`；仅保留 iOS 插件注册的适配。

## 本地验证命令

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --release --no-codesign
# Android 本批不接入 STMini，不以 Android 构建作为本批 Web 验收项。
```

当前 iOS Bundle ID 为 `com.tripdelta.lite.app`，Android 包名为 `com.tripdelta.lite`。隐私政策已公开并接入应用；支持 URL、品牌权利核验、iOS 签名和真机验证等上架事项仍待处理。历史预检报告针对旧工件，需对最终签名构建重跑。详见 [`docs/release/APP_STORE_PREFLIGHT.md`](docs/release/APP_STORE_PREFLIGHT.md)。
