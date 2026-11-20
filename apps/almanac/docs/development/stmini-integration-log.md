# STMini 分批接入记录

本文随 Deynu 工程维护，每批追加实际完成范围及验证结果；未完成的批次不提前登记为已完成。提交身份以 Git 历史为准，签名构建、上传、审核及发布以真实后续运行证据为准。

## 2026-11-16：第一批 foundation（本地验收通过）

来源固定为 `stmini_flutter/main` 的 `b4462f63a33acf6c3fff63f0e67b3713bc00dff8`。完整接入版已另行在本地固定储藏，不随本批作为隐藏资源入包；恢复信息仅保留在本地主控记录。当前 App 专用子集位于 `packages/stmini_flutter`，通过相对 path 依赖，来源和逐文件 SHA256 见该目录 `UPSTREAM.json`。

### 源码计量

| 口径 | 文件 | 物理行 | 字节 |
| --- | ---: | ---: | ---: |
| 完整 main 生产源码分母 | 113 | 20,683 | 823,442 |
| 本批原样生产源码 | 5 | 304 | 13,390 |
| 本批本地阶段 adapter | 3 | 159 | 7,174 |

原样源码占文件数 **4.4248%**、物理行 **1.4698%**、字节 **1.6261%**。分母包括 Dart、Android main Kotlin 和 iOS Swift/Objective-C/header，不包括文档、测试、example、资源和配置。adapter 是本地阶段适配，单列而不冒充整个原 plugin 已接入。35 份语言 JSON、Privacy 声明、许可及构建配置也不用于凑源码比例。比例表示源码范围，不能解释为功能完成度；本批按可执行的自然依赖闭包实施，接受低于原先约 20% 的计划。

### 实际能力及未接范围

- Android 执行原 main 的 `StminiHostConfiguration` 配置与语言解析，依赖 `MiniLink` 中的 `MiniSecurity` 类型和 `WebOrigin`，事件由原样 `StminiRuntimeEvents` 管理；这些 URI/配置类型不包含下载器。
- iOS 执行原 main 的 `STMiniLocalization` 本地语言资源解析与缓存。两平台阶段 adapter 校验真实 Deynu packageName，初始化后可通过 `foundationState` 回读阶段、身份、语言及真实初始化状态。
- App 首帧仍为原 Deynu 页面，随后仅初始化一次；同步/异步失败、重建或卸载均隔离。原日笺数据、存储键/schema、主题、中英界面和隐私入口不变。
- 本批未接入 Mini/WebView 容器、网页桥、包管理、ZIP 解包安装、下载或页面打开。阶段标记为 `foundation`，Mini/Web loading 均为不可用；未接方法返回 `unsupported_capability`，未接参数拒绝，不以空包或成功回调伪装完整功能。没有 Mini 链接、隐藏开关、自动跳转或参考项目业务参数。
- iOS 插件仅依赖 Flutter，保留宿主 iOS 15.0 下限；Android 插件不新增权限、Activity 或 Provider。上游 LICENSE 仍为 TODO 占位，原文保存，不能据此宣称已核实外部分发许可。

### 本批实际验证

- Flutter 3.35.7 / Dart 3.9.2；原 pub.dev 锁仅新增本地插件，离线 `pub get --enforce-lockfile` 通过，未升级既有依赖。
- 格式检查 20 文件零变、静态分析无问题、App 全量 68 项通过。常规之后的初始化专项/fake 8 项通过，8 项已包含在 68 项中；最后 fixture 字段/标题对齐后又定向复核 8 项通过。Dart channel fixture 仅证明参数与解码，不替代原生执行。
- 本批 iOS Simulator/debug 无签名编译通过（Xcode 20.2 秒）。实际插件注册、foundation/localization 符号及语言/Privacy 资源存在；没有完整 Mini/Web/下载模块或其额外第三方框架。该本地构建保留工程版本 1.0.5/build 1，不代表后续商店目标版本。
- 新建专用 iPhone 16 / iOS 18.2 模拟器执行 3 项 native XCTest，全部通过：真实初始化与状态回读、重复稳定、缺能力拒绝、错误身份/参数不初始化。测试结束已删除仅为本批创建的设备，未改动既有设备数据。
- Android Kotlin 插件编译和宿主 debug merged manifest 通过。离线首次缺少原版本 AndroidX 1.9.0 缓存，补齐相同公开依赖后成功，未抬版本。实际包含 8 个基础类型，无 STMini Activity/Provider 或存储权限；宿主 debug INTERNET 与 AndroidX signature receiver 权限保留。直接 Gradle 清单版本默认 1.0/code 1，仅作编译证据，未生成或签名 APK。
- 未执行物理设备验证、Android 原生运行时测试、Mini 打开/下载端到端、签名 IPA/APK、上传或商店审核。本地通过不能替代这些验证。

### 提交与后续

本批本地验证及独立验收已通过；提交身份以 Git 历史为准。签名、上传和送审尚未执行。用户指定本批更新记录为“修复bug”、审核备注不填写；实际商店版本、构建归属及是否存在更高草稿仍须核实，不将文案当作已完成送审的证据。当前主线已有剪贴板复制失败提示修复，是否包含于待提交商店版本须另核实际来源。

后四批的准确依赖闭包和比例待规划，不虚构每天完成量；第五批按当前决定仅本地完整验证，暂不送审。后续每批在本文件追加真实源码、构建与审核运行记录，完整能力接入后的说明由用户另行处理。

## 2026-11-16：首批发布依赖工具一致性修复

签名构建尝试 `43834612213` 使用首批源码 `9955abed7c9aee1dc151907b472fdf54a1915518`、目标版本 1.0.9，在依赖 deployment 阶段失败：runner 全局 CocoaPods 为 1.17.0，已提交 `ios/Podfile.lock` 的生成版本为 1.16.2；差异只在 COCOAPODS 字段。该尝试未产生 IPA、未上传。

固定发布引擎 `b2a2e38df4eac58c35d1bf8b5dc7cc987be467d9` 已支持 Flutter App 目录的 Gemfile/Gemfile.lock：安装锁定 Ruby 工具后执行 `bundle exec pod install --project-directory=ios --deployment`。本次仅为 Deynu 新增 Gemfile 精确固定 CocoaPods 1.16.2，并用实际 Bundler 4.0.23 生成完整工具依赖锁；不手工改 Podfile.lock 尾行、不更新业务 Pods、Dart 依赖、SDK 或基础层源码，也不改共享引擎和发布工作流。

失败 run 的固定 runner image 为 macos-26-arm64；其镜像清单列 Ruby 3.4.12 / Bundler 4.0.23 / CocoaPods 1.17.0（镜像资料，不是该 run 的 `ruby -v` 输出）。工具锁的 BUNDLED WITH 采用实际生成工具 4.0.23，与该 image 一致，避免依赖默认 Bundler 自动切换到旧版。锁包含通用 arm64-darwin 和本机 arm64-darwin-21 平台；实际 Bundler 平台匹配及 gem 的 Ruby 版本要求元数据核对通过，覆盖目标 arm64-darwin-25 / Ruby 3.4.12 的声明要求，但这不等于已在云端执行。

本机 Ruby 3.3.0 + 实际 Bundler 4.0.23 验证：`bundle check` 通过，`bundle exec pod --version` 精确为 1.16.2；启用 frozen lock 后实际执行 deployment 安装通过，共 4 个依赖/4 个 Pods。Gemfile.lock、Podfile.lock 和 pubspec.lock 安装前后逐文件 SHA256 全等。未重新运行未变化的业务全量测试。后续仍需用新提交来源重新执行云端签名构建，核实工具安装与产物；本条不代表新 IPA、上传或送审已完成。

## 2026-11-16：第一批 1.0.9 签名构建、上传及送审进度

本条更新此前条目记录时“尚未签名/上传”的状态。修复来源 `4baa638fbdd4c271885b4c1a5b2a2deca965410f` 的构建运行 `43838615277`（Deynu build #13）实际成功，已生成并上传 1.0.9/build 1，App Store Connect 处理为 VALID。后续若只提交本接入记录，其文档提交与该 IPA 来源分开追溯，不改写已构建源码身份，也不因此重打包。

实际签名包大小为 **19,947,104 字节**，SHA256 为 `59c76ce76c79c8bd4dc76eb4f7dbbc07488364098f40ec67d7921070f5083af2`。独立验包确认 bundle 为 `com.almanac.lite`、arm64、最低 iOS 15.0；基础层实际入包，含 71 条 foundation/localization 符号及 35 份语言资源，未包含完整 Mini/Web/下载容器；`codesign --verify --deep --strict` 实际退出码为 0。这是签名包和模拟器/静态证据，不补充为物理设备或完整 Mini 端到端运行证明。

用户随后将本批商店更新记录明确更正为 en-US **`fix bug`**（小写、单个空格、无句号），覆盖前文历史中文“修复bug”的计划。仅更正此 What's New；审核备注本次不填写，也不要求清空或读取历史值。更新运行 `43842993664`（existing-build #69）已实际 GET 回读英文文案一致。

送审前精确查询 `43843368818`（status #197）及独立门禁确认：版本 1.0.9，version ID `3ae166f9-8599-4e5c-b239-8d40e7a8492c`，附加 build ID `5caa1b9e-43c5-4436-88df-91773f47ad0b` / build 1，状态 VALID，实际 release type 为 AFTER_APPROVAL；What's New 精确为 `fix bug`，无查询错误。正文和 5 张截图与 1.0.8 语义一致，未替换为新媒体。

正式送审运行 `43843986777`（existing-build #70，submit=true，来源仍为上述 `4baa638`）实际成功。提交记录的 `submitted_at` 为 `2026-11-16T09:54:55Z`（北京时间 17:54:55），`review_submitted=true`、`no_op=false`，审核提交 ID 为 `f2a87d82-b0bf-4572-ab2c-38033e636431`，返回状态 WAITING_FOR_REVIEW。同一 1.0.9/version/build 1 复用未变，en-US `fix bug` 再次 GET 回读一致；正式 submission 结果与准备阶段未送审的回执分开记录。最终精确回查运行 `43844328593`（status #198，来源仍为 `4baa638`）成功：`2026-11-16T09:57:11Z` 实际回读同一 App/1.0.9/version/build，状态 WAITING_FOR_REVIEW、release type 为 AFTER_APPROVAL，build 1 为 VALID 且未过期；`2026-11-16T09:57:14Z` 的元数据回读无错误、en-US 文案精确为 `fix bug`。该只读摘要的 `review_submission` 为 null、没有查询错误，不能作为再次确认审核提交 ID 的证据；上述 `f2a87d82-b0bf-4572-ab2c-38033e636431` 仍明确来自 #70 正式提交回执。当前为已提交等待苹果审核，未获批、未发布；自动发布配置不等于已通过审核或已公开。后四批仍待真实依赖规划，第五批仍仅本地验证、暂不送审。


## 2026-11-17：首批发布结果与第二批基础事件/地区资源修复

首批状态查询运行 `43997660036` 在北京时间 09:43:09 实际确认同一 1.0.9/build 1 为 READY_FOR_DISTRIBUTION / DISTRIBUTED / AFTER_APPROVAL，已审核通过并自动发布。本条覆盖前文历史“仍等待审核”，不改变该签名 IPA 的源码身份。

第二批仍以 pinned main `b4462f63a33acf6c3fff63f0e67b3713bc00dff8` 为只读来源，仅改 Deynu 专用副本。新增运行链是两端真实 initialize → 原生 `foundation_initialized` → 共享 Dart channel transport → process 级 startup 白名单内存诊断。事件不触发页面跳转、数据写入或能力开放；Host 卸载重挂保留初始化终态和一个订阅，非共享服务由创建者取消。listen/cancel 控制失败与 envelope/model 错误局部处理，不替换全局 FlutterError handler。

### 真实缺陷及修正

- iOS 旧实际 framework 的 initialize 可复得 pt-BR/pt-PT 选不到现有葡语资源、zh-TW 区域 alias 回落英文；en-US 对照正常。现仅修已有区域资源名及 `_`/`-` 归一，unknown → en → zh-Hans 回退保留，不加语言 setter/持久化或 Deynu UI 语种。
- Android 旧逐字生产事件源在确定性 Handler/Looper 调度中会把取消前排队消息及无 listener 期间事件送给新 listener。现捕获 subscription lease 和顶层 payload 副本，只撤销自身 owner、忽略过期回调；此生产 state 自产嵌套 list 不再修改，不承诺任意可变嵌套 payload 的深快照。该缺陷复现是 JVM 受控调度，不能描述为观察到真实用户事件串用。
- 两端 late-listen 回放当前实例的真实 initialized 状态，消除 MethodChannel/EventChannel 没有跨 channel FIFO 保证的 ready 竞态；未初始化不伪造 ready。Dart 对事件进行严格解码和深冻结，process 服务只保白名单状态和通用问题标记。

### 当前累计来源计量

| 分类 | 文件 | 物理行 | 字节 |
| --- | ---: | ---: | ---: |
| main 生产源码分母 | 113 | 20,683 | 823,442 |
| 仍逐字等上游的生产源 | 3 | 217 | 10,040 |
| 两份修订后的派生源 | 2 | 121 | 4,941 |
| 本地生产 adapter/helper | 5 | 470 | 17,244 |

首批的两份原样源修改后转派生，当前原样比例为 2.6549% 文件 / 1.0492% 行 / 1.2193% 字节；不是集成能力倒退或完成百分比。`UPSTREAM.json` 同时保留原 SHA、新 SHA、修订原因及当前计量。事件契约参考摘录仅 19 行 / 710 字节，不算新增完整原样文件；App startup 消费代码在包外另列，不混入上游比例。35 份语言 JSON、Privacy、许可、测试和配置均不用于凑量。

### 本批验证与交付边界

Flutter 3.35.7 / Dart 3.9.2：format 25 文件零变、analyze clean、三文件定向 25 项、全量 85 项、常规后 fake 25 项通过（25 已含在 85，不相加）。两条 widget fixture 曾因 SDK root-zone Future 与 FakeAsync 清理边界挂起；仅修测试清理为实际异步执行，所有业务断言保留，没有改生产服务来换通过。

iOS 普通 `lib/main.dart` Simulator/debug/no-codesign 构建通过，插件真实注册及新二进制存在，35 语言 JSON/Privacy 资源保留，没有完整 Mini/Web/下载模块或额外框架。新专用 iPhone 16 / iOS 18.2 模拟器 6 项 native XCTest 全过，覆盖初始化、9 个地区/别名与回退、listen 前后时序/取消后当前状态回放、实例隔离和原 unsupported/参数拒绝。另用 test-only Flutter target 实际附着运行，完整 JSON 回执证实原生 init 与 startup eventCount=1、passed=true、disposed=true、无诊断 issue；这是平台 channel 路径，不等同原 App UI 或物理设备 E2E。普通入口已重建恢复，所有自建 iOS 设备均已删除，既有设备不动。首次直接 simctl launch 未收到完整输出，以及附着日志长行截断的对照都不作为通过依据；最后已压缩重复测试诊断并完整解析。

Android 8 项生产事件源的受控 JVM 调度回归、真实插件 Kotlin 编译以及本批 debug APK 构建通过。Android33 / Android 13 任务独立 AVD 已实际运行同一 test-only target，完整 JSON 回执确认 native initialized=true、startup eventCount=1、passed=true、disposed=true、lastIssue=null。所有 adb 指令显式指向该任务 serial；未改系统镜像或既有 AVD，结束只退出本任务模拟器并清理其独立用户目录，未停止全局 adb。首次启动因本机 emulator 31.3.13 不支持可选的 no-metrics 参数而失败，移除该参数后新任务 AVD 成功；不把首次失败说成 OS 通过。之后普通 lib/main.dart debug APK 已重建恢复，真实宿主 merged manifest 保持 min24/target36、原 INTERNET 与 AndroidX receiver 权限、无 STMini Activity/Provider。OS 回执仅证明真实 channel 路径，8 项所有权时序仍是受控 JVM 测试，不声称每个时序都在 OS 重演。Gemfile.lock、Podfile.lock、pubspec.lock、原首页入口与数据/主题/双语/隐私实现保持原字节。本批未增加 Mini/Web/下载/安装、URL、隐藏开关、自动打开、宿主权限或组件。

当前本地开发验证完成，待独立最终 Review，尚未提交或推送；本批尚未签名 IPA、上传、创建商店版本或送审。下一版本只作候选，由发布阶段 fresh 核库存决定；公开更新说明仍为 en-US `fix bug`，依据是本批实际新修复，不能重复借用已上线剪贴板修复。审核备注本次不填，不清历史。第3–5批仍按真实自然依赖和能力披露边界分别冻结，第5批仅本地完整验证不送审。


可复跑的 Android 受控调度测试源保存在 `packages/stmini_flutter/test_support/jvm`。在插件目录，用 Kotlin 2.1 / JDK 21 将 `test_support/jvm/AndroidOs.kt`、生产 `android/src/main/kotlin/com/fsst/stmini_flutter/StminiRuntimeEvents.kt` 与 `test_support/jvm/StminiRuntimeEventsCases.kt` 一起编译后运行其 main；stub 仅替代测试中的 Handler/Looper，不进入 Android main 编译或发行包。真实 Flutter channel target 位于 `test/platform/stmini_native_channel_main.dart`，仅显式测试构建使用；普通 `lib/main.dart` 无引用，不添加 integration_test 依赖或测试开关。


## 2026-11-17：第二批 1.0.10 签名构建、正式送审与最终回查

本条覆盖前文第二批本地验证时“待独立 Review、尚未提交/签名/送审”的历史状态。独立最终源码与本地 QA、跨端契约核对通过后，18 个文件精确提交并正常推送为 `193fc266eaa3277f1d6f69031beef26ecdffd4c5`。下列签名包、构建及商店动作均来自该源码；后续若仅追加本工程记录，其文档提交与此 IPA 来源分别追溯，不因此重新构建或送审。

Deynu iOS Release #14 / `44008959464` 实际成功，来源 main / `193fc266eaa3277f1d6f69031beef26ecdffd4c5`，生成并上传 **1.0.10/build 1**。实际 IPA 为 **19,958,267 字节**，SHA256 为 `95bc5be1721be4ca7d4284fe41832e3bdf26f822e25e3d658af3ce308e3d9e8c`。独立实际验包确认 `com.almanac.lite`、arm64、最低 iOS 15.0，35 语言资源及 Privacy 逐字等源；Release 原生与 Dart AOT 中存在事件 transport、严格模型、startup 实际消费回调及地区解析标记，没有 test-only sentinel、完整 Mini/Web/下载容器或多余框架。`codesign --verify --deep --strict` 在可访问系统公共信任的环境中退出 0；该静态签名制品审核不等同物理设备或签名 App 的运行证明。

送审前准确查询 #203 / `44010732469` 确认 App `6824457290`，版本 `1.0.10` / `11a30103-f973-435e-bead-9d2587ac281b`，附加 build `321bc11e-528e-4989-a64c-89cfb02a8e0d` / build 1 为 VALID 且未过期，release type 为 AFTER_APPROVAL。独立审核确认原正文与 5 张截图和 1.0.9 语义一致，en-US What's New 精确为 **`fix bug`**。本次只使用实际第二批 SDK 修复，不重复借用已上线的剪贴板修复；审核备注此次不填写，不读取或清空历史值。

正式送审 #72 / `44011185245`（来源仍为 `193fc266`）实际成功。真实提交回执时间 `2026-11-17T03:35:09Z`（北京时间 **11:35:09**），`review_submitted=true`、`no_op=false`，审核提交 ID 为 `8c7afe2f-2b4a-4d7e-bbbc-625fb353f917`，返回提交状态 WAITING_FOR_REVIEW；不是只准备草稿或复用旧版提交。

最终只读回查 #204 / `44011368663`（同来源）成功：`2026-11-17T03:36:40Z`（北京时间 **11:36:40**）准确回读同一 App、1.0.10、version ID 与 build ID，状态 **WAITING_FOR_REVIEW / QUEUED_FOR_REVIEW / AFTER_APPROVAL**，build 1 仍 VALID、未过期；`03:36:44Z` 元数据 errors 为空，en-US 文案仍精确 `fix bug`。该只读摘要的 `review_submission` 为 null、query error 为 null，不能作为再次核实 submission ID 的证据，也不表示撤回；上述真实 submission ID 明确来自 #72 正式回执。

当前第二批已正式送审、等待苹果审核，**尚未获批、尚未发布**；自动发布配置不代表已公开。原首页、数据、主题/中英界面和隐私入口保持；完整接入储藏仍隔离，未恢复或作为隐藏资产混入本批。后续批次按各自真实范围与披露门禁推进，第五批仍仅本地完整验证、暂不送审。


## 2026-11-18：第三批本地只读库存与来源校验修正（本地验证进行中）

基线 main/de25bfc47fe09a0abc9870fe5f1171ee3ff2390f，已保留同期 photoreport 与根 README 的并行提交；本批仅改 Deynu 专用副本。来源继续固定 b4462f63a33acf6c3fff63f0e67b3713bc00dff8，完整接入 stash 不恢复。

新增真正可调用的本地只读库存链：原生约定目录 → bounded manifest/installed record 校验 → 严格不可变五字段 Dart metadata → 初始化成功后的 startup 一次真实 SDK 查询。合法空库存来自真实读根目录，不创建 STMini 目录；查询失败与合法 count 0 分开。后台串行且单飞，原生 4 秒协作式截止与取消检查、startup 5 秒终态超时；detach/迟到结果不二次交付或影响新查询。内存诊断只留状态和数量，不留包路径、名字或链接，不写宿主数据。

这次显式提取原 Android MiniPackageStore 与 iOS STWebResourceManager 中的只读数据/校验片段，不复制其网络、ZIP、安装、路由或渲染单体。两端统一顶层 List 与 manifest verified version，修正 pinned iOS Map envelope/缺版本的来源缺陷；每次重验、逐层拒绝 symlink/非普通文件，补上旧 iOS 空路径段与正缓存不重新验证等缺口。来源缺陷在接入前修正，不能称线上 Deynu 既有库存用户故障。新本地只读 metadata 能力在此如实记录，无新增远程加载或内容执行。

阶段字段仅 miniId、miniName、version、entry、icon，不含完整宿主的 URL/launchLink；icon 可空，ID 是小写 ASCII，版本为 1–8 段且每段 1–9 位数字，仅精确字符串一致，不接比较器。name/path/channel 长度均以 UTF-16 code units 计；JSON 每份 64 KiB、最多 256 个非隐藏候选，路径逐段锚定于私有根。channel 若存在须与 record 一致，Android 历史 record 未携带而 manifest 携带 channel 的包在此严格阶段只读拒绝。它不是所有历史包兼容保证，不执行内容，也不称密码学真实性或敌对并发修改的原子快照。

累计原样源仍 3 文件/217 行/10,040 字节；derived 4 文件/414 行/19,745 字节；本地生产 adapter/helper 6 文件/702 行/26,520 字节；App startup 187 行/6,205 字节单列。原分母 113/20,683/823,442 不变，原样比例仍 2.6549%/1.0492%/1.2193%，不据此声称功能百分比。新增库存参考片段与来源/集成 SHA 在 UPSTREAM.json 分别记录，不整份计入两大单体。

常规 format 28 文件/0、analyze clean、全量 Flutter 99 项通过后追加库存/wire/生命周期 fake 定向 39 项通过；两者有重叠，不合计为 138 项。Android 最后生产插件 Kotlin compile 通过。iOS 首轮暴露插件 target iOS 13.0 与 FileHandle 新 API 的兼容问题，已改为有界 InputStream，不改最低版本或锁；新一轮普通 Simulator build 与真实 XCTest 15 项（原 6 项及本批 9 个测试方法，内部参数化多场景）通过，真实 Flutter-native inventory channel 完整 JSON passed=true/disposed=true、available/count0/unsupportedRejected=true，根目录前后均不存在；普通 main 已重建且专用模拟器已删除。Android OS fixtures/channel 及最终独立 QA 仍待完成，本条后续补结果；当前未提交、签名、上传或送审。

默认原首页、日笺数据键/schema、主题/中英界面与隐私入口实现保持原样；不加 Mini 链接/自动打开/隐藏开关，不增加权限或宿主组件。第五批仍仅本地验证，实际签名 IPA/商店状态另设门禁，不以模拟器结果代替。


第三批范围后续更新：用户已明确要求本次再加入 Mini 本地页面渲染。上述记录只描述当前已实现库存切片，整个第三批尚未冻结或完成；旧只读范围不能直接送审。渲染依赖、真实执行边界及验证将经新范围预核后继续记录在本文件，默认原首页及无自动/隐藏入口、无下载安装不变量保留。

## 2026-11-18：第三批只读库存与显式本地 Mini renderer

第三批仍只改 Deynu 专用副本，固定来源为 `stmini_flutter/main` 的 `b4462f63a33acf6c3fff63f0e67b3713bc00dff8`。库存查询统一为严格的五字段 List，每次复核 manifest/installed record、绑定身份与锚定普通文件，真实空目录不创建文件；来源 iOS Map/缺 version、路径和正向缓存缺口在移植前修正，不声称原线上 Deynu 已发生库存故障。生产 startup 初始化后只查询一次，只保内存状态/count，不打开 Mini 页面。

本批新增显式 `StminiLocalView(miniId, version)`、双端真实 PlatformView factory 与受限本地 WebView。每实例 controller 仅接受无参 state/reload/goBack/close；ready 只表示当前受验本地主文档 commit，实际 DOM、资源和屏幕另验。Android 使用精确本包 HTTPS origin、`self` CSP 及禁网设置，iOS 使用 nonPersistent WKWebView、精确本 id scheme handler 与 `stmini:` CSP；后者不冒充 CSP 精确 host。逐资源身份、严格单次 UTF-8 路径解码、无链接普通文件、4 reader/8MiB/4 秒协作截止与零等待溢出拒绝均有边界；这不是整个 WebView 的内存限额。

跨端 Unicode entry/channel 使用 UTF-16 逐字一致性；当前资源发现 version/entry 身份失效会使当前 generation failed/stop，普通缺图只拒绝该资源。跨文档/back/reload 创建新 WebView，以本包 history 和 generation 隔离旧事件；fragment 不制造 loading/8 秒超时。单 identity worker、取消/latest pending、当前 navigation/phase 校验与迟到回执隔离修正了本批独立预审发现。完整 openMini/openWeb、下载/安装、任意 URL/file/evaluateJS、原生 JSBridge、账号注入仍未接入；capability 显式区分 local_renderer 与完整 loading。原首页、存储/主题/双语/隐私及生产权限/组件保持原范围，无 Mini URL、隐藏开关或自动打开。

### 累计来源计量

| 分类 | 文件 | 物理行 | 字节 |
| --- | ---: | ---: | ---: |
| main 生产源码分母 | 113 | 20,683 | 823,442 |
| 逐字原样生产源 | 3 | 217 | 10,040 |
| 派生生产源 | 8 | 1,270 | 66,639 |
| 本地生产 adapter/helper | 7 | 1,188 | 42,342 |
| App startup 消费代码（另列） | 1 | 187 | 6,205 |

40 份逐字来源文件包括上述 3 份代码、35 份语言 JSON、Privacy 与 LICENSE。renderer 的九份选段共 514 行/22,593 字节只作参考，不计完整原样移植或功能完成比例；`UPSTREAM.json` 的逐项来源/集成 hash、README 与本表已复核。没有为 20%/60% 比例携带未使用容器，LICENSE 仍保留来源 TODO 原文，不表示已核实外部分发许可。

### 本地验证与限制

Dart 生产实现冻结后，focus 1 项、全量 113 项、常规后 fake 53 项、analyze 与 format 31 文件通过；53 已包含于 113，不相加。后续只修 test-only Engine 宿主与日志回执，新增真实 Flutter 背景/header、首帧和布局诊断，静态分析及实际 target 编译运行通过，原返回/两轮重载/根 history/重复关闭断言保留。帧回执不代替截图；外部安装的 Engine fixture 将自动二页定时改为 20 秒，最终观察 15 秒，源码 fixture 不变，未加入产品资产或接口。

iOS v5 实际 XCTest 23/0，真实本地 JS 生成指定 DOM、CSS、1px 图片、按钮、二页/back/reload/fragment、Unicode/身份失效、资源预算/取消、真实 8 秒 watchdog 与迟到释放/reload 均通过；真实 Preferences→App 往返、受控 renderer-loss delegate/reload 有证据。WK snapshot 与真实 FlutterEngine preterminal 图分别可见，不能把前者当物理机或整个原产品 UI E2E。mediaDevices 为 unavailable，不冒充系统权限弹窗已拒绝。后续当前 HC Dart 的普通 `lib/main.dart` iOS Simulator/debug/no-codesign 单次编译通过，35 语言/Privacy 逐字、原生类/WebKit 链接和普通 kernel 无测试 sentinel 均复核；debug Info 为 1.0.5/build 1，不是签名发行候选身份。

Android v6 真实 OS 执行 108 项库存及 42 项 Looper/plugin 场景，并以生产 WebView 验 DOM/JS/CSS/image/button、列明安全尝试、Unicode/身份失效、实际 Activity 前后台同 view、受控 renderer loss、真实 8 秒 watchdog/late/reload 与资源边界。后续六份 native 输入 hash 未变，明确复用该证据，不声称每轮重跑。早期 Engine 控制链虽通过但截图全黑，始终未当作可见通过；加入显式 hybrid composition 和唤醒操作仍未证明能修复黑屏。默认 window/activity/surface 取证显示前台焦点、非零布局/真实 buffer、无 secure 截屏标志，仍不能单凭它们证明 paint。

最终 Android 13/API33 任务模拟器 v14 使用本机 `host` GPU，在同一 APK 上，生产默认 Impeller/OpenGLES 与仅测试 intent 的 Skia 两段均取得完整控制回执和 terminal 前真实屏幕：Flutter header、本地 JS 标题、CSS、按钮、二页链接都可见；同设备普通 main 两图也可见。此前 `swiftshader_indirect` 环境的黑图及测试签名/日志截断失败保留，结论仅限已观测的 GPU 环境差异，不宣称已定某个驱动内部根因、HC 或休眠是唯一原因。没有为测试修改生产 renderer backend/manifest。普通 main 已重建恢复，fixture 根清、本任务 AVD/私有目录已删除，既有设备与全局 adb 未改。

双端列明 12 条本地 JS 网络尝试有真实终态、loopback 正控 1→攻击 0、无远程代码执行；这不证明所有浏览器通道封闭，WebRTC/UDP/DNS 与物理设备未覆盖。当前是本地开发验证完成，待最终冻结后的独立 QA/跨端核对，尚无第三批提交、推送、签名 IPA、上传或送审；新增内容执行能力的发行说明与审核访问仍由独立发行门禁决定，不因本地通过直接放行。第 5 批仍仅本地。


## 2026-11-18：第三批 1.0.11 签名上传（验包通过，发行决定待完成）

本条更新前文第三批本地验证阶段“尚未提交/签名/上传”的历史状态。冻结的本地只读库存与显式 renderer 已经独立最终 QA、跨端核对通过，P1=0/P2=0，38 个路径精确中文提交并普通推送为 `4983b26eed8bbfc312491e5d293a7b310717a3b6`，父提交为 `de25bfc47fe09a0abc9870fe5f1171ee3ff2390f`。以下签名 IPA 的源码身份固定为 `4983b26`；本条后续纯文档提交与该身份分开，不据文档提交重新构建、上传或送审。

唯一 Deynu iOS Release #15 / `44235836404` / job `134571642683` 在 `2026-11-18T04:25:40Z` 的最终只读回查确认为 **completed/success**，source head 为 `4983b26`，run updated_at 为 `04:24:05Z`；构建与上传步骤均成功。签名制品 artifact `14398140124` 的实际 IPA 为 **1.0.11/build 1**、**20,123,926 字节**，SHA256 为 `151b0ddde7f1cabf15a850165572fc5b3bb31a6a66bc11124ace585e72c262e4`；build-metadata 同时记录 source `4983b26eed8bbfc312491e5d293a7b310717a3b6`、run attempt 1。实际下载的同一 IPA 已经独立静态制品与上传身份审核通过，P1=0/P2=0：Info 为 com.almanac.lite/1.0.11+1、最低 iOS 15.0；六个实际 Mach-O 均为 arm64，无模拟器 slice。App.framework/App 有四个 VM/isolate data/instruction snapshot 符号且无 kernel_blob，属于设备 Release AOT。原生插件实际包含 LocalMiniViewFactory、LocalMiniView、LocalMiniResource、LocalPackageInventory，Runner 链接插件、插件链接系统 WebKit；工厂注册链与冻结源码一致。35 语言资源和 Privacy 逐字等源码 `4983b26`，实际包中没有测试 fixture、test target sentinel 或测试 kernel。

AOT 可达范围另行分层：实际检索保留 StminiStartup、StminiPackage、installedPackages 与 foundation_initialized；未检出未消费的 StminiLocalView/Controller/channel 及部分内存诊断字符串。普通 main/startup 只消费初始化、事件与库存，并未创建 renderer Widget/controller 或产品 Mini 页面入口；Release 优化/树摇与该检索结果一致属于推断，字符串缺失不是穷尽调用图证明。原生 renderer 已编入并注册，不等于签名 IPA 新增可达 Mini UI；此前 source SDK 与 test target 的真实双端页面执行证据不能改称这次签名 IPA 已运行新页面。

严格 deep 签名验证初轮受限环境的 CSSMERR_TP_NOT_TRUSTED、entitlement display 的 invalid blob/no XML 警告均保留。独立解析实际签名 XML slot 有效；获得公共系统安全服务访问后，strict verify 与 entitlement display 均实际退出 0，XML 与实际 slot 一致，application bundle/team 前缀匹配、get-task-allow=false、beta-reports-active=true，不再有 invalid blob 警告，仅保留旧冒号输出语法的 deprecated 提示。该复核不改信任或提取 profile/证书/key；初始受限读行为不改写成签名制品缺陷。审核结论只覆盖静态 arm64/AOT/native/resources/签名与上传身份，没有执行签名 App 或物理机运行，也不由此自动批准商店写入。

上传回执 artifact `14397184814` 在 `2026-11-18T04:23:52Z`（北京时间 **12:23:52**）确认 App `6824457290` / `com.almanac.lite`、1.0.11/build 1、build ID `130d4983-6020-41a3-a25a-f45dce28cfee`，`upload_accepted=true`、上传状态 **COMPLETE**、processing state **VALID**，上传 errors 为空。回执同时含非阻断此次 VALID 的 warning **90725**：该包使用 iOS 26.4 SDK，提示自 2027 年 4 月起上传要求 iOS 27 SDK 或更新版本。保留该后续 SDK 要求提示，不将本次警告改写成上传失败或全无警告。

当前签名工作流、实际 IPA 独立静态验包与上传已完成；公开说明及审核说明的新具体方案仍待用户决定。拟案 `Local rendering infrastructure improvements.` 及内部 local-only HTML/CSS/JavaScript 执行边界说明尚未获得批准，不记录为已经改写；原首页和 daily reflection/verse/leaf/folio 用途不变，无产品 Mini 页面、远程激活、下载代码或产品测试 fixture。本阶段没有创建候选 App Store 版本、绑定该 build 或正式送审，也未获批或上线。此前两批已公开与本候选状态分开；第三批仍未完成发行，第五批仅本地限制保持。


## 2026-11-18：第三批 1.0.11 已正式送审（等待审核，尚未获批或上线）

本条更新前文“发行决定待完成、未创建店版/绑定/正式送审”的阶段状态。用户最新明确“暂不改文案，先送审，最后一批改文案”：本次公开更新说明保持精确 en-US `fix bug`，不采用此前拟案，不新增审核备注，也不清除历史备注；第五批仍仅本地。独立发行门禁审核已通过，P1=0/P2=0。原首页与 daily reflection/verse/leaf/folio 用途及前文原生编入/API、AOT 未消费 renderer、没有产品 Mini 入口的事实边界不变，本条不新增线上 Bug 已发生的声明。

制品来源继续固定为源码 `4983b26eed8bbfc312491e5d293a7b310717a3b6`，实际签名 IPA 仍是 1.0.11/build 1、20,123,926 字节、SHA256 `151b0ddde7f1cabf15a850165572fc5b3bb31a6a66bc11124ace585e72c262e4`。前次工程日志提交 `6dde505cca53dc18171f8135808a94ecfb77326c`、后续审核备注工具提交 `c8e99a60727d0454fb4239a86d699ccfae97dcc6`，以及包含本条的后续纯文档提交均独立追溯，不能替换签名源码身份。没有为文档或工具重新构建、签名或上传该 IPA；审核备注工具本轮运行数为 0，未执行 apply。

现有 build 发行准备 #73 / `44247492940` 成功，创建 App Store version `bac3b2d9-28c8-4135-b8c0-625fa9e92f0f` 并绑定原 build `130d4983-6020-41a3-a25a-f45dce28cfee`，设置审核通过后自动发布；当时 `review_submitted=false`，只作为准备，不当作送审。独立门禁核对精确 App `6824457290` / `com.almanac.lite`、1.0.11/build 1、`AFTER_APPROVAL`、同一 VALID 且未过期 build，以及 en-US `fix bug` 已写入并读回。正文与五个媒体资产的有效内容及顺序对照原 1.0.10 保持，新版本对象 ID 可不同；正文/媒体更新开关均为 false。备注保持的证据是已核固定脚本分支及本轮无写入/无清除路径，未直接读取或逐字比较私密历史备注值。

随后仅一次正式送审：existing-build 发行 #74 / `44248853130`，实际回执 artifact `14402797855`。`2026-11-18T06:06:38Z`（北京时间 **14:06:38**）的 `asc-review-submission` 记录 `review_submitted=true`、`no_op=false`，submission ID `b0b92422-239b-4bfb-aefa-0943d96ac06d`、状态 `WAITING_FOR_REVIEW`；身份仍为上述 App、version 和 build。此处依据真实提交回执，不将工作流派发成功或准备完成当作已经送审。

最终只读回查 #216 / `44249151572` / artifact `14403505420` 已 completed/success：`2026-11-18T06:09:01Z` 状态与 `06:09:04Z` metadata 均对应同一 App、1.0.11/build 1、version `bac3b2d9-28c8-4135-b8c0-625fa9e92f0f`、build `130d4983-6020-41a3-a25a-f45dce28cfee`，版本 **WAITING_FOR_REVIEW**、release type **AFTER_APPROVAL**，build **VALID**、`expired=false`，en-US 更新说明精确为 `fix bug`，metadata errors 为空。该只读状态中的 review-submission relationship 为 null，仅表示此关系查询未给出对象，不推翻前述真实提交回执，不据此重复提交。

第三批当前结论是**已正式送审、等待审核**，尚未获批或公开上线；`AFTER_APPROVAL` 表示审核通过后的发布策略，不是现在已经发布。前述 90725 未来 SDK 要求仍保留为警告，当前 build VALID。此次只收集真实发行回执与精确终读，没有重跑 SDK/设备测试，也没有改变此前签名制品和本地验证的已说明限制。


## 2026-11-19：第四批完整容器与 Bridge 接入（当前验证与独立审核进行中）

本条更新第三批 foundation/local-renderer 的能力现状，旧条目保留为当时的范围与发行证据。固定 main 来源仍为 `b4462f63a33acf6c3fff63f0e67b3713bc00dff8`；本次从固定 Git 来源迁入完整 Mini runtime、MiniLink、版本/下载/ZIP 原子安装、栈/保活/overlay 与 OnlineWeb 自然闭包，并真实接上 Dart SDK 和原生 CMS Bridge。未恢复保护 stash，也未复制主控端过程文档到打包机。

双端初始化状态现在为真实 mini runtime、Mini/Web 能力 true。普通 startup 只初始化、消费状态并读严格五字段库存，Deynu 原首页无 Mini URL、自动/隐藏/远程激活入口；旧 LocalView、严格库存、事件所有权及地区 alias 保留。完整 dispatcher 的 provider 能力有宿主前提，未提供按合同失败；Deynu 没有账号/交易 provider。Mini 与 HTTPS origin 使用原生主体 SHA256 独立存储域；异步回包和 UI/Photos 等副作用沿用最初 document generation/URL，写入前重验。完整 iOS WK 绑定初始 id/version/entry；Android 保留本地域非法资源拒绝而不回退网络。

独立部分预审发现两项 P2：minSupport-only 绕过运行下限与 Android self-update 可降级。本次五个生产文件窄修已落盘，当前执行门槛为 `minSupportVersion ?? currentVersion`，下载同时守两个版本声明，安装提交前重读磁盘、低版不得覆盖、同版 kept/强同版可冷重载，Android 只有 changed 发安装事件；iOS kept 补充 launchLink 时保留 Home 注册表通知。生产冻结后仅测试环境适配，不以编译通过或实现者完成替代 P2 独立关闭；完整余审仍待结论。

当前 P2 Android Kotlin compile exit0/10.73s、iOS 普通 Simulator Debug exit0/15.80s；后续真实 JVM 首轮 92 项有 5 失败，iOS native 首轮31项有1失败，均已保留原始失败后窄修测试并复测。iOS 首轮实际 ZIP/min-only cold/keepalive 已过，失败回退测试未实际拦截下载，不记为通过；普通 target 恢复0/22.41s且私有模拟器已删除。报告 writer 真实 IO 3项再次通过0/2.01s。旧完整 SDK 报告采集的日志截断、Android路径误取、iOS重装container换代失败仍是失败；当前按显式私有目录、nonce、probe/reader ack 和安装后 container 采集，尚待当前双端整轮实际结果。

HXWRefresh1.1.0、Masonry1.1.0、SDWebImage5.21.7、Toast-Swift5.1.1、ZIPFoundation0.9.20 已解析；iOS仍15.0，Photos add描述只为显式save调用。Android宿主移除宽存储权限，原生组件须以最终合并manifest/APK核验，旧pre-P2发行制品不得代替当前修复后的Release。真实TLS/生产Mini/物理设备/账号交易/系统相册写入或分享发送未测；模拟transport不冒充真实HTTPS。

来源规模按固定 source path+line 真实去重、派生改行不计，且须绑定当前普通 Release source SHA；iOS与Android各自归属制品。前三批 known byte-equal同path子集与跨path派生unknown分列，不把额外reference扣重差额1048当成前三批全部规模或5.1%。当前P2最终来源量/资格待受影响Release重算，旧pre-P2的13707和12659是两个不可相加下界。完整独立QA/cross、精确中文提交及普通push尚未完成；实际签名IPA、商店内容/送审由PM独立发行门禁处理，第五批仅本地完整整体验证/补缺。


### 当前平台权限能力说明

Android minSdk24，插件虽保留来源 `WRITE_EXTERNAL_STORAGE maxSdkVersion=28`，Deynu 宿主显式 remove READ/WRITE。因此 API24–28 的 saveAlbum 真实实现会进入权限请求并以无权限失败，不能把 API33 模拟器或 MediaStore helper 测试写成旧系统相册保存成功；API29+ 使用 scoped MediaStore，实际系统写入仍未测。本批保持宿主无外存读写权限，未因完整 Bridge 入口增加旧系统宽写授权；此差异随当前交接与独立审核明列。iOS Photos add 仍仅显式保存调用的权限描述，不等于已验证真实相册保存。


### 当前完整 iOS 运行验证发现的析构缺口

本轮完整原生 XCTest 实际为37项中34通过、3失败，完整 SDK 测试尚未进入。一个真实缺陷是 Mini 根控制器在 UIKit 尚未加载 view 时即释放，其析构将空 WebView 当成必需值使用导致崩溃；这不是已证实的线上 Deynu 用户故障，也不能仅由测试强制加载页面掩盖。崩溃重启后的下一测试遇到私有 fixture 残留；会话断言另需区分测试主动关闭导致的正常 epoch/清理与随后排队的旧副作用。失败分层保存，当前仍待最小修复、完整复测及独立关闭。普通主入口构建已经恢复成功，本任务私有模拟器已清理；不据此前编译通过宣称本轮原生或 SDK 通过。


### 第四批当前源码复测与来源资格

根控制器析构改为只捕获可选 WebView 做原生清理，移除不必要异步 JavaScript；未加载 view 的真实构造/释放、取消未呈现导航和已加载重复清理均有回归。新增已加载回归曾误将 UIKit 释放期间的清理次数固定为一次而失败：实际 root 清理后 removeFromSuperview 又触发 willMove(toSuperview:nil) 的合法幂等清理。该轮40项39通过、1测试断言失败保留；修正只约束显式两次清理精确失效、真实对象释放/委托清除及释放确有失效，不盲改固定次数，也不改变产品清理或安全门禁，测试标记改为中性完成，正式 XCTest 结果决定通过。

当前冻结后的完整 iOS 原生测试实际40/40通过、0失败、0跳过；完整 SDK 两个 Mini 各17项检查通过、closedBoth=true，iframe 的原生对象可用且实际投递后由 native gate 拒绝。完整1443字节 nonce 报告SHA256为 `7c58c651bc00bc5e09674587f5311cb86d6e507a7eab054b98c1486793c9b455`；CMS appHide/appShow仅A实际观测，普通主入口恢复构建成功且任务私有模拟器已删除。Android当前 JVM 92/0/0skip，完整SDK A/B各17项、closedBoth=true，CMS仅B实际观测；原生矩阵按相同生产/测试/依赖锁逐SHA复用已执行结果，明确没有再执行一遍。旧SDK B超时与早期编译/传输失败不回写成功；B生命周期准备时机修正只在测试runner，不修改产品前台/关闭语义。

受影响普通 iOS设备 Release构建退出0，当前双端Release全部模块输入与三锁保持；本地原生framework为2,557,200字节、SHA256 `21a849efb5d8b0ebbbc421d4f648860480e6100a016a700823eea2650d50d668`，Runner动态加载、11个主要原生类型符号及STMini资源均在。Android APK为17,538,362字节、SHA256 `74037c54af7739fd683d2b46890007b96008e342b92fe08bc02922c0dde0f495`，合并及最终manifest没有宽存储权限，Mini组件non-exported。R8映射112类中检出103个DEX描述符，不能据此声称全部原始类或每行机器码均保留。普通制品没有测试fixture；iOS最低15.0、Photos add描述有、camera/microphone描述无。这里是无签名本地App/framework，不是签名IPA。

正式 `UPSTREAM.json` / `SOURCE_MAP.json` 已按当前源码、普通Release输入/原生注册链接及真实受控消费者重新生成，保留前三批历史。当前准入来源C=13,514行，额外扣除所有此前引用范围后的第四批保守新增下界12,467行，达到10,342门槛；两者不可相加。平台分别为iOS当前8,562/新增下界8,011、Android当前4,952/新增下界4,456，各自只归属本地unsigned iOS App/framework和Android APK。固定20683分母仍是Android实现5133+iOS实现14981+headers336+sharedDart233，Android行不归入iOSIPA。已知前三批同path byte-equal子集P=320，当前保留317、移出3、相对已知P的新行N=13,197，317+13,197=13,514及320−3+13,197=13,514成立；P不是前三批全部来源量，跨path派生与等价改行未知，额外reference扣重下界不参与该加法。旧pre-P2的13707/12659仅历史，不沿用为当前资格或功能比例。

本批普通首页仍为原Deynu，初始化/状态/严格库存以外没有自动或远程Mini入口，账号交易provider未注入；系统真实相册写入、分享发送、真实TLS/线上Mini、物理设备仍未由本轮获得验证。后续签名IPA、CI/商店披露与发行状态单独记录，第五批仅本地完整整体验证与补缺。


最终 Dart 格式检查36文件/0、静态分析无问题、全量119项通过；全量后五文件fake回归50项通过，是重叠子集，不相加，也不沿用旧59项数字。57份Dart/fixture输入前后逐SHA一致。

旧pre-P2的13,707到当前13,514减少193条来源资格，是累计P2-01至P2-06在九份生产文件中的本地安全修复改变了逐字匹配来源span，并非P6单独删除193行，也不是来源资格过滤规则缩放：本轮candidate/module exclusion/Release排除/资格状态均未变，改为本地等价实现的行依旧不给来源信用。九文件来源行差额依次为Android MiniPackageStore −12、Container −40；iOS Plugin −40、ResourceManager −13、ApiManager −11、Router −4、InstanceManager −19、WebView −12、根控制器累计 −42，总计−193。P6单独逆向重建旧根控制器的内存字节并与当时冻结SHA严格一致后重算，来源资格仅从1,992到1,986、减少6行；没有恢复或写入旧源码。对应保守新增下界从12,659到12,467减少192行，差1来自此前引用重叠区，仍不是前三批全部规模。


## 2026-11-19：第四批签名上传后的用途声明修复

完整容器/Bridge代码 `aabf8fb62f4617865c98825d6317829298ee125f` 的本地独立QA/cross通过和Git交付保持真实。随后签名上传run44462331461产出1.0.12/build1，上传被接收，但App Store Connect的build-upload处理实际FAILED，错误90683指出Runner.app缺NSCameraUsageDescription，asc_build_id为空；不是已成功处理的build，也没有据此送审。实际旧IPA为22,300,427字节、SHA256 `e666b88c6ed4fc7a3bfbbebffa97f5019b37f6aa27d8f7af20d70f109f95ea15`，只作该失败的静态诊断，不复用发行。90725关于未来2027年4月SDK要求仅警告，本轮不升级SDK。

真实签名framework保留AVCaptureDevice/Input/Session与video类型、PHPhotoLibrary/PHAssetChangeRequest、UIImagePickerController引用。公开SDK扫描类的调用链是viewDidLoad→startScan→视频输入/session；其openPhotoAlbum→普通Photos授权→photoLibrary picker→选中图像QR识别。Deynu启动和实际宿主调用链没有构造/打开该扫描器，未新增扫描页面或自动权限请求；但SDK未被产品调用不免除二进制所引用保护API的用途声明。已有saveImageToPhotosAlbum路径继续使用add-only授权，该键不能代替扫描库普通相册读取用途。扫描SDK源与实包均无audio/AVAudio引用，不凭弱CoreLocation overlay或单纯库名增加麦克风、定位或其他purpose。

本次只补宿主Camera与Photo Library Read两key，保留Photo Add及所有原Info值；新增en/zh-Hans InfoPlist.strings各三个用途，用最小variantgroup/Runner资源引用接入。developmentRegion仍en，原Base和首页Dart locale逻辑、日笺数据/隐私页面/原首页入口保持。Camera英文说明仅在主动打开扫描器时用于二维码扫描，Photo Read说明在扫描器中识别用户选择照片的二维码，中文同义；没有把Deynu描述为已经有拍照/扫描入口，也不以声明触发访问。

当前普通无签名iOS Release实际构建退出0，包内Info三key与en/zh-Hans编译后的InfoPlist.strings逐值匹配，最低15.0、名称Deynu、不含Microphone key；原生framework仍2,557,200字节/SHA256 `21a849efb5d8b0ebbbc421d4f648860480e6100a016a700823eea2650d50d668`，Android APK仍`74037c54…`，依赖锁和原生/Dart/测试源码精确未变。旧iOS40/0、Dart119及后置五文件50、AndroidJVM92/0/native矩阵与双端A/B各17项SDK证据明确按SHA复用not_reexecuted，本次不机械重跑。新Info/project/语言资源已经当前普通Release实输入及包内值验证，不能沿用旧缺key的包装结论。

UPSTREAM/SOURCE_MAP重新绑定当前宿主声明、普通Release与明确的runtime复用边界；来源C=13,514、额外引用扣重新增下界12,467不变。purpose/project/localization不取得来源行信用，Android APK与本地无签名iOS/后续实际签名IPA仍分开。后续必须用修复后的新提交及新的构建号重新签名上传并核实际IPA/ASC结果，不能把本地声明验证称为Apple ingest已成功，也不能重新上传失败build1；第五批继续仅本地。


## 2026-11-19｜第四批 C3：iOS 本地 Mini 与 Android 基础范围收敛

用户最新范围为 Android 暂不接入第四批完整容器，只将 iOS 新增收敛到固定原生 iOS 来源的 30%–40%。来源仍为 main `b4462f63a33acf6c3fff63f0e67b3713bc00dff8`，固定 iOS 86 文件 / 15,317 行（14,981 行实现、336 行 headers）；旧完整 main 113 文件 / 20,683 行仅为历史参考，不选择有利分母。Android 和 shared Dart 不计本次 iOS 原生来源。

LBX 扫码及专属两图、Mini HTTP 下载、ZIP 解包安装/更新和 Tiercel 下载实现持续删除，第五批也不得自动恢复。iOS 仅只读打开合格已有本地 Mini；任何非空下载别名/重复参数、force 意图明确不支持；缺包、坏身份、低版本失败，不回退 HTTPS，不创建、修复或写包 metadata。旧更新方法回字符串 code=0、data.msg unsupported、supported=false，不伪造安装或进度。普通首页、原隐私网页及日笺数据保留。

iOS 另真删独立 Flutter Web 呈现、关闭后 cache/reuse、无配置宿主 profile/token 缓存与 WebStorage 镜像、自定义 snapshot/interactive 转场及孤立 Card；关闭重开使用新的 controller/document 和正常 UIKit。Mini 内 H5、活动栈、根首文档 overlay/超时退出、CMS Bridge、直接 getUserInfo provider、标准 mini_notifySessionChanged 与 document/session lease 保留。webLoadingAvailable=false、miniChildWebAvailable=true、closedMiniCacheAvailable=false，三包操作能力均 false、miniPackageMode=local_only。Android 34 个基线文件中，仅 Plugin 的明确 unsupported 与 false 能力字段较第三批 `584c6b92447b90c28a7814fbf022e46e29ed2963` 不同；stage=foundation、foundation_initialized，严格库存/受限 renderer/event lease 保留，无完整 Mini/Web。shared Dart 按两个实际平台合同校验启动，不伪装完整能力。

当前本地验证：Dart format、analyze 通过，完整测试 122 项/0 失败；iOS generic build-for-testing 通过，任务私有 iOS18.2/iPhone16 原生 37 项/0 失败；两个已有本地 Mini 各 18 项真实 CMS/页面检查通过，包括 iframe transport 正控与 native gate、local-only 拒绝、存储、缺 provider fail-closed、前后台及关闭。nonce regular-file probe/ack/final 报告采集通过，普通 main 恢复和私有设备清理已核。Android 新任务私有 API33 AVD 的原基线 renderer instrumentation、真实注册 FlutterEngine 默认 Impeller renderer 路径通过，普通 main 恢复和专用 AVD/目录清理完成。测试包均由测试 runner 在生产接口之外生成；没有恢复生产 installer。

双普通 Release 构建通过，依赖锁前后不变。首次 actual App 扫描揭示旧增量输出残留未链接的 ZIPFoundation framework；保留失败证据，隔离两个完整 generated Runner.app 输出后重新构建，当前全 App 每个 Mach-O 均无 LBX/Tiercel/ZIP 标记，插件无 camera/scanner 标记，专用扫码图片缺失。当前 iOS 原生插件 SHA256 为 `954e28c4d562dea900f511532fde6f35847397a24f5c170bef246771bdaa0fa6`；Android APK SHA256 为 `07c3b6784a5fe7e253ab1cd2d34f99051795c7458c97ddd01c454825a2dd8c21`，无完整 Mini 组件，未添加 INTERNET、Camera 或广泛存储权限。Camera 用途已去除；Pod13 legacy Photos 授权 fallback 仍真实存在，保存相关 Read/Add 用途及 en/zh-Hans 本地化保留，不能为删用途改变保存行为。

`SOURCE_MAP.json` 已按当前普通 Release 输入、实际 native/SDK consumer 与精确源 SHA 求交重建 iOS-only 资格，25 个核心路径，累计 C=6,182；已知同路径前三批子集 P=80，交集=79，未保留=1；扣所有旧参考的保守新增下界=5,632，相对已知 P 的新增上界=6,103（约36.77%–39.84%），整体满足 4,596–6,126。P 不是前三批全部，cross-path/equivalent-derived 来源仍未知；额外参考下界不与 P 相加，不倒推历史。计量不授予 supporting UI、headers、资源、Dart、local adapters、tests、no-caller/declaration、Debug-only 来源信用，也不声称逐行机器码或全部方法执行覆盖。Android 来源信用为0；本地无签名 iOS App/framework 不等于实际签名 IPA。

本节点为负责人实现与本地验证证据，独立 QA/跨端允许差异结论及最终提交另行登记。未执行签名、上传、商店准备或送审，不将旧 C1/C2 发行证据套到当前源码；商店内容与实际签名包由授权发行流程另核。第五批仍仅本地整体验证与补缺。角色长期规则未由本节点改动。

最后按机械格式窗口仅删除 STOnlineWebCore.swift 与 STWebInstanceManager.swift 各一个多余结尾 LF；原文导出证明 after=before.rstrip(LF)+LF、body 字节完全不变，git diff --check 清零。原 native/SDK 运行证据保留其旧 SHA，仅复用无语义变化的执行证据；当前普通 iOS Release 再构建通过，实际包扫描再通过，原生插件二进制 SHA 不变。当前来源资格与正式 provenance 绑定新源 SHA，并显式登记机械复用边界，没有将旧运行记录改写为新 SHA。


## 2026-11-20｜第五批：iOS cache、native transition 与独立 HTTPS Web

本条覆盖历史“第五仅本地、不恢复独立Web/cache、下载安装永久排除”的后续安排；历史节点保留。用户当前要求只加iOS，第五如前批完成验证后提交审核，第六才是最终本地批并加入真实下载安装更新，只有相机/扫码排除。固定来源仍为 `b4462f63a33acf6c3fff63f0e67b3713bc00dff8`，第五前基线 `0af8928ec1c2a7c8a10e11a6e2a954c50e4c756c`。

第五实现普通FIFO2和显式空默认白名单continuous缓存、严格完整bytes/id/version/entry/session身份复核、hidden根+全H5栈撤权及visible fresh epoch；当前owner截图、自定义/interactive转场和取消恢复，无Scanner fallback。显式SDK ordinary HTTPS Web具有独立replacement/cancel/close/session生命周期，Mini子H5等URL FIFO不混用；主frame/currentdoc/origin/native-owner lease与scopedstorage保留。宿主展示参数不改原URL，覆盖期间open/close明确web_covered、session0；engine detach只撤权/清理自己的Mini或Web，foreign自退后才退原惰性navigation。捕获后排队close消费时再核foreign owner，旧操作不能清新UI。

iOS initialize先安装默认反向receiver但不装业务provider，未设置handler仍返回标准code0，重复初始化保已显式provider。Android initialize不新增默认receiver、foundation/cap/error合同不变，host与插件34tracked源相对基线逐字同。本条无新Android构建或设备验证。

本轮实测曾发现并修正转场context缺省视图/宿主重父、released H5晚生命周期崩溃、covered Web/ Mini owner及默认reverse listener缺口；原失败保留，不以编译代OS行为。当前Dart127项全过、analyze/formatcheck通过。任务私有iPhone16/iOS18.2完整native59/0，随后仅Dart修复时65native/test输入及三锁逐SHA同，保留原native报告身份；当前SDKtarget另重建运行。两个已有本地Mini各18项检查、两个真实受控HTTPS Web文档各12项检查全过，含JS/CSS/pixel、iframe transport正控与native拒绝、storage/缺provider失败、session及不同documentNonce关闭重开、前后台appHide/show。nonce probe/ack/final采集通过，普通main恢复、私有sim/TLSserver/临时合成CA及keys均清理；没有ATS/生产信任降级。

普通lib/main.dart device Release无签名构建通过。实际10个Mach-O逐件扫描、native插件15类符号保留，含cache/runtime host/Trans；framework为1,918,440字节，SHA256 `40b0baea19abfc600f55629df8f21e7ea7f36153404c940a873395c16621ffe6`。无Camera/Scanner、ZIPFoundation/Tiercel或测试fixture残留；Photos原保存用途和本地化保留，无新增启动权限请求。它是本地unsigned App/framework，不能替代实际签名IPA、物理机手势/系统Photos写入/分享发送或商店结果。

最终source资格按当前普通Release/native/SDK精确输入求交27核心paths：累计6,973；第五批准候选实际838（Web163/cache457/transition218），相对C3已知集合新846/未再逐字留存55。安全改写、Dart、测试、资源、supportingUI、no-caller代码不获来源信用，未逐字保留不等于功能损失。第六同固定source候选再扣当前交集1行为download988、可选safe镜像至多92；它们未实施/合格，838对988..1080仅预测45.89/54.11至43.69/56.31，不能称最终qualified50/50。真实最终比例须第六安全适配/Release/consumer完成后核。`SOURCE_MAP.json`/`UPSTREAM.json`保存完整ranges、交并、当前输入资格及历史C3，旧EOF执行复用没有套用本批真实改动。

普通首页、日笺schema/数据、主题、中英界面、原隐私路径不变，启动仍只initialize/state/inventory；无生产Mini/Web URL、隐藏/远程激活、账户或交易provider。第五仍无下载/ZIP安装/更新能力与依赖，第六才实现；未消费Tiercel/旧非原子helper不为行数恢复。当前为开发整合证据，独立QA/cross及实际signedIPA/发行内容/ASC仍分别门禁；本节点未签名、上传、改商店文案或送审，源码提交及CI实际head另追溯。


### 2026-11-20 第五批接续验证与 P205 收口

接续已保存的 P205 修复，发现 WarmActivationTicket 的通用 UINavigationController 类型无法访问 Mini navigation 的 foreign-owner 保护；已在 ticket 消费边界明确验证 STWebNavigationController，保留全部 owner/document/session/stack/window 检查。完整原生61项重新运行零失败（含真实WK warm事件顺序、duration一次消费与close/document/session失效负控），真实两个Mini各18项、两个受控HTTPS文档各12项检查全部通过，普通入口恢复、私有sim/TLS清理通过。当前执行身份 takeover1120v2；首轮编译失败保留，未复用旧59项冒新执行。

普通 device Release 重建通过，逐包扫描通过；插件1,938,088字节，SHA256 cdd7e1dd125d377f89a0f114d3a8206c668f694d7b6c8bc417985148a49894e6。当前27核心path来源资格重新绑定本次native/SDK/Release输入；累计6964、第五逐字候选833（Web158/cache457/transition218）、相对C3已知新增841/不再逐字保留59。上述是严格来源量，不代表功能比例；旧上段数字为修复前历史。Android与相机/下载安装边界不变，第六未实施。本轮尚未签名IPA或送审，后续发行更新记录按用户指定精确 fix bug，不新增审核备注。
