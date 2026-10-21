# UI 与交互验收 — 2026-10-21
判定：实际检查矩阵通过；未检查的状态不据此放行。原创纸色/梅紫/杏色，供给计划优先，最大内容宽720逻辑像素；滚动内容尾部按系统安全区留量。

| 渲染目标 | 实际覆盖 | 证据 |
|---|---|---|
| iPhone SE 3 / iOS18.3 / 375×667 | 引导、空态、两设备、Cupertino更换确认、30/60天净缺口、流水、中文深色、资料重载、重看引导、2倍字号首屏/末端 | runtime/ios-se-final/01…12；ios-runtime-final-source.log |
| iPad mini A17 Pro / iOS18.3 / 744×1133 | 同一完整流程与2倍字号；宽屏布局、底部安全区 | runtime/ios-ipad/01…12；ipad-runtime.log |
| 独立Pixel7 AVD / Android15 API35 / 1080×2400 | 同一完整流程与2倍字号；底栏、键盘输入、确认取消/重开 | runtime/android-api35/01…12；android-runtime.log |
| 320×568 / 字号2 / 长型号与99999库存 | 库存卡不溢出；编辑页末端按钮可达 | test/independent_review_test.dart、widget_test.dart |
| 普通main应用 iPad | 安装后桌面图标、中文系统首次引导、跳过、正常启动；原生备份分享与Files本地保存/选择 | CUA观察；runtime/native/ |
| 普通main应用 Android | 正常冷启动与英文引导，状态栏和手势区 | runtime/native/android-cold-onboarding.png |

原生启动配置：iOS命名颜色支持深浅色，纯背景无文案；Android旧版window背景及Android12+原生splash使用原创图标和对应背景。没有假进度/延时。普通main应用冷启动可达引导，未捕获每个原生启动动画帧，不能宣称逐帧无闪烁。iOS安装图标已目检；Android图标资源/原生启动配置已核验，桌面遮罩的完整矩阵仍待补。
系统语言初始iPad为zh-Hans-HK，正常应用解析为简体中文；Android正常启动为英文。三设备自动流程使用测试环境的英文起点，再显式切换中文/深色。无覆盖的动态语言/英文回退与偏好清除由widget回归验证。深浅色OS实时切换、读屏、减弱动态、横屏、所有首轮大字组合、平板分屏和真机未全部实测。
本目录截图为运行证据，部分有alpha、尺寸为测试设备；未制作为可上传商店营销截图。
