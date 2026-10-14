# Trip Delta / 旅程差额

离线优先的中英文旅行预算应用。用户可在出发前按类别规划预算，旅行中快速记录当地币种支出，并在结束后比较计划、估算折算和最终入账金额。

## 功能闭环

- 建立带日期、目的地、本位币和当地币种的行程，设置五类预算；首笔支出锁定预算基线。
- 首页分为“当前”和“历史”：当前页突出正在记录的旅程并直达新建表单，历史页按复盘时间排列并可按旅程名或目的地搜索。
- 快速记账并复用手填汇率；行程详情展示预算概览与最近三笔支出，完整预算对照和全部支出进入独立页面；在支出列表按类别、日期或待核对状态筛选。
- 外币支出先按汇率估算，需逐笔填写最终金额或明确确认估算金额，才能完成复盘。
- 对照类别差额、主要支出并记录原因；按最终总支出与原总预算的比例展示七档复盘评语；下次可选择原预算或本次最终支出作为可编辑的新计划。
- 主动导出 JSON 备份，并预览后合并或替换导入。合并时保留本机同 ID 旅程；替换会覆盖全部本机记录。

## 产品边界

- Flutter，iOS / Android
- 本地 Application Support 文件持久化
- 备份文件由用户选择保存位置；无自动云同步
- 无账号、后台、广告或分析 SDK
- 手填汇率可按旅程复用，不依赖在线汇率
- 中文和英文
- 隐私页可加载在线 HTTPS 政策；旅程的规划、记账与复盘仍可离线使用
- iOS、Android 图标共用 [`assets/brand/app_icon.svg`](assets/brand/app_icon.svg)；调整后运行 `bash tool/generate_app_icons.sh` 更新各尺寸资源

## 在线隐私政策地址

应用默认按当前语言加载已发布的[中文隐私政策](https://gotripdelta.com/privacy.html?lang=zh)或[英文隐私政策](https://gotripdelta.com/privacy.html?lang=en)。构建时仍可用 `--dart-define=TRIP_DELTA_PRIVACY_URL=<HTTPS 地址>` 覆盖共同网址，或用 `TRIP_DELTA_PRIVACY_URL_ZH`、`TRIP_DELTA_PRIVACY_URL_EN` 分别覆盖；只接受 HTTPS。在线加载失败会显示本地数据摘要，并提供重试；回到应用时也会再试一次。

## 本地验证

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --release --no-codesign
flutter build apk --debug
```

当前 iOS Bundle ID 与 Android 包名均为 `com.tripdelta.lite`。隐私政策已公开并接入应用；支持 URL、品牌权利核验、iOS 签名和真机验证等上架事项仍待处理。历史预检报告针对旧工件，需对最终签名构建重跑。详见 [`docs/release/APP_STORE_PREFLIGHT.md`](docs/release/APP_STORE_PREFLIGHT.md)。
