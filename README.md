# majia

每个应用独立放在 `apps/<应用名>/`；GitHub Actions 工作流统一放在仓库根目录的 `.github/workflows/`。

| 应用 | 目录 | 来源 |
| --- | --- | --- |
| Jufu（photo） | [`apps/photo/`](apps/photo/) | [`CherryIce/photo`](https://github.com/CherryIce/photo)，迁移基点 `295a625059f8f4102d194029ba9bc58c68e87eb6` |
| TripCost（RoamSum） | [`apps/tripcost/`](apps/tripcost/) | [`CherryIce/TripCost`](https://github.com/CherryIce/TripCost)，迁移基点 `5e8e2975d0967a31691529ef603e22e0f1cb63cb` |
| Trip Delta（旅程差额） | [`apps/trip_delta/`](apps/trip_delta/) | 独立 Flutter MVP，离线优先、中英文、无账号 |
| Donesome（LAURUS） | [`apps/donesome/`](apps/donesome/) | [`CherryIce/Donesome`](https://github.com/CherryIce/Donesome)，迁移基点 `ccc86d05c66935005d0db25a4c50224a07633119` |
| Cleantrail | [`apps/cleantrail/`](apps/cleantrail/) | [`CherryIce/Cleantrail`](https://github.com/CherryIce/Cleantrail)，迁移基点 `487c079c9f9b336dcedb586b80f9cca862c7a896` |
| plotproof_lab | [`apps/plotproof_lab/`](apps/plotproof_lab/) | [`CherryIce/plotproof_lab`](https://github.com/CherryIce/plotproof_lab)，迁移基点 `7abd805f1ca6448e09dafbef6db3a153f20c6b0c` |
| SDPacket（搬家箱） | [`apps/sdpacket/`](apps/sdpacket/) | [`CherryIce/SDPacket`](https://github.com/CherryIce/SDPacket)，迁移基点 `f5c16af424977b76da8a5b205f05c4b96768d52c` |
| PhotoReport（现场照片记录） | [`apps/photoreport/`](apps/photoreport/) | [`CherryIce/PhotoReport`](https://github.com/CherryIce/PhotoReport)，迁移基点 `ad5cf6b8006ae4a569ea2bae1445dae3fa28c95f` |
| Steady21（微成） | [`apps/steady21/`](apps/steady21/) | [`CherryIce/steady21`](https://github.com/CherryIce/steady21)，迁移基点 `0e273393c3cea00440c30d2b108beb813be7dcf5` |

`photo` 的 [iOS CI](.github/workflows/photo-ios-ci.yml) 进行无签名构建，并保留不可直接安装到设备的 `Runner.app` 压缩产物；它不生成已签名 IPA。正式 Release Bundle ID 为 `com.lunelle.lite`；签名发布还需要单独配置证书、描述文件和受保护的 GitHub Environment。

`tripcost` 的 [iOS Release](.github/workflows/tripcost-ios-release.yml) 可手动归档并签名 Runner 与 AppWidget，默认不上传 App Store Connect；签名材料需配置在 `tripcost-production` Environment 中。

`donesome` 的 [iOS Release](.github/workflows/donesome-ios-release.yml) 可手动归档并签名 LAURUS，默认不上传 App Store Connect；签名材料需配置在 `hearthio-production` Environment 中。
