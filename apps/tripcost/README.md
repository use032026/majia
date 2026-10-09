# TripCost

TripCost 是旅行真实消费成本助手 RoamSum 的开发代号。Flutter 主应用支持 iOS 15+ 与 Android 24+；已具备精确金额、Drift、Frankfurter v2 与离线汇率链路、快速换算、支付成本与 DCC，以及行程 CRUD、预算仪表盘、消费账本、实际入账和本地费用校准。历史汇率与支付规则均以快照随消费保存。iCloud 与 Widget 仅在 Apple 平台启用；Android OCR 使用随包分发的本机模型。

## 本地启动

```bash
flutter pub get
flutter gen-l10n
flutter test
flutter run -d <ios-simulator-id>
```

Android 使用正式包名 `com.tripcost.lite`。云端 APK/AAB 由仓库根目录的 `Android Package` 工作流生成；没有 `TRIPCOST_ANDROID_*` 正式签名 Secrets 时，只能以 `sign_release=false` 生成内部验证包。

环境参数通过 `--dart-define` 注入：

```bash
flutter run \
  --dart-define=APP_FLAVOR=development \
  --dart-define=API_BASE_URL=https://api.frankfurter.dev
```

## 生成 Pigeon 契约

```bash
./tool/generate_pigeon.sh
```

提交 schema 与 Dart/Swift 生成产物。正式显示名与 Apple 标识已经冻结；能力、签名材料和人工验收边界见 `docs/IOS_CAPABILITIES.md`。

## iOS 云构建

仓库通过手动触发的 `TripCost iOS Release` GitHub Actions 工作流归档 Runner 和 AppWidget。工作流默认不上传 App Store Connect；生产签名材料只存放在受保护的 `tripcost-production` Environment 中。

- 构建配置：`.github/ios-build.yml`
- 工作流：[`../../.github/workflows/tripcost-ios-release.yml`](../../.github/workflows/tripcost-ios-release.yml)
- 首次验证：使用 `upload_to_asc=false`，并核对远端 SHA、IPA 中的两个 Bundle ID、签名 Team 和 embedded profiles。
- 正式上传：确认使用未占用的 build number 后，再使用 `upload_to_asc=true`。

## 生成数据库代码与 schema

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump \
  lib/core/storage/database/app_database.dart \
  drift_schemas/
dart run drift_dev schema generate \
  drift_schemas/ \
  test/generated_migrations/
```

每次提升 `AppDatabase.schemaVersion` 时同时提交新 schema 导出、显式升级步骤和旧版本迁移测试。

## 汇率网络冒烟

默认测试不会访问公网。需要单独验证 Frankfurter v2 的币种、批量和历史接口时运行：

```bash
RUN_FRANKFURTER_SMOKE=1 \
  flutter test test/core/rates/data/frankfurter_live_smoke_test.dart
```

连接类型只用于执行“仅 Wi-Fi”策略，不能证明互联网一定可用；实际请求仍通过超时、错误映射、缓存回退和指数退避处理失败。
