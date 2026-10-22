# Refqo 优化实现与验收 — 2026-10-22

范围仅为 `apps/refqo`。按本轮确认保留系统键盘，名称和备注支持中文，不强制英文。未改变库存预测规则、历史保护规则、备份 schema、应用身份或其他项目。

## 已实现

- 异步操作统一处理开始、执行中、成功、失败和取消；先绘制可见状态再执行校验及文件操作。详情页订阅状态，保存期间禁止重复写入及返回；慢操作继续反馈，不以超时释放写入锁。
- 新建耗材后可直接关联设备；关联后可查看计划；入库、更换后可查看流水；撤销后可查看计划。库存不足提供入库入口，历史保护提供流水入口。
- 表单失败保留草稿、恢复按钮并显示错误；累计库存上限在表单内校验；无效字段获得焦点。恢复备份先预览，取消不改资料；分享取消、目标已接收和结果不可确认分别反馈，不声称文件已在外部成功落盘。
- 启动先显示 Flutter 页面，再解析存储路径；路径失败可重试。清除主资料后副本删除失败时，同步空资料库并明确提示“副本待清理”，可重试。
- 首页直接展示计划窗口和补货数量；耗材页显示条目数量；设置长说明折叠。只构建当前标签页，缓存预测，流水按可见条目构建。
- 三类表单共享焦点和滚动管理：系统键盘弹出居中、隐藏恢复原位置，数字键盘提供完成入口；处理快速高度变化、旋转布局和页面销毁。
- 单行 Enter/完成校验提交，多行 Enter 保留系统文字编辑，Ctrl/Cmd+Enter 提交；Tab/Shift+Tab 顺序切换，左右键编辑光标，上下键仅在实际显示首/尾行边界切换字段；组合输入和选区优先。退格沿用 Flutter 文本编辑，不叠加删除计时器。

## 验收矩阵

| 编号 | 当前结论 | 证据与边界 |
|---|---|---|
| F01 | 自动回归通过 | 原有领域、文件和界面回归；新增提交异常、保存中状态、分享异常重试、文件选择取消/失败、恢复预览取消/确认、清理部分完成测试。外部文件提供方异常通过注入验证。 |
| F02 | 通过 | 原子保存/重载；三平台业务流程使用真实文件仓库，保存后重建应用并重读。普通最终 main 安装另已完成终止进程再启动（未重新安装），两条资料保留，中文名称和备注与本地 JSON 一致。 |
| F03 | 通过 | 重复完成动作只写一次；执行中禁用按钮、保护返回；等待超过 3 秒仍保持锁并提示。 |
| F04 | 通过 | 主文件损坏恢复、路径解析失败重试、原子提交前失败、清除后的部分副本失败及重试。主文件清除后不继续显示旧库存。 |
| U01 | 通过自动/截图范围 | 可操作、禁用、执行中不同；错误具有可读文本和 live region；查看计划/流水等后续动作保持有效。 |
| U02 | 模拟器首帧采样通过；真机待补 | 每环境入库保存 30 次，测量从测试点击派发到首个 Flutter post-frame 回调；不包含 GPU 栅格化、屏幕呈现或系统分享完成，也不代表每个操作都进行了真机 30 次采样。数值见 results.json。 |
| K01 | 三环境通过 | 原生键盘产生的实际 viewInsets 下，首字段、备注字段居中偏差及隐藏复位误差均为 0 逻辑像素。另有单元测试覆盖快速高度变化/销毁。 |
| K02 | 自动与 iOS 原生实操通过 | KeyDown/Repeat/Up 覆盖选区、空值、中文和组合 emoji；普通 iPhone SE simulator main 中，系统删除键长按 1.5 秒、外接 Backspace 长按 1.8 秒均连续删除到空，松开后新输入保留。 |
| K03 | 自动与 iOS 实操通过 | 自动覆盖 Enter、多行、自动换行、选区、组合输入、方向键、Tab、只读历史日期；实际键盘验证空值回车报错、组合输入回车确认、单行回车保存、备注回车换行、Down/Tab/Shift+Tab 焦点及 Left/Right 光标编辑。 |
| K04 | 部分覆盖 | iPhone SE/iPad mini iOS18.3 和 Android API35 实际弹出系统键盘；iPhone SE 普通最终 main 已实测系统拼音候选点选录入中文名称/备注，并通过模拟器路由实际硬件按键。Android/iPad 中文候选、第三方输入法全组合、实体设备、浮动键盘和分屏仍待补。 |
| K05 | 已按用户新要求调整 | 保留系统键盘和中文输入，不再以锁定英文为验收条件。 |
| R01 | 部分覆盖 | 中英文、深浅色、320×568、两倍字号与键盘工具栏；58 项自动测试通过。实体设备、iOS15、Android24/36、读屏和完整横屏/分屏矩阵尚未覆盖。 |

宿主解锁后已完成 iPhone SE 普通 main 原生补验：[按键与重启记录](evidence/optimization-20261022/native-keyboard-checks.json)。系统拼音组合输入正常，候选点选支持中文，确认候选不会误提交；成功保存后显示“关联设备”下一步入口。

## 保存反馈采样

| 环境 | 次数 | 中位数 | P95 | 最大值 |
|---|---:|---:|---:|---:|
| iPhone SE iOS 18.3 simulator | 30 | 25.852ms | 27.799ms | 28.230ms |
| Android API35 Refqo_QA emulator | 30 | 31.144ms | 39.263ms | 60.159ms |
| iPad mini iOS18.3 simulator | 30 | 27.855ms | 29.066ms | 29.594ms |

以上是 Debug 模拟器/仿真器的 Flutter 首帧回调采样；不是实体设备屏幕呈现延迟。每个环境只对入库保存做了 30 次采样，其余功能通过状态与结果回归验证。SE 自动流程早于最后一项执行中返回/导航禁用调整，之后已用最终 main 构建完成原生补验；Android/iPad 自动流程包含最终应用代码。

## 验证与复跑

- 静态分析：无问题；格式检查及差异空白检查通过。
- 单元与 Widget：58 项通过（包含既有 35 项）；`test/interaction_test.dart` 和 `test/storage_interaction_test.dart` 为新增回归。
- 普通 iOS simulator main 构建通过，无正式签名、上传或发布动作。
- 三环境完整业务/键盘/保存采样使用独立 Refqo QA 安装；每次设备测试会清除该 QA 安装的原业务测试资料。不要指向真实资料安装。

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
REFQO_DEVICE=optimization-qa flutter drive --no-pub \
  --driver=test_driver/app.dart \
  --target=integration_test/interaction_runtime_test.dart \
  --dart-define=REFQO_QA=true -d QA_DEVICE_ID
```

结构化结果：[results.json](evidence/optimization-20261022/results.json)。完整日志留在同目录 `*.log`（被现有 Git 规则忽略）。

截图：[iPhone SE](evidence/runtime/optimization-ios-se-20261022/)、[Android](evidence/runtime/optimization-android-20261022/)、[iPad](evidence/runtime/optimization-ipad-20261022/)。集成截图捕获 Flutter 应用层，系统键盘区域可能呈空白；键盘几何断言使用真实原生 inset，截图本身不证明候选栏行为。

原生全屏截图：[拼音候选](evidence/optimization-20261022/ios-native-pinyin-candidate.png)、[中文备注与系统键盘](evidence/optimization-20261022/ios-native-chinese-notes.png)、[进程重启后中文详情](evidence/optimization-20261022/ios-native-after-process-restart.png)。
