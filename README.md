# majia

多应用 Flutter 仓库。每个应用独立放在 `apps/<应用名>/`，仓库级 GitHub Actions 工作流和共用发布脚本分别放在 `.github/workflows/`、`.github/scripts/`。

## 应用目录

| 应用 | Flutter 工程 | 来源 |
| --- | --- | --- |
| Jufu（`photo`） | [`apps/photo/`](apps/photo/) | [`CherryIce/photo`](https://github.com/CherryIce/photo)，迁移基点 `295a625059f8f4102d194029ba9bc58c68e87eb6` |
| RoamSum（`tripcost`） | [`apps/tripcost/`](apps/tripcost/) | [`CherryIce/TripCost`](https://github.com/CherryIce/TripCost)，迁移基点 `5e8e2975d0967a31691529ef603e22e0f1cb63cb` |
| Trip Delta（旅程差额） | [`apps/trip_delta/`](apps/trip_delta/) | 独立 Flutter MVP，离线优先、中英文、无账号 |
| LAURUS（源项目 `donesome` / `Hearthio`） | [`apps/donesome/Hearthio/`](apps/donesome/Hearthio/) | [`CherryIce/Donesome`](https://github.com/CherryIce/Donesome)，迁移基点 `ccc86d05c66935005d0db25a4c50224a07633119` |
| CleanTrail（清迹） | [`apps/cleantrail/cleantrail/`](apps/cleantrail/cleantrail/) | [`CherryIce/Cleantrail`](https://github.com/CherryIce/Cleantrail)，迁移基点 `487c079c9f9b336dcedb586b80f9cca862c7a896` |
| PlotProof Lab（图证实验室） | [`apps/plotproof_lab/plotproof_lab/`](apps/plotproof_lab/plotproof_lab/) | [`CherryIce/plotproof_lab`](https://github.com/CherryIce/plotproof_lab)，迁移基点 `7abd805f1ca6448e09dafbef6db3a153f20c6b0c` |
| KIFXPRO（源项目 `sdpacket`） | [`apps/sdpacket/`](apps/sdpacket/) | [`CherryIce/SDPacket`](https://github.com/CherryIce/SDPacket)，迁移基点 `f5c16af424977b76da8a5b205f05c4b96768d52c` |
| PhotoReport（现场照片记录） | [`apps/photoreport/`](apps/photoreport/) | [`CherryIce/PhotoReport`](https://github.com/CherryIce/PhotoReport)，迁移基点 `ad5cf6b8006ae4a569ea2bae1445dae3fa28c95f` |
| Steady21（微成） | [`apps/steady21/`](apps/steady21/) | [`CherryIce/steady21`](https://github.com/CherryIce/steady21)，迁移基点 `0e273393c3cea00440c30d2b108beb813be7dcf5` |

具体功能、平台限制、本地命令和发布缺口以各 Flutter 工程内的 `README.md` 与 `docs/` 为准。

## iOS 云构建与发布

以下工作流均从 GitHub Actions 手动触发，仅允许 `main` 分支作为发布来源。它们使用受保护的 GitHub Environment 完成签名构建并保留 IPA；是否上传 App Store Connect、创建商店版本、提交审核或修改元数据由运行时开关决定。

| 应用 | 工作流 | GitHub Environment | 签名 Targets | ASC 状态查询 |
| --- | --- | --- | --- | --- |
| Jufu（工作流配置名为 Lunelle） | [`Photo iOS Release`](.github/workflows/photo-ios-ci.yml) | `photo-production` | `Runner` | 支持 |
| RoamSum | [`TripCost iOS Release`](.github/workflows/tripcost-ios-release.yml) | `tripcost-production` | `Runner`、`AppWidget` | 支持 |
| LAURUS | [`Hearthio iOS Release`](.github/workflows/donesome-ios-release.yml) | `hearthio-production` | `Runner` | 支持 |
| KIFXPRO | [`KIFXPRO iOS Release`](.github/workflows/sdpacket-ios-release.yml) | `sdpacket-production` | `Runner` | 支持 |
| PlotProof Lab | [`PlotProof Lab iOS Release`](.github/workflows/plotproof-lab-ios-release.yml) | `plotproof_lab-production` | `Runner` | 暂未加入查询选项 |

`CleanTrail`、`PhotoReport`、`Steady21` 和 `Trip Delta` 当前没有仓库级 iOS 发布工作流；各自 README 中的本地构建或预检结果不能视为签名 IPA、ASC 上传或 TestFlight 证据。

### 发布开关

- `upload_to_asc=false` 是默认值：执行签名构建并保留产物，但不上传 App Store Connect。
- `auto_create_store_version=true` 要求同时设置 `upload_to_asc=true`；它只创建或复用商店版本，不会提交审核。
- 在上述构建发布工作流中，`submit=true` 要求同时设置 `auto_create_store_version=true`；只有该开关为 `true` 时才会在版本和构建准备完成后提交审核。`submit=false` 不会提交。
- [`ASC Submit Review`](.github/workflows/asc-submit-review.yml) 可从 `main` 独立提交已经存在且已关联有效构建的商店版本；手动运行时只需选择应用 Environment 和版本号，不会重新构建、上传 IPA、创建商店版本或修改元数据。
- `update_asc_text_metadata` 和 `replace_asc_media` 只有在自动创建商店版本时才能启用，并且只处理应用 `app-store/metadata.yml` 中明确声明的字段或媒体集合。
- 非空 `release_notes_json` 要求 `update_asc_text_metadata=true`。
- 当前元数据模板默认只声明出口合规字段；名称、描述、更新说明和媒体示例仍为注释，启用开关不会修改未声明的内容。

工作流存在不代表某次运行已经成功。签名构建、IPA 产物、ASC 接收、处理完成、TestFlight 可用和 App Review 状态是不同的证据层级，应以对应运行的 Job Summary、Artifacts 和 App Store Connect 状态为准。

### Environment 配置名

每个发布工作流只读取自己的受保护 Environment。请配置名称，不要把真实签名材料提交到仓库。

始终需要：

- Variables：`APPLE_TEAM_ID`、`IOS_BUNDLE_ID`、`IOS_SCHEME`
- Secrets：`IOS_DISTRIBUTION_P12_BASE64`、`IOS_DISTRIBUTION_P12_PASSWORD`、`IOS_APPSTORE_PROFILE_BASE64`

上传 ASC 或查询审核状态时还需要：

- Variables：`ASC_KEY_ID`、`ASC_ISSUER_ID`
- Secret：`ASC_API_KEY_P8`

`TripCost` 的描述文件归档需同时覆盖主应用和 `<IOS_BUNDLE_ID>.widget`。所有发布工作流固定使用 Flutter `3.35.7`，构建号在仅打包时来自 GitHub run number，上传时按 ASC 中现有构建号递增。

## 其他自动化

- [`ASC Submit Review`](.github/workflows/asc-submit-review.yml) 使用与构建发布流程相同的仓库内提交脚本，可独立提交现有版本；结果会写入 Job Summary 并保留 30 天 JSON 证据。已提交版本会作为幂等 no-op 返回。
- [`ASC Review Status`](.github/workflows/asc-review-status.yml) 是只读查询，可按版本获取 `photo-production`、`tripcost-production`、`hearthio-production` 或 `sdpacket-production` 对应应用的 ASC 处理、TestFlight 与审核状态，并保留 30 天 JSON 快照。
- [`PlotProof lesson content refresh`](.github/workflows/plotproof-content-refresh.yml) 每周一 `03:17 UTC` 自动运行，也可手动触发；它生成并校验公开数据课程包，只在内容变化时提交 `lesson_pack.json`。
- 发布输入与 ASC 状态解析的 Ruby 测试位于 [`.github/scripts/`](.github/scripts/)，修改工作流或共用脚本时应一并运行。

## 本地开发

进入上表中的 Flutter 工程目录后，通常使用：

```sh
flutter pub get
flutter analyze
flutter test
```

部分应用还需要代码生成、特定 `--dart-define` 或额外平台验证，请先阅读该应用自己的 README。自动化测试、模拟器和无签名构建均不能替代真机权限、系统分享/打印、通知、网络异常或商店审核验证。
