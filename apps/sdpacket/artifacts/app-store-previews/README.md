# KIFXPRO App Store 预览图

## 成品

- `final/iphone-6.5-01.png` — 搬家流程，一目了然
- `final/iphone-6.5-02.png` — 每个箱子，都有迹可循
- `final/iphone-6.5-03.png` — 扫码推进，离线也安心
- `final/ipad-12.9-01.png` — 搬家流程，一目了然
- `final/ipad-12.9-02.png` — 每个箱子，都有迹可循
- `final/ipad-12.9-03.png` — 扫码推进，离线也安心

iPhone 成品均为 `1242 × 2688` RGB PNG；iPad 成品均为 `2732 × 2048` RGB PNG，全部不含 Alpha 通道。

## 素材与验证

- 氛围背景由内置图像生成工具生成，限制为无文字、无 UI、无设备和无二维码的背景层。
- iPhone 界面来自仓库中的真实实现截图。
- iPad 界面来自 iPad Pro 13-inch (M4)、iOS 18.3 模拟器的原生横屏运行截图。
- `qa/` 内包含两套三联联系表，便于快速检查顺序、文案和整体一致性。

## 重新生成

在 `apps/sdpacket` 目录运行：

```bash
python3 tool/generate_app_store_previews.py
```

脚本依赖 Pillow，并复用 `source/`、品牌图标、中文字体、真实界面截图和 onboarding 插画。
