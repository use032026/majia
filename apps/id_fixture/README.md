# ID Fixture 证号实验室

当前版本 **1.1.0+2**。Flutter 本地测试数据应用，按国家、区域和证件生成合成测试用例，并通过 JSON 用例包按锁定版本复现。

本目录是 `CherryIce/ID-Fixture` 的 iOS / Android 独立快照，应用身份、规则与用例包兼容性沿用源版本。 [迁移基点 3033487](https://github.com/CherryIce/ID-Fixture/commit/3033487c62a7f74de666485dd26fffbe8de6c78e)

## 当前规则范围

- 中国大陆：GB 11643结构与校验，提供31省级分组下的 **2851个公开参考候选代码**，支持原文地名/代码搜索及分层选择。此集合不是全国实际签发代码全集；特殊市级参考码与公开报道前缀保留各自限制，实际签发未知。
- 中国香港：公开格式及校验规则，可选1或2个大写字母前缀；规范输出不带括号，不推断出生日期、性别或签发地区。
- 中国澳门：公开格式层；**校验字符算法未知**，不提供校验位反例，也不把未知项标为通过。
- 中国台湾：22个当前地区前缀，另有4个须显式选择的历史前缀；支持编码性别与公开校验规则，历史前缀保持明确标记。
- 越南：启用公开历史结构测试；先以 **34个当前省级单位导航**，再选对应的 **63个公开历史出生地前缀**。当前两位行政码不是证件三位前缀。只编码出生年份，现行新签发分配符合性未知，不把历史解释当成当前身份事实。
- 美国：仍仅纽约州DMV ID与新一代护照本公开格式，NY须先选择州；不推广为全美驾照或完整签发算法。

旧版`cn-id-demo`保留为归档规则，仅供已有1.0用例包恢复与复现，仍是2022年北京3区演示，不静默升级到新档案。所有合成值可能与真实号码重合；格式或校验通过不证明实际签发、持有人或有效性。

## 本地开发

在 `apps/id_fixture/` 执行以下命令。Flutter 版本为 3.35.7，Dart 版本为 3.9.2。目标平台为 iOS 13+ 和 Android API 24+。

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
# Android arm64 AOT 本地验收包（既有Debug证书；不配置生产签名）
./tool/build_android_local.sh
# iOS模拟器完整ad-hoc签名；参数替换为你选择的模拟器UDID
./tool/build_ios_simulator.sh 'id=<模拟器UDID>'
```

Android 本地验收 APK 写入 `artifacts/`，iOS 模拟器 App 写入 `build/ios/`。Android 集成测试的默认报告也位于 `artifacts/`，可用 `ID_FIXTURE_INTEGRATION_REPORT` 指定其他路径。

```sh
flutter drive -d <Android设备标识> \
  --driver=test_driver/integration_driver.dart \
  --target=integration_test/android_workflow_test.dart
```

`data/sources/` 保存规则生成所需的输入。使用 `python3 tool/generate_coverage_data.py` 更新规范快照和 Dart 规则表。Flutter 回归测试所需的历史用例包位于 `test/fixtures/`。

应用图标母版和资源生成工具位于 `branding/` 与 `tool/generate_brand_assets.py`。系统分享回归使用独立测试接收器。 [接收器使用说明](test/native_share_receiver/README.md)

原始规则来源及 1.1 版验收范围见上游记录。 [规则覆盖与交付记录](https://github.com/CherryIce/ID-Fixture/blob/3033487c62a7f74de666485dd26fffbe8de6c78e/docs/coverage/DELIVERY.md)
