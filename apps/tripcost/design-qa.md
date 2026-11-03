> 历史视觉验收档案：以下记录、截图路径和 TripCost/RoamSum 旧名称反映各次验收时的状态。2026-11-03 起当前应用名为 RhinoSmart，App Icon 已更新；保留本文原始证据不表示新品牌已经完成相同运行验收。

# Design QA — 首页汇率与手动汇率面板

## 对照范围

- 设计来源：`/Users/starburst/.codex/generated_images/01a018a0-9d3b-7663-90d0-70ab2e279c4e/exec-03ae4b64-3c40-4e61-8feb-afe23eef9258.png`
- 首页实机截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a018a0-9d3b-7663-90d0-70ab2e279c4e/tripcost-home-implemented.png`
- 面板实机截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a018a0-9d3b-7663-90d0-70ab2e279c4e/tripcost-rate-sheet-manual-comparison.png`
- 同画面对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a018a0-9d3b-7663-90d0-70ab2e279c4e/design-qa-comparison.png`
- 运行视口：iPhone 17，iOS 26.5，402 × 874 logical px，截图 1206 × 2622 px（@3x）。
- 设计稿为 1706 × 922 的双画板概念图，并非同尺寸设备截图，因此按信息层级、间距、状态和交互做视觉对照，不伪造逐像素一致性。

## 验证状态

- 首页：当前汇率、汇率来源、更新时间及“调整”入口均已进入换算主卡片；“当地价格或算式”与输入框之间保留 8pt 间距。
- 手动汇率：底部面板同时展示接口参考汇率和手动输入，手动值 `6.7000` 时展示“比接口参考汇率低 0.56%”。
- 恢复接口汇率：面板提供独立的“改用接口参考汇率”操作；控制器测试确认会清除手动汇率并重新发布市场汇率。
- 状态辨识：选择状态同时使用勾选图标和文字，不依赖颜色单独传意；保存按钮只在输入有效时可用。

## 视觉审查

| 表面 | 结果 | 说明 |
| --- | --- | --- |
| 字体与层级 | 通过 | 标题、币种、换算结果、来源和操作层级与设计方向一致，沿用系统字体以保持原生可读性。 |
| 间距与布局 | 通过 | 已按评论增加输入标题与输入框间距；主卡片、按钮组及面板安全区无挤压或截断。 |
| 颜色与状态 | 通过 | 延续现有蓝色主操作、浅灰背景和白色卡片；选中态清晰，蒙层层级正确。 |
| 图片与图标 | 通过 | 没有新增位图资产；使用现有 Cupertino 图标体系，未引入风格不一致的资源。 |
| 文案与数据 | 通过 | 页面及面板文案与设计意图一致；接口汇率和时间来自运行时数据，因此数值与静态设计稿不同。 |

## 迭代记录

1. 首次运行截图发现面板的来源时间容易换行，且打开面板时选择态没有直接落在手动输入上。
2. 将面板时间改为紧凑格式，并让“调整”入口默认进入手动选择态；随后重新构建、安装、启动并截图复核。
3. 最终对照中没有 P0、P1 或 P2 问题。可接受的 P3 差异仅包括原生状态栏/安全区、动态汇率与时间，以及手动输入在用户录入前为空。

## 交互与工程证据

- Widget 测试覆盖：打开底部面板、录入手动汇率、显示差异、保存、再次打开并切回接口参考汇率。
- Controller 测试覆盖：手动汇率生效后可加载市场参考值，并可清除手动汇率回到市场汇率。
- 聚焦测试 15 项全部通过；相关文件 `flutter analyze` 无问题。
- iPhone 17 / iOS 26.5 模拟器完成 Debug 构建、安装、启动和实机截图。
- 原生 Flutter 页面不适用浏览器控制台检查；运行期间未见布局溢出或可见异常。

final result: passed

---

# Design QA — 设置页二级分类重设计（2026-08-20）

## 对照范围

- 视觉真值：`/Users/starburst/.codex/generated_images/01a01d49-ca4e-7c42-a6ed-0f4366ae2816/exec-dc2df632-c053-4258-95be-b29b750cd24b.png`，853 × 1844 px；设计目标为 390 × 844 logical px。
- iOS Simulator 实现截图：`/Users/starburst/TripCost/artifacts/settings-redesign-iphone17.png`，1206 × 2622 px；iPhone 17 / iOS 26.5，402 × 874 logical px，@3x，浅色模式、简体中文。
- 同画面对照：`/Users/starburst/TripCost/artifacts/settings-redesign-comparison.png`，2412 × 2622 px；视觉稿轻微等比差异归一到 1206 × 2622 后与 Simulator 截图并排。
- 状态：一级设置目录，默认本位币 CNY、每 6 小时刷新、iCloud 同步关闭、语言跟随系统。
- iOS 状态栏和 Dynamic Island 属于设备运行时基础设施；视觉稿未包含这些区域，本次只对 app 自有导航、内容和底部栏做一致性判断。

## 视觉审查

| 表面 | 结果 | 说明 |
| --- | --- | --- |
| 信息架构 | 通过 | 一级页仅保留“支付方式、货币与汇率、iCloud 同步、数据、备份与导出、语言、隐私与关于”六个分类；原有开关、选择器和数据动作均移至对应二级页。 |
| 字体与层级 | 通过 | 导航标题、分组标题、分类主标题和灰色状态摘要形成与图 2 一致的四级层次；运行时使用系统 Cupertino 字体，没有截断。 |
| 间距与布局 | 通过 | 三组白色圆角列表、组间 26pt 间距、78pt 以上分类行和底部导航均完整落在 iPhone 17 视口内；没有溢出、遮挡或手势区挤压。 |
| 颜色与令牌 | 通过 | 使用现有 `#2D7AFF`、`#F2F2F7`、系统 grouped surface、secondaryLabel 和 separator；未引入新色板、渐变或阴影。 |
| 图片与图标 | 通过 | 页面无位图资产；全部使用现有 Cupertino 线性图标。数据入口使用最接近语义的 `archivebox`，属于可接受的 P3 图标差异。 |
| 文案与内容 | 通过 | 图 2 的分类、摘要和当前状态已完整本地化；中英文 ARB 及生成类键值一致。 |
| 交互与可访问性 | 通过 | 分类入口具有按钮语义；Widget 测试验证货币、数据二级页导航、共享币种选择器及 2× 大字体滚动可达。二级页通过 root Navigator 覆盖自定义底部栏。 |

## 对比历史

1. 首次 Simulator 全画面对照即确认分类顺序、分组、摘要、主蓝图标、圆角表面和底部导航与图 2 方向一致，没有发现 P0、P1 或 P2。
2. 全画面对照中所有标题、摘要、图标、分隔关系和底部栏均清晰可读，因此不需要额外聚焦裁切。
3. 可接受的 P3 差异是 iPhone 17 原生状态栏、402 × 874 与概念稿 390 × 844 的设备尺寸差异、系统字体栅格，以及数据入口使用 Cupertino `archivebox` 而非概念稿数据库圆柱图标。

## 工程与运行证据

- 完整 `flutter analyze` 无问题。
- 完整 `flutter test` 225 项通过；1 项 Frankfurter 联网冒烟测试按配置跳过。
- 设置页聚焦测试覆盖一级页隐藏详细控件、进入货币/数据二级页、尾部箭头对齐、共享币种目录、语义标签和 2× 大字体可达。
- iPhone 17 / iOS 26.5 Simulator 完成 Debug 构建、安装、`/settings` 启动和最终截图；运行期间未见可见异常。
- 原生 Flutter 页面不适用浏览器控制台检查；本轮未执行物理设备验证。

final result: passed

---

# Design QA — 手动记账行程与分类双栏级联面板

## 对照范围

- 视觉真值：`/Users/starburst/.codex/generated_images/01a01d3a-b4ad-7ac3-b516-45afb67e1e97/exec-d182866d-8081-4dc0-86bb-d77b2df3b5de.png`，853 × 1844 px；设计目标为 390 × 844 logical px。
- 最终 iOS Simulator 截图：`/Users/starburst/TripCost/artifacts/design-qa/expense-context-picker-simulator-v3.png`，1206 × 2622 px（iPhone 17，iOS 26.5，402 × 874 logical px，@3x）。
- 行程列表状态截图：`/Users/starburst/TripCost/artifacts/design-qa/expense-context-picker-trip-list-simulator.png`，1206 × 2622 px。
- 密度归一截图：`/Users/starburst/TripCost/artifacts/design-qa/expense-context-picker-simulator-v3-normalized.png`，853 × 1844 px。
- 全画面对照：`/Users/starburst/TripCost/artifacts/design-qa/expense-context-picker-comparison.png`，1706 × 1844 px。
- 面板聚焦对照：`/Users/starburst/TripCost/artifacts/design-qa/expense-context-picker-sheet-comparison.png`；左右保留各自纵横比并顶部对齐，避免把 iPhone 17 底部安全区强行压缩成概念稿比例。
- 状态：简体中文、浅色模式、手动记账页上叠加底部面板；分类态选中“购物”，行程态选中“无”。

## 视觉审查

| 表面 | 结果 | 说明 |
| --- | --- | --- |
| 字体与层级 | 通过 | 标题、当前组合摘要、左栏主/次标签、右栏选项和“完成”按钮形成与图 2 一致的层级；实现沿用 Cupertino 系统字体和原生字重。 |
| 间距与布局 | 通过 | 面板约占 iPhone 17 视口 57%，28pt 顶部圆角、拖拽条、左右分栏和底部安全区完整；六个分类与“无 + 3 个行程”均可见，无裁切、溢出或遮挡。 |
| 颜色与令牌 | 通过 | 使用现有 `#2D7AFF`、系统分组背景、secondaryLabel 和 separator；左栏选中态为浅蓝底与 4pt 蓝色指示条。 |
| 图片与图标 | 通过 | 面板没有图片资产；分类使用现有 Material/Cupertino 图标库，餐饮、交通、购物、住宿、门票、其他分别使用橙、青、蓝、紫、玫红和灰色语义色。 |
| 文案与内容 | 通过 | “行程与分类”“行程”“分类”“无”“餐饮/交通/购物/住宿/门票/其他”“完成”均来自现有本地化；头部和左栏实时回显当前组合。 |
| 交互与可访问性 | 通过 | 左栏切换右侧列表，选择先暂存；关闭或点遮罩不写入，点击“完成”才一次提交。选项至少 50pt、侧栏至少 76pt，选中态同时使用文字、颜色和勾选。 |

## 对比迭代记录

1. 首次 Simulator 对照（`expense-context-picker-simulator.png`）发现 P1：关闭按钮缺少横向约束，视觉上压到标题；P2：左栏选中背景未铺满列宽；P2：64% 面板高度明显高于图 2。
2. 将面板高度收敛到 57%，左栏按钮强制铺满 118pt 列宽，分类行收敛到 50pt，并将交通图标调整为更贴近图 2 的公交轮廓。
3. 第二次截图（`expense-context-picker-simulator-v2.png`）确认左栏和高度已修正，但标题区域自身仍按内容宽度布局，关闭按钮继续落在标题附近。
4. 标题容器改为完整面板宽度并重新采集 `expense-context-picker-simulator-v3.png`；关闭按钮稳定在右上角，分类态没有剩余 P0、P1 或 P2。
5. 另采集行程态，确认“无”“北京周末”“东京之旅”“欧洲夏季行程”均完整显示。可接受的 P3 差异是 iPhone 17 原生状态栏/安全区、402 × 874 与概念稿 390 × 844 的设备尺寸差异，以及系统字体栅格比 ImageGen 概念稿略大。

## 工程证据与缺口

- `test/features/expense/presentation/ledger_page_test.dart` 共 21 项通过；新增用例覆盖默认分类态、分类图标、50pt 行高、左右级联、关闭丢弃暂存值及“完成”一次提交。
- 费用页与对应测试定向 `flutter analyze` 无问题；`git diff --check` 通过。
- iPhone 17 / iOS 26.5 Simulator 完成临时隔离预览入口 Debug 构建、安装、启动、两种级联状态和最终截图；最终预览入口已移除，未写入生产启动流程。
- 最终 Flutter run 控制台没有可见运行错误；原生 Flutter 页面不适用浏览器控制台检查。
- 未执行物理设备验证，也未把 Simulator 证据表述为真机证据。

final result: passed

---

# Design QA — 扫描记账与 OCR 预填（2026-08-20）

## 对照范围

- 视觉真值：`/Users/starburst/.codex/generated_images/01a01ce3-cf0c-73c1-81ce-4258d08a5f08/exec-a2d02e5b-3750-40e9-9f67-7739787a4dc9.png`，1673 × 940 px，双画板概念稿。
- 记账扫描页：`/Users/starburst/TripCost/artifacts/design-qa/scan-record-simulator.png`，1206 × 2622 px。
- OCR 预填记账页：`/Users/starburst/TripCost/artifacts/design-qa/expense-ocr-prefill-simulator.png`，1206 × 2622 px。
- 归一对照：`/Users/starburst/TripCost/artifacts/design-qa/scan-record-flow-comparison.png`；每行左侧为概念稿，右侧为 iPhone 17 实现。
- 运行视口：iPhone 17，iOS 26.5，402 × 874 logical px，浅色模式、简体中文、@3x。

## 视觉审查

| 表面 | 结果 | 说明 |
| --- | --- | --- |
| 信息架构 | 通过 | 扫描页使用同页“比价 / 记账”切换，没有增加入口弹框；记账模式的标题、说明、图片来源和手动兜底一屏可见。 |
| 层级与间距 | 通过 | 导航、分段控件、说明、插画、双按钮、隐私说明和手动入口保持清晰节奏；iPhone 17 安全区无遮挡或溢出。 |
| OCR 反馈 | 通过 | 记账页顶部明确提示“已从票据填入 4 项，请核对”；商户使用橙色“待确认”，不会误导为自动保存。 |
| 字段覆盖 | 通过 | 商户、交易金额、消费日期和票据附件均进入编辑器；日期移至金额区常显，票据缩略图与更换入口可见。 |
| 颜色与控件 | 通过 | 沿用 TripCost 主蓝、系统灰背景、白色分组卡片和 Cupertino 图标；选中态使用蓝底白字，未引入新色板。 |
| 文案与可访问性 | 通过 | 中英文本地化完整；模式、入口和保存操作均有文字表达，不依赖颜色单独传意，主要触控区域保持至少 44pt。 |

## 工程与交互证据

- OCR 结构化解析覆盖强总计、税费/小计排除、弱置信度和中英文日期；无可识别字段时仍可进入手动记账。
- 扫描入口按上下文选择默认模式：首页/设置默认比价，行程/账本默认记账；行程详情会把当前行程继续交给记账页。
- 票据图片导入应用私有本地目录，预填页显示附件；本轮没有改变原图不上云的边界。
- `flutter analyze` 全项目无问题；OCR、扫描页、记账页和本地化聚焦套件 29 项全部通过；目标文件 `git diff --check` 通过。
- 正常生产入口完成 iOS Simulator Debug 构建、安装和启动。两张验收图使用生产组件的隔离预览状态采集；验收后已移除临时入口并恢复正常生产构建。
- 原生 Flutter 页面不适用浏览器控制台检查。最终对照未发现剩余 P0、P1 或 P2；可接受的 P3 差异为概念画板比例、隔离预览数据及系统状态栏时间不同。

final result: passed

---

# Design QA — 三类日期选择器职责拆分（2026-08-20）

## 对照范围

- 手动记账视觉真值：`/var/folders/6h/fw9ps2896831sdwc108hy6dm0000gn/T/codex-clipboard-e803e3b9-c61b-4b23-9b3c-73216663c87f.png`，1002 × 496 px；目标精度为“年、月、日、时、分、秒”。
- 账本筛选视觉真值：`/var/folders/6h/fw9ps2896831sdwc108hy6dm0000gn/T/codex-clipboard-797aeb91-b185-4653-902c-9e519a8aeea4.png`，987 × 525 px；目标精度为“年、月、日”。
- 行程范围视觉真值：`/var/folders/6h/fw9ps2896831sdwc108hy6dm0000gn/T/codex-clipboard-a528c833-6c1a-4964-b70f-afb4655e5ff7.png`，1660 × 2096 px；目标是同页选择开始与结束日期的连续月历。
- 用户提供的现状证据分别为：`/Users/starburst/Desktop/Simulator Screenshot - iPhone 17 - 2026-08-20 at 09.41.05.png`、`/Users/starburst/Desktop/Simulator Screenshot - iPhone 17 - 2026-08-20 at 09.40.55.png`、`/Users/starburst/Desktop/Simulator Screenshot - iPhone 17 - 2026-08-20 at 09.40.47.png`。
- 手动记账实现截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/manual-date-time-picker-implementation.png`，390 × 844 px。
- 账本筛选实现截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/date-picker-implementation-normalized.png`，852 × 1846 px；本轮组件未再改动，沿用上一轮已通过的当前实现证据。
- 行程范围实现截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/trip-date-range-picker-implementation.png`，390 × 844 px。
- 三种最终状态总览：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/date-picker-final-states.png`，1170 × 844 px。
- 手动记账聚焦同屏对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/manual-date-time-picker-comparison.png`，876 × 470 px；参考控件裁切为 310 × 300 px 后等高归一，Flutter 实现裁切为 390 × 470 px。
- 行程全屏同屏对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/trip-date-range-picker-comparison.png`，780 × 844 px；参考画板裁切为 500 × 900 px、缩放到 390 × 702 px 并补齐到 390 × 844 px，Flutter 实现为 390 × 844 px。
- Flutter 截图使用 390 × 844 logical px、devicePixelRatio 1，并显式加载系统 PingFang 字体；这是 Widget 渲染证据，不表述为 Simulator 或真机证据。

## 状态与视觉审查

| 表面 | 结果 | 说明 |
| --- | --- | --- |
| 信息架构 | 通过 | 手动记账、账本筛选和行程不再复用同一种精度：分别为六列时间、三列日期、双端点月历。 |
| 字体与层级 | 通过 | 三者沿用 Cupertino 系统层级；手动记账的标题、实时摘要和选中行清晰，行程页标题、起止字段、月份标题和日期数字层级明确。 |
| 间距与布局 | 通过 | 六列在 390pt 宽度内没有遮挡或截断，44pt 连续选中带减弱中央拥挤；行程页首屏同时容纳起止字段、星期栏、当前月和下一月。 |
| 颜色与令牌 | 通过 | 使用 TripCost 主蓝、系统背景、secondaryLabel、tertiarySystemFill 和 systemOrange；范围使用低透明度主蓝连接并以实心圆标记端点。 |
| 图片与图标 | 通过 | 三类选择器不依赖图片资产；没有用占位图、手绘 SVG 或字符图标替代视觉稿资产。 |
| 文案与内容 | 通过 | “消费时间”“开始日期/结束日期”“选择日期范围”“取消/完成”均有中英文本地化；手动记账列表值显示到秒。 |
| 交互与可访问性 | 通过 | 手动记账取消不写入、完成返回六字段时间；行程第一次点击重设起点、第二次点击完成终点，终点未选时完成按钮禁用；关键按钮维持至少 44pt 触控区域。 |
| 视口韧性 | 通过 | 390 × 844 截图中没有溢出、裁切、重叠或底部安全区遮挡；滚轮与月份列表均可继续滚动。 |

## 对比迭代记录

1. 初次结构对照确认手动记账六列精度和行程双端点月历均达到参考图的核心交互；未发现 P0/P1。
2. 首次行程截图发现 P2 文案偏差：导航标题仍使用入口文案“整段行程”，参考图使用任务标题“选择日期范围”。新增专用中英文本地化文案并重新渲染。
3. 独立可访问性复核发现 P2：月历日期格原为 42pt，低于项目采用的 44pt 最小触控尺寸；将日期格和行距统一为 44pt，并同步调整月份固定高度后重新渲染。
4. 修正后的手动聚焦对照、行程全屏对照与三状态总览未发现剩余 P0、P1 或 P2。可接受的 P3 差异是网页参考图与原生 Cupertino 字体栅格、滚轮透视淡出、设备纵横比及示例日期不同。

## 工程与交互证据

- 手动记账定向测试通过：验证六个独立滚轮、44pt 全宽选中带、秒值实时摘要及完成后列表显示到秒。
- 账本筛选定向测试通过：验证年月日弹层、开始/结束日期、取消/完成和自定义日期摘要；没有引入时分秒。
- 行程编辑器 4 项测试全部通过：新增用例验证单页范围选择、起点后禁用完成、终点后启用完成及返回后整段日期更新。
- 本地化契约 3 项全部通过；涉及实现、生成本地化类和测试的定向 `flutter analyze` 无问题；目标文件 `git diff --check` 通过。
- 两张 390 × 844 最终 Widget 截图测试通过；原生 Flutter 页面不适用浏览器控制台检查。
- 本轮未执行新的 iOS Simulator 构建、安装或真机验证；用户提供的图 4–6 仅作为改造前现状证据。

## 账本自定义日期范围单弹框复核（2026-08-20）

- 视觉真值：`/var/folders/6h/fw9ps2896831sdwc108hy6dm0000gn/T/codex-clipboard-200033a1-c8fe-4e9b-9d48-978a9d9f5477.png`，339 × 496 px；它是带红色标注的桌面组件参考，核心真值是顶部并列开始/结束日期字段，以及下方共用一个“年、月、日”滚轮。
- Flutter 实现截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/ledger-date-range-picker-implementation.png`，390 × 844 px；Widget 视口 390 × 844 logical px、devicePixelRatio 1、浅色模式、简体中文，状态为默认编辑开始日期。
- 聚焦对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/ledger-date-range-picker-comparison.png`，826 × 466 px。参考组件裁切 293 × 344 px 后归一到 390 × 464 px；实现从完整截图裁切底部 390 × 464 px，左右同高并排比较。该组件没有图片资产，聚焦对照已能清晰检查全部关键控件，无需额外细节裁切。
- 字体与层级：通过。标题“选择日期范围”居中，开始/结束字段标签弱化，日期值和选中滚轮行保持主层级；使用系统中文字体与 Cupertino 原生字号节奏。
- 间距与布局：通过。单个约 55% 屏高的底部弹框容纳标题、两个 56pt 日期字段和共享滚轮，水平内边距 16pt，选中带 44pt；无内容挤压、截断或安全区遮挡。
- 颜色与令牌：通过。主操作、当前字段描边使用 TripCost 主蓝，字段背景与选中带使用系统填充色，未依赖颜色单独表达字段含义。
- 图片与图标：通过。参考和实现均不需要图片或自定义图标；拖拽条、圆角和原生滚轮均由现有 Cupertino 组件绘制。
- 文案与内容：通过。新增中英文“选择日期范围 / Select date range”，并保留“开始日期 / 结束日期”“取消 / 完成”；只显示年月日，不引入时分秒。
- 交互与可访问性：通过。点击两个顶部字段在同一弹框内切换滚轮目标；开始日期变化会抬高结束日期下限，并在必要时同步结束日期；一次“完成”返回整段范围，“取消”不覆盖原值，日期字段维持至少 56pt 触控高度。
- 比较历史：首轮实现截图发现视觉测试主题缺少完整 Cupertino 字体颜色，造成标题和选中行在截图中不可见；补齐测试渲染字体样式，同时为弹框标题显式使用语义标签色后重新截图。第二轮并排对照未发现剩余 P0、P1 或 P2。可接受的 P3 差异是参考图带桌面标题栏、关闭/清空操作与红色注释，而移动端沿用现有底部弹框的拖拽条、取消和主色完成按钮。
- 工程证据：账本页面完整 17 项 Widget 测试通过，其中日期范围用例验证单弹框、两个字段、单个三列滚轮、结束日期下限、一次完成和取消保持原值；本地化契约 3 项通过；聚焦 `flutter analyze` 无问题。未执行新的 iOS Simulator 构建或真机验证，因此截图仅作为 Widget 渲染证据。

final result: passed

---

# Design QA — 行程列表与多国路线编辑

## 对照范围

- 设计来源：`/Users/starburst/.codex/generated_images/01a0197c-7287-7e01-8fe2-6387173ebe09/exec-cc09493e-d53b-45a0-afdd-ba7e12c50be1.png`，1701 × 925 px，横向双画板概念稿。
- 行程页最终截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a0197c-7287-7e01-8fe2-6387173ebe09/tripcost-trips-list-final.png`。
- 双站点编辑页最终截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a0197c-7287-7e01-8fe2-6387173ebe09/tripcost-trip-editor-final.png`。
- 最终同画面对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a0197c-7287-7e01-8fe2-6387173ebe09/trip-design-comparison-final.png`。
- 运行视口：iPhone 17，iOS 26.5，402 × 874 logical px，截图 1206 × 2622 px（@3x）。概念稿单画板比真实设备更宽，因此以信息层级、相对间距、状态、颜色和交互结构为验收基准。
- 运行状态：简体中文、浅色模式；当前行程为日本与韩国 10 天，预算 CNY 20,000，已消费 CNY 2,497.40；另有一条即将开始的大阪周末行程。示例数据只写入 Simulator 隔离容器。

## 视觉审查

| 表面 | 结果 | 说明 |
| --- | --- | --- |
| 字体与层级 | 通过 | 页面标题、行程名称、站点、预算指标和辅助说明使用 Cupertino 系统层级；主次关系与图 1 一致。 |
| 间距与布局 | 通过 | 顶部导航、分段控件、行程卡、底部导航和编辑页滚动安全区均无溢出、遮挡或截断。 |
| 颜色与状态 | 通过 | 品牌蓝用于主操作和当前站，绿色用于进行中，辅助信息使用系统灰；预算进度同时有数字与进度条。 |
| 图标与控件 | 通过 | 行李、地点、时钟、预算、拖拽、编辑和箭头全部使用 Cupertino 图标；“记一笔”按图 1 增加蓝色描边。 |
| 内容与多国状态 | 通过 | 行程页展示有序路线、各站日期/币种、当前站与下一站、整趟预算和即将开始；编辑页展示双站点、拖拽排序、整段日期、预算、人数和折叠设置。 |

## 对比迭代记录

1. 设计对照确认原模型只有目的地集合，没有路线顺序和分段日期；实现有序停留段，并以数据库 v6 字段持久化国家/地区、起止日期和当地币种。
2. 首轮 Simulator 复核后，历史分段文案由“历史行程”收敛为图 1 的“历史”，次操作按钮补齐蓝色描边。
3. 最终把概念稿两个画板与 iPhone 17 两张实现截图放入同一比较图复核；未发现剩余 P0、P1 或 P2。可接受的 P3 差异是概念稿使用城市名而现有产品目的地粒度为国家/地区，以及真实设备比概念画板更窄导致“更多设置”摘要末尾省略。

## 交互与工程证据

- 新建/编辑页支持逐站添加、拖拽排序、修改目的地、修改单站币种、调整相邻站分界日期、删除站点、调整整段日期和保存。
- 旧行程读取时会按原有目的地与币种生成兼容停留段；v5 升 v6 的 `route_stops_json` 默认值经迁移测试验证为 `[]`。
- 仓储测试验证日本 → 韩国顺序、分段日期和 JPY/KRW 往返持久化；同步层继续接受 v1 记录并以 v2 输出新字段。
- 完整 `flutter analyze` 无问题；完整测试 202 项通过，1 项需联网的 Frankfurter smoke test按设计跳过。
- iPhone 17 / iOS 26.5 Simulator 完成最终 Debug 构建、安装、启动、双状态加载和截图；原生 Flutter 页面不适用浏览器控制台检查。

final result: passed

---

# Design QA — 扫描价格页与金额确认底部面板

## 对照范围

- 扫描前定稿：`/Users/starburst/.codex/generated_images/01a0197d-c4f1-79a0-a9f7-8acf11191b11/exec-dc2c0f70-c5e7-4707-bf6f-7fd6b790a2ef.png`。
- 识别后定稿：`/Users/starburst/.codex/generated_images/01a0197d-c4f1-79a0-a9f7-8acf11191b11/exec-ac8f8bb7-c146-451c-b703-b3cc0c7a4ebc.png`。
- 扫描前实现截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a0197d-c4f1-79a0-a9f7-8acf11191b11/scan-before-manual-implementation.png`，1170 × 2532 px。
- 识别后实现截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a0197d-c4f1-79a0-a9f7-8acf11191b11/scan-after-edit-implementation.png`，1170 × 2532 px。
- 同尺寸并排对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a0197d-c4f1-79a0-a9f7-8acf11191b11/scan-before-comparison.png` 与 `scan-after-comparison.png`，左右均归一为 390 × 844 px。
- 状态：简体中文、浅色模式；扫描前弹框输入 JPY 1,280；识别后使用收据夹具并打开“确认价格”编辑面板。
- Flutter 渲染使用 390 × 844 logical px、@3x，并显式加载可读中文字体与 Cupertino 图标字体；收据夹具仅用于同场景视觉验收，不进入产品代码或资产目录。

## 视觉审查

| 表面 | 结果 | 说明 |
| --- | --- | --- |
| 页面层级 | 通过 | 扫描前由说明、插画、拍照/相册入口、隐私说明和手动输入行组成；识别后切换为图片、候选价格列表与可编辑入口。 |
| 底部面板 | 通过 | 手动输入与识别结果编辑复用同一底部面板，包含拖拽条、标题/副标题、金额、交易币种、取消和“保存并使用”。 |
| 间距与布局 | 通过 | 面板使用 24pt 顶部圆角并收敛输入区、币种行和底部按钮高度；390 × 844 视口无横向溢出或按钮截断。 |
| 颜色与状态 | 通过 | 延续 TripCost 蓝色主操作、系统灰背景、白色面板和细边框；选中 OCR 区域使用绿色框，不依赖颜色单独表达选择结果。 |
| 图片与图标 | 通过 | 扫描前复用现有扫描插画；相机、相册、键盘、关闭、铅笔和箭头均使用 Cupertino 图标。 |
| 文案与数据 | 通过 | 扫描说明改为定稿中的紧凑文案；识别数量、本地处理说明、手动输入提示和面板操作均已中英文覆盖。 |

## 对比迭代记录

1. 首次渲染对照发现扫描说明过长而换成两行，导致插画与手动输入入口下移；文案收敛为“拍下价签或账单，确认价格后再比较支付方式”。
2. 首次面板比定稿高约 50 logical px；收紧金额输入内边距、币种行和按钮垂直间距后，面板顶部与定稿的半屏位置一致。
3. 视觉测试环境最初未加载插画和 Cupertino 图标字体；补充图片预解码及图标字体后重新采集，最终并排图中的图片、图标与中文均正常。
4. 最终对照未发现剩余 P0、P1 或 P2。可接受的 P3 差异包括 Widget 渲染环境不显示真实 iOS 状态栏/返回按钮、测试字体栅格与 ImageGen 概念稿略有差异，以及识别后示例候选数量不同。

## 交互与工程证据

- 扫描页 5 项 Widget 测试通过：覆盖扫描前全部入口、底部面板结构、低置信度编辑、多价格求和、权限拒绝回退和无识别结果时手动录入。
- 本地化契约 3 项通过，中英文 ARB 保持键值一致。
- 扫描页与对应测试的聚焦 `flutter analyze` 无问题；`git diff --check` 通过。
- 视觉证据来自真实 Flutter 控件渲染；原生 Flutter 页面不适用浏览器控制台检查。
- 本轮未执行 iOS Simulator 构建、安装或真机验证，因此不把 Widget 截图表述为 Simulator/设备证据。

## 币种尾部对齐复核（2026-08-20）

- 问题截图：`/var/folders/6h/fw9ps2896831sdwc108hy6dm0000gn/T/codex-clipboard-4e48b0ec-812a-4a90-84f2-f437881bef42.png`，1206 × 2622 px；币种值和箭头停在行中部。
- 修正后 Flutter 截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a0197d-c4f1-79a0-a9f7-8acf11191b11/scan-currency-alignment-fixed.png`，1170 × 2532 px（390 × 844 logical px，@3x）。
- 聚焦对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a0197d-c4f1-79a0-a9f7-8acf11191b11/scan-currency-alignment-comparison.png`，左侧为问题状态、右侧为修正状态；两侧币种行裁切后归一为 555 × 130 px。
- P2 历史：`CupertinoButton` 内部行没有获得完整卡片宽度，`Flexible` 的值区域又使用起始对齐，造成值和箭头没有贴右。修正为明确的全宽 50pt 行，并使用 3:2 弹性分栏及 `TextAlign.end`。
- 五项复核：字体与字号未变；币种值和箭头贴右且保持 8pt 间距；颜色、边框和圆角令牌未变；插画与图标资源未变；“交易币种 / 选择币种”文案未变。没有新增 P0/P1/P2。
- 回归断言验证箭头距卡片右边为 14 ± 1 logical px、值与箭头间距为 8 ± 1 logical px，并确认值使用尾部对齐；扫描页 5 项测试和聚焦 `flutter analyze` 均通过。

final result: passed

---

# Design QA — 手动记账重设计

## 对照范围

- 确认视觉稿：`/Users/starburst/.codex/generated_images/01a01960-a99a-7503-a6ad-5ac95215065b/exec-939f6a2b-3963-400b-ab45-54a3e84cada9.png`，853 × 1844 px。
- iOS Simulator 截图：`/Users/starburst/TripCost/artifacts/design-qa/manual-expense-editor-simulator.png`，1206 × 2622 px（iPhone 17，iOS 26.5，402 × 874 logical px，@3x）。
- 密度归一截图：`/Users/starburst/TripCost/artifacts/design-qa/manual-expense-editor-simulator-853x1844.png`，853 × 1844 px。
- 同状态并排对照：`/Users/starburst/TripCost/artifacts/design-qa/manual-expense-editor-comparison.png`，1706 × 1844 px。
- 状态：简体中文、浅色模式、JPY 12,800、CNY 实时换算、默认银行卡、待入账、已有票据缩略图、缺少商户名称并显示导航栏下校验 Toast。

## 视觉审查

| 表面 | 结果 | 说明 |
| --- | --- | --- |
| 页面层级 | 通过 | 基本信息、金额、支付与状态、附加费用、票据、备注与预算沿用确认稿的分组顺序；iOS 26 上使用系统分组底色、白色圆角卡片和细边框，层级不再被背景吃掉。 |
| 金额反馈 | 通过 | “交易金额—参考换算—预计最终”同卡展示；预计值使用 TripCost 蓝色和粗体，输入、行程、币种、支付方式与附加费用变化都会重算。 |
| Toast | 通过 | 必填提示位于导航栏下方，使用浅红背景、细红边、圆形感叹号和短文案“还需填写商户名称和交易金额”；不再占用页面底部。 |
| 票据 | 通过 | 附件以实际图片缩略图、移除按钮和添加/更换入口展示；页面不暴露本地文件路径。 |
| 键盘 | 通过 | 数字键盘提供上一项、下一项、完成工具条；页面滚动或全应用空白区域点击可收起键盘，导航与列表不随键盘错误位移。 |
| 可访问性 | 通过 | 可操作行保持至少 44pt 触控高度；状态同时用文字表达，Toast 不依赖颜色单独传意。 |

## 对比迭代记录

1. 首次同尺寸对照发现 iOS 26 的白色页面背景使分组卡片边界消失，同时默认 52pt 行高让首屏信息密度低于确认稿。
2. 页面改用 `systemGroupedBackground`，卡片增加 0.5pt 系统分隔色边框，并将常规行收敛到 44–48pt 可触控范围。
3. 将金额标签收敛为“交易金额 / 参考换算 / 预计最终”，并把必填校验提前到保存入口，使 Toast 即时出现；随后使用临时预览入口周期触发真实保存动作，采集与视觉稿相同的 Toast 状态复核。
4. 最终对照没有剩余 P0、P1 或 P2。可接受的 P3 差异包括原生状态栏与 Debug 标记、隔离预览中的英文示例支付方式/插画票据，以及系统字体栅格与 ImageGen 概念稿的轻微度量差异。

## 工程证据与当前缺口

- 手动记账页 15 项测试通过，覆盖实时金额联动、已入账保存、顶部 Toast、键盘工具条、票据图片预览与路径隐藏。
- 本地化契约 3 项通过；共享键盘空白点击收起测试通过。
- 本次涉及的手动记账页、键盘组件和测试隔离 `flutter analyze` 无问题。
- iPhone 17 / iOS 26.5 Simulator 完成临时预览入口 Debug 构建、安装、启动和同状态截图；此前生产入口 iOS Simulator 构建已成功。
- 当前全项目 `flutter analyze` 被并行中的 `scan_page.dart` 未完成私有组件与文案定义打断（12 项）；随后并行 Drift 行程字段 `routeStopsJson` 与尚未刷新的生成文件也会阻断全量测试编译。两处均与本次手动记账改动无关，未越界修复或覆盖。

final result: passed

---

# Design QA — 账本自定义日期舒展滚轮

## 对照范围

- 视觉真值：`/Users/starburst/.codex/generated_images/01a01973-8268-7f42-bc7e-bc2b0d2079e6/exec-7751c2eb-35d6-4de4-a958-45e592f7149a.png`，852 × 1846 px。
- Flutter 渲染截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/date-picker-implementation.png`，1170 × 2532 px（390 × 844 logical px，@3x）。
- 密度归一截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/date-picker-implementation-normalized.png`，852 × 1846 px。
- 全画面对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/date-picker-design-comparison.png`，1704 × 1846 px。
- 日期弹框聚焦对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a01973-8268-7f42-bc7e-bc2b0d2079e6/date-picker-focus-comparison.png`，1704 × 926 px。
- 状态：简体中文、浅色模式、账本筛选面板上叠加“开始日期”，选中 2026 年 8 月 19 日。
- 截图使用真实 Flutter 控件和 390 × 844 逻辑视口；测试环境显式加载可读中文字体与 Cupertino 图标字体，未伪造日期控件或使用静态截图替代实现。

## 视觉审查

| 表面 | 结果 | 说明 |
| --- | --- | --- |
| 字体与层级 | 通过 | 取消、标题、完成、日期摘要和滚轮选中值层级与图 1 一致；运行时继续使用 Cupertino 系统字体。 |
| 间距与布局 | 通过 | 弹框约半屏高，顶部圆角、拖拽条、56pt 操作栏、摘要与 44pt 滚轮行形成稳定节奏；无挤压、截断或遮挡。 |
| 颜色与令牌 | 通过 | 使用现有 TripCost 蓝色、系统背景、secondaryLabel 与 tertiarySystemFill，不引入新色板、渐变或阴影。 |
| 图片与图标 | 通过 | 日期弹框没有图片资产和图标需求；所有可见元素均由现有 Cupertino 控件绘制。 |
| 文案与内容 | 通过 | “取消”“开始日期”“完成”和本地化日期摘要完整；摘要会随滚轮选择实时更新。 |
| 交互与可访问性 | 通过 | 取消不写入，完成进入结束日期；按钮保持 Cupertino 触控面积，摘要使用 live region 向辅助功能播报更新。 |

## 对比迭代记录

1. 首次对照发现 P2：弹框按 52% 屏高渲染，比图 1 高约 20 logical px，导致背景筛选区露出偏少。
2. 将高度收敛为屏幕 50%，并限制在 400–440 logical px；同尺寸复核后，弹框顶部位置与图 1 的半屏结构一致。
3. 第二次聚焦对照发现 P2：系统日期选择器的默认选中背景只覆盖内部列宽，仍有“集中在中央”的视觉倾向。
4. 保留原生三列滚轮，关闭分列默认蒙层，增加距左右各 14pt 的连续 44pt 选中带，并强制滚轮区域使用完整可用宽度。
5. 最终全画面和聚焦对照未发现剩余 P0、P1 或 P2。可接受的 P3 差异是 ImageGen 概念稿与 Flutter 字体栅格、滚轮透视淡出和测试字体度量存在细微差别。

## 工程证据与缺口

- 聚焦 Widget 测试通过：覆盖弹框高度、标题、取消/完成、日期摘要、44pt 行高、全宽选中带、开始日期进入结束日期及取消返回。
- 修改文件定向 `flutter analyze` 通过，`git diff --check` 通过。
- 390 × 844、@3x 的 Flutter 可视截图测试通过；原生 Flutter 页面不适用浏览器控制台检查。
- 完整账本测试文件另有 3 个与本次日期弹框无关的并发失败，并卡在收据图片用例；已停止该次无进展运行，未修改这些超出范围的问题。
- 本轮未执行 iOS Simulator 构建、安装或真机验证，因此不把 Widget 渲染证据表述为 Simulator/设备证据。

final result: passed

---

# Design QA — 账本概览与筛选底部面板

## 对照范围

- 设计来源：`/var/folders/6h/fw9ps2896831sdwc108hy6dm0000gn/T/codex-clipboard-caed8f43-0ee4-4763-886e-c5ed40927997.png`
- 账本实机截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a018df-8764-7460-a651-d8e15de4a49f/tripcost-ledger-final.png`
- 筛选实机截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a018df-8764-7460-a651-d8e15de4a49f/tripcost-ledger-filter-final.png`
- 同画面对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a018df-8764-7460-a651-d8e15de4a49f/tripcost-ledger-design-comparison.png`
- 运行视口：iPhone 17，iOS 26.5，402 × 874 logical px，截图 1206 × 2622 px（@3x）。
- 确认稿是横向双画板概念图，画板比例并非目标设备比例；验收以信息层级、相对间距、状态、颜色和交互结构为准。

## 验证状态

- 账本概览：本月支出、记录数、本位币、前三分类占比和金额已形成首屏摘要。
- 明细列表：按本地日期分组，显示行程、分类、原币金额、本位币金额，并明确区分“待入账”“已入账”和退款。
- 筛选面板：改为圆角底部弹框，包含行程、多分类、交易币种、支付方式、状态、快捷日期、自定义日期和金额区间。
- 快捷日期：30 天选中态已按确认稿调整为蓝底白字；底部主按钮实时显示匹配记录数。
- 手动记账：可在保存时直接选择“待入账”或“已入账”；已入账可直接填写实际金额，现金默认已入账。

## 视觉审查

| 表面 | 结果 | 说明 |
| --- | --- | --- |
| 字体与层级 | 通过 | 页面标题、月度总额、分类摘要、日期组和交易金额层级清晰；沿用 Cupertino 系统字体。 |
| 间距与布局 | 通过 | iPhone 17 安全区、底部导航、列表行和底部面板均无溢出、遮挡或截断。 |
| 颜色与状态 | 通过 | 分类使用稳定的橙/蓝/紫色，退款使用绿色；待入账与已入账同时通过文字表达，不依赖颜色。 |
| 图标 | 通过 | 顶部与筛选面板沿用 Cupertino 图标；餐饮和住宿使用 Material 的刀叉、床图标，以贴合确认稿语义和轮廓。 |
| 数据状态 | 通过 | 使用 Simulator 隔离示例数据覆盖餐饮、购物、住宿、退款、待入账和已入账；截图后已清理，未写入项目代码或真实设备数据。 |
| 筛选反馈 | 通过 | 30 天选中态、清除/关闭入口、匹配数量按钮和金额输入层级与确认稿一致。 |

## 迭代记录

1. 首次运行截图确认页面和底部面板结构正确，但快捷日期仍使用系统白色选中块。
2. 将快捷日期选中态改为品牌蓝底、白字，并重新格式化、静态检查、测试、构建、安装与截图。
3. 首次验收后，用户进一步标注了两个 P2 细节：筛选值/箭头未贴右对齐，以及餐饮、住宿、币种和顶部筛选图标与确认稿不一致。
4. 筛选行改用完整宽度的 `CupertinoListTile`，通过 `additionalInfo` 与独立尾部箭头统一右边线；餐饮、住宿改为刀叉与床图标，币种图标会按 JPY/CNY/EUR/GBP/USD 变化，顶部筛选固定使用三横滑杆图标。
5. 使用最终构建重新采集账本与筛选截图；聚焦对照未再发现 P0、P1 或 P2 问题。可接受的 P3 差异仅为运行数据笔数、当前筛选状态、原生状态栏与概念画板比例不同。

## 交互与工程证据

- Widget/逻辑测试覆盖月度筛选、7/30 天与自定义日期、多分类、底部筛选弹框，以及手动记账直接保存为已入账。
- 控制器测试覆盖银行卡实际金额保存时同步生成手续费校准记录。
- 完整 `flutter analyze` 无问题；完整测试 184 项通过，1 项需联网的 Frankfurter smoke test 按设计跳过。
- 最终视觉修正后，相关文件 `flutter analyze` 无问题，聚焦测试 12 项全部通过。
- iPhone 17 / iOS 26.5 Simulator 完成 Debug 构建、安装、启动、交互和双状态截图。
- 原生 Flutter 页面不适用浏览器控制台检查；视觉验收期间未见布局溢出或可见运行异常。

## 细节修正复核（2026-08-19）

- 标注来源：`/Users/starburst/.codex/generated_images/01a018df-8764-7460-a651-d8e15de4a49f/exec-7d667703-066b-403e-a8d6-69595f30f298.png`
- 最终账本截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a018df-8764-7460-a651-d8e15de4a49f/tripcost-ledger-icons-final-2.png`
- 最终筛选截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a018df-8764-7460-a651-d8e15de4a49f/tripcost-ledger-filter-alignment-final-2.png`
- 最终同画面对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a018df-8764-7460-a651-d8e15de4a49f/tripcost-ledger-detail-comparison.png`
- Widget 回归同时断言筛选行接近面板全宽、右侧值距面板右边不超过 56 logical px，并覆盖餐饮/住宿图标与 JPY 日元图标映射。
- 完整 `flutter analyze` 无问题；完整测试 184 项通过，1 项联网 smoke test 按设计跳过；最终 iOS Simulator Debug 构建成功。

## 筛选标题垂直居中复核（2026-08-19）

- 视觉真值：`/var/folders/6h/fw9ps2896831sdwc108hy6dm0000gn/T/codex-clipboard-a83968a8-e1f9-470c-8077-467c40ddc9c3.png`，1206 × 2622 px（402 × 874 logical px，@3x）。
- 最终实现截图：`/Users/starburst/.codex/visualizations/2026/08/19/01a018df-8764-7460-a651-d8e15de4a49f/tripcost-ledger-filter-title-centered.png`，1206 × 2622 px（402 × 874 logical px，@3x）。
- 聚焦同画面对照：`/Users/starburst/.codex/visualizations/2026/08/19/01a018df-8764-7460-a651-d8e15de4a49f/tripcost-ledger-filter-title-center-comparison.png`；左右使用同一筛选卡片裁切范围和密度。
- 状态：简体中文、浅色模式、账本筛选弹框打开、筛选值为“全部”。
- P2 历史：`CupertinoListTile` 的单标题纵向容器使标题靠上；改为固定 48pt 高、水平 `Row` 居中的完整宽度点击行，并保留右侧值和箭头贴右。
- 回归证据：Widget 测试断言“分类”标题中心与所在行中心差值小于 1 logical px，同时继续断言右侧值距面板右边小于 56 logical px；11 项账本聚焦测试全部通过。
- 五项复核：字体/字号、48pt 行距与分隔线、蓝/灰色令牌、系统图标清晰度、中文文案均与现有设计方向一致；没有新增图片资产，也没有剩余 P0/P1/P2 问题。
- 最终源码完整 `flutter analyze` 无问题；不含截图调试入口的 iOS Simulator Debug 包重新构建、安装并启动成功。

final result: passed
