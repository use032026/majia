# ASTFX 新版上架素材包

应用目录：`apps/cleantrail/cleantrail`（原 CleanTrail，当前显示品牌 ASTFX）。素材生成日期：2026-10-27；配置更新日期：2026-10-28。

## 交付内容

- App Store：中英文各 4 张 iPhone 和 4 张 iPad 截图，共 16 张；iPhone 1206×2622，iPad 2064×2752，全部 RGB。
- Google Play：中英文各 4 张 Android 手机截图，共 8 张，1080×1920 RGB；另有中英文 1024×500 RGB feature graphic、512×512 RGBA 商店图标。
- 原始素材：真实 iOS／Android 运行界面、Android 界面层级 XML、来源与 SHA-256 记录。
- 文案：两店共用英文完整描述、Apple 关键词、Play 英文短描述，以及不启用上传的元数据草稿。
- 官网与隐私政策：`website/` 下完整中英文 HTML/CSS/JS；语言可切换并保留；包含当前图标和新采集的真实界面。
- 校验：`QA_REPORT.md`、`DELIVERY_SUMMARY.json`、`FACTS_EVIDENCE.md`、`image-review.json`、`web-qa/`。

## 校验结论

描述 2464 字符，Apple 关键词 94 UTF-8 字节，Play 短描述 78 字符。图片格式、尺寸、数量、双语正文和语言切换通过；各平台使用各自真实运行截图。

2026-10-28 用户已确认：运营主体为独立开发者，支持与隐私邮箱为 evwascr0317@icloud.com，政策生效日为 2026-10-28，iOS/Android 包标识为 `com.astfx.lite`。上述值已同步到原生配置、元数据和中英文网站/政策。正式域名已回填为 `https://astfx1.com`，中英文隐私政策分别为 `/privacy.html?lang=zh` 和 `/privacy.html?lang=en`。应用默认加载该政策并按当前语言选择版本，仍支持 `PRIVACY_POLICY_URL` 覆盖。最新素材门禁结论见 `QA_REPORT.md`；其余发布前事项见 `OPEN_ITEMS.md`。

本次完成配置回填、公开链接及语言核对，并运行聚焦的隐私政策/菜单自动化测试；没有为新包标识制作原生安装包或做真机验证。新验证记录位于 `../privacy-domain-20261028/`。既有图片检查、移动端布局检查和下方清理记录属于 2026-10-27 素材生成任务。

## 本地预览

在应用目录执行 `python3 -m http.server 8417 --bind 127.0.0.1 --directory website`，浏览 `http://127.0.0.1:8417/index.html?lang=en` 或 `?lang=zh`，隐私页为 `privacy.html`。

没有部署官网、上传两店、操作商店账号、制作分发签名包、上传 IPA/AAB、处理/TestFlight/内部测试或提交审核；没有真机验证或法律审核。仅为了真实 Android 界面采集构建了本地调试版本，iOS 复用现有模拟器应用。

历史 `docs/release/` 素材保留为旧版记录；本次以 `release-kit.yml` 和 `artifacts/` 新包为准，不使用历史 CleanTrail 图标或截图。

## 本次收尾

已删除 44 个闲置 Android 编译中间目录，估算 445.62 MiB；6052 个源码、依赖和保留产物内容哈希未变，原暂存内容未变。保留 iOS 模拟器应用、Android 调试 APK、框架、依赖及混合产物目录。已停止本次临时网页预览服务和专用 Android 模拟器，保留已有模拟器。详见 `CLEANUP_REPORT.json`。

历史交付压缩包：`artifacts/ASTFX-release-kit-20261027.zip`；同目录 `.zip.sha256` 可核对完整性，`ASSET_INVENTORY.json` 对应该历史包。该包及 `web-qa/` 截图未随 2026-10-28 配置更新重新生成，可能仍显示旧联系方式和日期；更新后的配置以当前 `release-kit.yml`、网站源文件和元数据为准。
