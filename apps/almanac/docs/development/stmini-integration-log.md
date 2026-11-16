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
