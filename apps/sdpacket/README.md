# KIFXPRO

Flutter 实现的本地优先装箱登记与定位应用。产品规格见
[`Docs/KIFXPRO_设计开发文档.md`](Docs/KIFXPRO_设计开发文档.md)，当前实现状态见
[`Docs/Flutter_MVP_开发进度.md`](Docs/Flutter_MVP_开发进度.md)。

## 当前能力

- 本地项目创建、编辑、归档、恢复和删除。
- 自动分配项目内唯一箱号；删除后不回退序号。
- 手动、批量照片和语音三种登记入口，权限不可用时可回到文字登记。
- 连续相机批次、“保存并下一箱”、房间/标签批量套用及未完成批次恢复。
- 离线搜索箱号、标题、备注、结构化物品、房间、位置和标签。
- 可多选的待装车/未到达/未拆箱/疑似遗漏看板筛选。
- 搬家现场连续扫码，批量推进状态并提示重复扫描、震动反馈和未扫描清单。
- 状态变更历史记录操作时间与手动/扫码来源，并支持撤销最近一次误操作。
- 最近使用及常用房间、位置、标签模板可一键复用。
- 结构化物品支持名称、数量、备注、逐项拆箱勾选和增删改。
- 稳定 UUID 二维码、高清 PNG、单个 PDF、A4 批量标签、系统分享和打印。
- 自动生成包含总数、疑似遗漏、损坏、未拆箱及房间分布的项目收尾 PDF。
- CSV 导出、包含照片/清单/SHA-256 校验和的版本化备份包及旧 JSON 恢复兼容。
- 简体中文和英文界面；权限用途文案随 iOS 系统语言本地化。

## 系统要求

- Flutter 3.35.7 / Dart 3.9.2（当前验证工具链）
- iOS 15+
- Android 14+（`minSdk = 34`）

当前平台标识：

- iOS 生产 Bundle ID：`com.kifxpro.lite`
- Android 开发期 Application ID：`com.starburst.moving_box`

iOS 已使用生产标识并通过云构建环境配置独立的 Release 签名；当前 Android Release 配置仍沿用 Flutter 模板的 Debug 签名，不可用于发布。

设置页会根据当前应用语言在外部浏览器打开公开页面：

- 简体中文：`https://kifxpro.com/privacy.html?lang=zh`
- English：`https://kifxpro.com/index.html?lang=en`
- 支持邮箱：`15211857631@163.com`

远程隐私页面无法打开时，应用会显示内置隐私说明作为兜底；无法打开邮件应用时，会显示可手动发送的支持邮箱。

## 本地运行

```bash
flutter pub get
flutter gen-l10n
flutter run
```

## 验证

```bash
flutter analyze
flutter test
flutter build ios --simulator --no-codesign
flutter build apk --debug
```

构建和自动化测试不能替代真机相机、语音、照片选择、扫码、系统分享、打印、飞行模式及 Android 14 设备验收。

## 代码结构

```text
lib/
├── data/       # JSON 快照、原子写入、备份校验、应用状态
├── models/     # 项目、箱子、物品与状态模型
├── screens/    # 项目、箱子、搜索、扫码、语音、标签与设置页面
├── services/   # 照片持久化、QR 载荷、备份、CSV/PDF 导出
├── widgets/    # 共用表单、实体标记与本地化映射
└── l10n/       # zh/en ARB 与生成代码
```
