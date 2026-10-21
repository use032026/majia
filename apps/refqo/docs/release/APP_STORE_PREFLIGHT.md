# 上架预检与风险 — Refqo — 2026-10-21
**发布判定：blocked。本地代码、已检功能和模拟器流程通过，不等于商店候选已具备提交条件。未上传、占名、创建证书、修改生产账号或提交审核。**

## 当前技术基线
- Flutter 3.35.7 / Dart 3.9.2（实际命令返回），Xcode26.5 /17F42。安装目录与源码存在版本不一致，未声称使用新版Flutter。
- iOS最低15.0；真实无签名Release归档使用iphoneos26.5，版本1.0.0(1)、arm64。Apple当前上传要求为Xcode26+/iOS26 SDK+，这是上传工具链要求，不是最低用户系统：[Apple](https://developer.apple.com/news/upcoming-requirements/?id=02032026a)。
- Android最低API24，compile/target36；Google自2026-08-31要求新手机App target36+：[Google](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)。Debug APK构建成功，只能作为本地工程证据。
- 当前Debug APK全部64位.so的ELF/ZIP机械16KB对齐符合；运行模拟器PAGE_SIZE=4096，尚无16KB运行或正式AAB证据：[Android](https://developer.android.com/guide/practices/page-sizes)。

## Apple规则矩阵
规则正文：[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)。

| 规则 | 判定/风险 | 已有证据 | 缺项与责任 |
|---|---|---|---|
| 1.5 开发者信息 | blocked | 产品内有隐私边界说明 | 需所有者提供真实主体、联系渠道、公开支持网址，不能虚构。 |
| 2.1 完整性 | 本地通过，发布证据不足 | 35项测试；三设备完整核心流程；iPad原生备份/恢复 | 真机、正式签名、全部文件提供方与中断组合未验证。 |
| 2.3 准确元数据 | needs_revision | 中英UI、审核说明草案、运行截图 | 正式商店描述、合规截图、年龄分级、隐私表单待完成；运行PNG并非上传截图。 |
| 2.4 兼容 | 部分通过 | iPhone SE/iPad mini iOS18.3、Android15运行 | 最低iOS15/Android24、Android36、横屏、平板分屏与实体设备仍待补。 |
| 3.1 支付 | 不适用 | 无数字收费/IAP/订阅 | 若改变商业模式必须重新评审。 |
| 4.1 模仿 | 未发现明确问题 | 原创图标/资产、供给优先架构 | 非法律权属保证。 |
| 4.2 最低功能 | 本地candidate | 多设备共享SKU→窗口需求→采购缺口→入库/更换/撤销→可保留备份 | 需在审核说明中展示实际两设备共用库存的价值。 |
| 4.3 重复/垃圾App | high_risk | 比广义保养工具更窄；数据模型及计划输出独立 | 同类已有库存/扣减，未有家庭用户验证；不能将中英/离线当唯一差异或承诺审核通过。 |
| 4.8 登录 | 不适用 | 无账号与第三方登录 | 无需制造登录或账号删除流程。 |
| 5.1 隐私 | blocked | 本地存储、最小权限、删除/导出、四份真实打包SDK隐私清单 | 需公开正式政策与真实联系方式、Xcode合并Privacy Report、ASC/Play真实答卷。 |
| 5.2 权利 | 名称未最终核实 | Refqo公开检索未发现同名App；独立生成资产 | Fylqo因用户确认已用而排除。Refqo未验证后台占名/未发布名称/商标，不称“未注册”。 |

## 发行产物与材料
- 归档标识仍为 `com.example.refqo`，仅本地占位；Android同样。iOS未配置Team/发行签名，归档无签名及provision。Android release signingConfig=null，避免默认误用debugkey，但正式签名仍缺。此调试APK不能作为Play发行AAB。
- 包内有效PrivacyInfo.xcprivacy：Flutter、file_selector_ios、path_provider_foundation、share_plus；无追踪/收集类型声明，并含Flutter必要原因API声明。实际打包通过，不替代隐私表单及行为审计：[Apple SDK要求](https://developer.apple.com/support/third-party-SDK-requirements/)。
- 没有真实公开privacy/support URL，不填假域名或假邮箱。政策草案不能替代正式公开政策：[Google User Data](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)。
- 归档含Flutter开发依赖带入的integration_test.framework；Dart实际入口为lib/main.dart，未发现独立网络监听或自动测试入口，非已证实的Apple阻断。列P2：正式签名前移除未用测试插件并重新审包。每次发行显式指定main入口，避免上次集成测试生成配置影响构建。
- Android新个人开发者账号若适用，需12人连续14天封闭测试后申请生产权限；账号类型未知：[Google测试要求](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)。
- 无实体设备、发行签名包、上传接收、ASC处理、TestFlight、审核决定或Play生产发布证据。

## 官方来源与研究限度
以上官方页面于2026-10-21实时核验。完整竞品观察/推断分离见 ../product/MARKET_EVIDENCE.md。公开页面不证明竞品未实现某功能；搜索空结果不证明名称可注册。最终店铺决策由商店独立作出。
最高价值下一步：先确认正式名称/主体/标识及真实双语支持与隐私页面，再完成生产签名和真机/16KB/最低系统验证。涉及创建商店记录、证书、上传或提交时需单独明确授权；本轮到此停止。
