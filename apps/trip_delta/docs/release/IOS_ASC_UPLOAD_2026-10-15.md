# Trip Delta iOS 1.0.0 ASC 上传记录

日期：2026-10-15（Asia/Shanghai）

| 项目 | 已验证结果 |
| --- | --- |
| 源码 | `c2551bb21779ea24645f1d92ca2a75a01f258f11`，位于 `origin/main` 历史中 |
| 云构建 | [GitHub Actions run 38667564770](https://github.com/use032026/majia/actions/runs/38667564770)，结论 `success` |
| 签名与 IPA | Archive、导出及单一 Bundle IPA 检查通过；IPA SHA-256 `7d6bd39043f4af70a62022ee1914e3c05967f64e8f4dc21a7c404d49b768afc7`；[构建工件](https://github.com/use032026/majia/actions/runs/38667564770/artifacts/11943301641) |
| 应用标识 | iOS `com.tripdelta.lite.app`，GitHub Environment `tripdelta-production` |
| 版本 | `1.0.0 (2)`；构建号由工作流查询 ASC 后自动确定 |
| ASC | App ID `6822704143`；Build ID `0903d59b-6498-4d08-a08b-c414a7a99995`；上传 `COMPLETE`，处理 `VALID`，无上传错误或警告；[ASC 状态工件](https://github.com/use032026/majia/actions/runs/38667564770/artifacts/11943068650) |
| TestFlight | 内部状态 `READY_FOR_BETA_TESTING`；未核实测试人员安装或实体设备运行 |

此前的 `1.0.0 (1)` 上传在 Apple 处理阶段因缺少 `NSPhotoLibraryUsageDescription` 被拒（错误码 `90683`）。源码已按“保存旅程回顾卡片到相册”的实际功能补齐用途说明，并以新源码重新构建。

本次仅完成打包与 ASC 上传。未创建或关联 App Store 商店版本，未修改商店元数据或截图，未提交 App Review，也未上架。
