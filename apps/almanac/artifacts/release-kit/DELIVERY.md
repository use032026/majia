# Deynu 双商店上架素材

更新日期：2026-10-19。对应应用：Deynu 1.0.0 (1)，标识 `com.almanac.lite`。

本次已重新编写英文商店文案，并从当前 Deynu 的 iOS / Android 应用补拍界面，重新生成全部 15 张商店截图与宣传图。下列路径均相对于 `apps/almanac`；压缩包保留相同目录结构。

## 文案对应关系

| 商店字段 | 文件 | 实际长度 |
| --- | --- | --- |
| App Store 名称 | `artifacts/app-store-listing/name-en.txt` | 5 字符 |
| App Store 副标题 | `artifacts/app-store-listing/subtitle-en.txt` | 26 字符 |
| App Store 宣传文本 | `artifacts/app-store-listing/promotional-text-en.txt` | 137 字符 |
| App Store 关键词 | `artifacts/app-store-listing/keywords-en.txt` | 94 UTF-8 字节 |
| 两家商店共用的完整英文描述 | `artifacts/app-store-listing/description-en.txt` | 1411 字符 |
| Google Play 名称 | `artifacts/google-play-listing/name-en.txt` | 5 字符 |
| Google Play 简短描述 | `artifacts/google-play-listing/short-description-en.txt` | 66 字符 |
| Google Play 搜索词参考 | `artifacts/google-play-listing/search-terms-en.txt` | 仅供文案规划 |

Google Play 没有独立的关键词填写栏。搜索词参考文件用于检查名称、简短描述和完整描述的主题覆盖，不要把词表单独粘贴到描述中。完整描述只保留一份来源，避免两家商店的内容发生偏差。

文案围绕已实现的短诗、宜忌选择、意图、收笺、回看、本地笺册和 Markdown 复制功能展开。英文名称统一为 Deynu。

## 上传图片

| 用途 | 成品目录或文件 | 数量与规格 |
| --- | --- | --- |
| App Store iPhone 英文截图 | `artifacts/app-store-previews/final/en-US/iphone/` | 3 张，1206 × 2622，RGB |
| App Store iPad 英文截图 | `artifacts/app-store-previews/final/en-US/ipad/` | 2 张，2064 × 2752，RGB |
| App Store 图标 | `artifacts/app-store-previews/icon-1024.png` | 1024 × 1024，RGB |
| Google Play 英文手机截图 | `artifacts/google-play-listing/final/en-US/phone/` | 4 张，1080 × 1920，RGB |
| Google Play 简体中文手机截图 | `artifacts/google-play-listing/final/zh-CN/phone/` | 4 张，1080 × 1920，RGB |
| Google Play 英文宣传图 | `artifacts/google-play-listing/final/feature-graphic-en.png` | 1024 × 500，RGB |
| Google Play 中文宣传图 | `artifacts/google-play-listing/final/feature-graphic-zh.png` | 1024 × 500，RGB |
| Google Play 图标 | `artifacts/google-play-listing/icon-512.png` | 512 × 512，RGBA |

按文件名中的序号上传截图。Play 的中文第三张现在是 `03-reflect.png`，旧的 `03-sealed.png` 已移除。两个图标沿用应用现有的纸笺与朱印图形，其中没有旧名称文字。

`final/` 是商店成品；`source/` 是未经改字的原始运行截图；`qa/` 中的接触表用于整组查看，不作为商店截图上传。Play 图片替代文本位于 `artifacts/google-play-listing/alt-text.tsv`。

## 校验与来源

- 标准素材校验：17 项通过，0 错误、0 警告，见 `artifacts/release-kit/QA_REPORT.md`。
- 15 张成品均经过视觉检查和品牌 OCR 检查，检测到 Deynu，未检出旧品牌词；报告为 `branding-checks.json`。
- 文案长度、图片尺寸、颜色模式、文件关联、哈希和源码保护检查见 `material-checks.json`。
- iOS 26.5 模拟器及 Pixel 7 API 35 模拟器的真实界面来源、演示数据和 Android 本地截图入口说明见 `SOURCE_REGISTER.md`；逐图哈希见 `capture-provenance.json`。
- 官网和隐私页的中英文切换已在本地验证，官网两张 Deynu 预览图保持上一轮更新结果。

## 交付范围

本次生成和校验本地素材，未上传商店、部署官网、创建签名发布包或提交审核。正式签名版本、真机表现、商店隐私表及运营者法定名称等发布检查见 `artifacts/release-kit/OPEN_ITEMS.md`。

素材包包含当前文案、成品、原始截图、图标、排版配置和校验记录，不包含测试安装包、截图辅助入口、个人记录或历史旧品牌图片。目录名称、应用标识和现有官网域名保持原值。
