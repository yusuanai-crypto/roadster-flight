# v0.2 视觉素材来源

- `assets/vehicle/reference-original.png`：用户提供的银色跑车侧面图，仅供来源核对，游戏不加载此图。
- `assets/vehicle/reference-car.png`：内置 `image_gen` 从用户附件去除背景后生成的透明 PNG。处理要求为“只去背景，保持银车轮廓、原色、方向不变”。PNG 保留原输出，未另行重采样；代码通过 alpha 有效边界裁定绘制区域，游戏中可见宽度为 136 像素。
- 霓虹城市、沙漠、天空、海底背景及配套障碍、拾取物由 Godot CanvasItem 原生图形绘制，不依赖外部图片。
