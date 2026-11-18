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
