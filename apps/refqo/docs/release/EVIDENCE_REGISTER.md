# 证据登记 — 2026-10-21
所有结果均为本轮实际执行；未把构建、模拟器、签名、上传和审核混为一层。

| 层级 | 结果 | 证据 | 限度 |
|---|---|---|---|
| 原创性/来源 | 内部门槛passed | ../product/DIFFERENTIATION.md、MARKET_EVIDENCE.md | 无用户访谈，不证明无人具备相同功能或法律清白。 |
| 静态 | format/analyzer passed | automation/20261021T111513+0800/QUALITY_GATE.md | 不证明设备行为。 |
| 单元/组件 | 35/35 passed | 同上 flutter-test.log；test/中保留可重跑用例 | 业务/文件仓库/偏好/恢复/大字/弹层锚点；不是全部系统组合。 |
| iOS模拟器核心 | passed | ios-runtime-final-source.log；runtime/ios-se-final/01…12 | SE3 C26BF6B0-9408-4B58-99CF-4DC8C466A9C8，iOS18.3，Debug。 |
| iPad模拟器核心 | passed | ipad-runtime.log；runtime/ios-ipad/01…12 | mini A17Pro DF747168-3634-42B8-AD03-75E8F450306C，iOS18.3，Debug。 |
| Android模拟器核心 | passed | android-runtime.log；runtime/android-api35/01…12 | 独立Refqo_QA emulator-5580，Android15/API35，Debug，1080×2400。 |
| 普通main原生检查 | 已检状态passed | NATIVE_CHECKS.md；runtime/native/ | iPad安装图标、正常冷启动、真实Files空库导出/恢复；Android普通main冷启动。 |
| Debug APK | passed | android-delivery-final-build.log；build/app/outputs/flutter-apk/app-debug.apk | 显式main入口、arm64工程构建；不是签名发行AAB。可能使用/生成本机debug keystore，未创建生产证书。 |
| Android 16KB机械 | passed | android-16kb-inspection.json | ELF/ZIP对齐；模拟器页大小4096，不能证明16KB运行或最终AAB。 |
| iOS无签名Release归档 | passed | ios-archive-final.log；build/ios/archive/Runner.xcarchive；archive-inspection.json | Xcode26.5/iphoneos26.5、arm64、最低15；无provision/signature，不是可上传发行包。 |
| 归档隐私清单 | 4份有效 | archive-inspection.json、机械preflight | Flutter/三个插件已打包；合并隐私报告/商店答卷未做。 |
| 来源追溯/散列 | 已记录 | source-sha256.json、最终机械preflight | 工作目录不是Git仓库；记录源文件与App.framework/App等散列，无commit声明。 |
| 实体设备/最低系统/API36/16KB | 未执行 | 缺口见GAP_BACKLOG.md | 不由当前模拟器结果推导。 |
| 发行签名/上传/ASC处理/TestFlight/审核/Play发布 | 未执行 | 用户停止条件 | 没有外部成功声明。 |

运行截图不是营销截图；自动截图部分含alpha。所有代码相关截图在对应构建后采集，分享锚点变更影响的原生状态单独重建复验；先前核心流程布局未改变。
原始失败均保留：all-local gate的Android磁盘耗尽、Flutter无签名归档Team提示、英文查找器遇中文、pageBack语言查找器以及固定IO等待失败。后续Android构建、显式无签名归档、条件等待和原生分享重测分别关闭对应问题；不可用后续结果改写先前日志。

最终机械预检：automation/preflight-20261021T112104+0800/RELEASE_PREFLIGHT.md（blocked，正式身份/公开URL/签名缺口）。最终源文件散列见source-sha256.json；APK与AOT App二进制散列包含在该最终preflight。测试结束已关闭本任务的headless Android与SE模拟器，保留iPad普通main应用便于查看；未关闭其他会话设备。
