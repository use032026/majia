# Refqo 本地交付 — 2026-10-21
产品面向多设备共用耗材的家庭：型号/适配备注→关联设备→30/60/90天共享库存净补货→入库→更换扣减→可撤销流水→备份恢复。离线、中英文、无账号，含原创图标、原生启动和可重看的引导。

- 代码与35项测试完成；格式和分析器通过。新项目隔离在refqo，保留原效果册。
- iPhone SE、iPad mini、Android15/API35完整核心流程均通过，36张运行图；iPad原生Files本地备份/恢复及分享取消重开已实测。
- Android arm64调试APK与iOS15最低目标、iPhoneOS26.5 SDK的无签名Release归档均成功；无生产签名、上传或审核。
- Fylqo已排除；Refqo（5字母）公开检索未发现同名App，但后台占名/未发布名称/商标权利未确认，不能承诺“未注册”。
- 上架预检blocked：正式标识、发行签名、真实主体/支持联系和公开隐私/支持页面仍缺；同类4.3风险、真机/最低系统/API36/16KB验证需补。

报告：[差异化](product/DIFFERENTIATION.md) · [来源与命名](product/MARKET_EVIDENCE.md) · [功能审核](release/FUNCTIONAL_REVIEW.md) · [UI验收](release/UI_ACCEPTANCE.md) · [上架风险](release/APP_STORE_PREFLIGHT.md) · [证据](release/EVIDENCE_REGISTER.md) · [后续缺口](release/GAP_BACKLOG.md) · [复盘](factory/RETROSPECTIVE.json)

产物：`build/app/outputs/flutter-apk/app-debug.apk`；`build/ios/archive/Runner.xcarchive`。正式包标识仍为本地占位com.example.refqo。下次发行明确使用lib/main.dart，并按待办剥离未用测试插件、复核签名/隐私/散列。
复盘提出的技能改进候选仅为“iPad分享使用可见小锚点并验证实际弹层、取消重开及Files往返”；未修改任何Skill。
