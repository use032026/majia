# Somniloquy

Somniloquy 是一个离线优先、无账号的 Flutter 夜间声音笔记 MVP。它不会自动判断鼾声、睡眠阶段或疾病，而是先找出相对房间基线的声音变化，再由用户在晨间亲自试听、标注并补充梦境回忆。

## 已实现

- 中英文界面、明暗模式、手机和平板响应式布局
- 录音前同室人员同意、麦克风即时授权、持续录音指示与 12 小时上限
- 本地 AAC 录音、环境基线校准、最多 24 个候选声音时刻
- 候选必须人工标注或忽略后才能成为已核对夜间卡片
- 待核对草稿跨重启恢复，并可保留、继续或永久删除
- 本地背景标签统计、单晚删除和全部删除
- 无账号、无自有后台、无广告或分析 SDK

## 本地运行

```sh
flutter pub get
flutter run
```

## 质量状态

- `flutter analyze`：通过
- 自动化测试：16 项通过
- Android debug APK：构建通过
- iOS release Archive：无签名构建通过
- iPhone SE 与 iPad Pro 模拟器：核心界面已目视核对

完整证据见 [功能审核](docs/release/FUNCTIONAL_REVIEW.md)、[差异化报告](docs/product/DIFFERENTIATION.md) 和 [App Store 预检](docs/release/APP_STORE_PREFLIGHT.md)。

## 发布边界

当前不是可提交 App Store 的成品：仍使用占位 Bundle ID，未配置 Distribution 签名，也没有已发布的隐私政策/支持 URL、App Store Connect 元数据或实体设备整夜录音证据。本次未上传或提交到 App Store。
