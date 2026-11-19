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

## iOS STMini 在线 Web 底层接入

iOS 使用 `stmini_flutter/mini_web` 的 Web-only 容器，在 Flutter 首帧后仅初始化。
旅程首页、引导和原有导航保持原样，不自动打开网页，也不增加按钮或隐藏触发入口。
需要由后续已确认的业务流程显式调用 `TripDeltaWebHost.openHome()`；当前没有用户可见的打开入口。
默认在线地址与参考工程 Verdant Frame 相同：`https://h5.globalsmartchoose.com/polymer/h5app/#/`。

```dart
final webHost = TripDeltaWebHost();
// 初始化不打开页面；同一实例可在已确认的业务触发点显式打开。
await webHost.initialize();
await webHost.openHome();
// 宿主销毁时释放 Bridge handler。
webHost.dispose();
```

生产入口仅在 iOS 将服务实例交给 `TripDeltaApp`，由应用负责首帧初始化和销毁。
Android 本批不接入：依赖不注册 Android 插件、不包含 Android 原生源码，
宿主在 Android 不初始化或调用 STMini channel；显式打开会报告平台不支持。
Android 原有旅程业务和工程配置保持原样。
Web 打开默认保留原生导航栏与返回路径；H5 的 `/web` 请求按其导航参数处理，
内部路由沿用参考工程的子页协议，仅允许同首页 origin 请求。每次显式打开均独立导航，
不按 URL 去重。初始化失败不阻断离线旅程，后续显式调用可重试。
仅接受 HTTPS，不放开 ATS/Android cleartext，不复制参考工程的包名、账号或认证快照。
普通 Bridge 支持打开、关闭、无凭据会话变化通知及诊断应答，未知方法返回失败。
主 frame、当前页面来源及生命周期由原生 Web Core 处理；未接入 Mini 下载、离线包或 `openMini`。

为使干净 checkout 与 CI 可复现，依赖使用应用内 `packages/stmini_flutter` 的发行源码快照，
不依赖本机相邻目录。来源固定为 `mini_web` 的
`78b5a71561babfdf070488a08941eb94d2072e40`，逐文件 SHA-256 和升级步骤见
[`UPSTREAM.json`](packages/stmini_flutter/UPSTREAM.json)。快照仅保留 Dart/iOS 所需文件，
插件 pubspec 裁掉 Android 注册，其余上游文件原样保留；来源及适配差异在清单中明确。
LICENSE 当前未声明开源许可，
不将其描述为某种开源许可证。后续升级需更新来源清单并重新核对 Dart、iOS 及 Android 未接入边界。

iOS 继续使用工程原有的 15.0，满足插件最低 13.0。
本次底层接入测试不等于线上 H5 登录、实际 WebView 或真机验收；相关限制以交付记录为准。

## 本地验证命令

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --release --no-codesign
# Android 本批不接入 STMini，不以 Android 构建作为本批 Web 验收项。
```

当前 iOS Bundle ID 与 Android 包名均为 `com.tripdelta.lite`。隐私政策已公开并接入应用；支持 URL、品牌权利核验、iOS 签名和真机验证等上架事项仍待处理。历史预检报告针对旧工件，需对最终签名构建重跑。详见 [`docs/release/APP_STORE_PREFLIGHT.md`](docs/release/APP_STORE_PREFLIGHT.md)。
