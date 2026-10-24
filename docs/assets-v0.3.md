# v0.3 界面素材

- `assets/ui/title-brush.png`：内置 `image_gen` 新生成的透明毛笔艺术字，2172 × 724，RGBA，alpha 0–255，已在实际游戏画面核对“氮气飞驰”四字。原始生成结果复制入项目，不做后处理。
- `assets/previews/{city,desert,sky,underwater}.png`：四幅 1280 × 720 实际场景预览。使用 `tools/generate-previews.gd`，通过正式背景、跑车及拾取物绘制脚本在真实 OpenGL 窗口渲染，预览与游戏场景一致。
- `assets/ui/heart-full.svg`、`heart-empty.svg`、`triangle.svg`：本项目原生 SVG 图标，分别对应剩余生命、失去的生命、三角暂停按钮，无外部字体依赖。
- 银车与原创音乐来源延续 [v0.2 素材记录](assets-v0.2.md)。

生成预览的命令：

```powershell
& '.\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . -s res://tools/generate-previews.gd
```

标题采用内置工具模式，`transparent_background=true`。最终提示词：

> Use case: logo-brand. Asset type: transparent title artwork for a Chinese flying-car game UI. Text (verbatim): 氮气飞驰. Exactly these FOUR simplified Chinese characters in one single horizontal row, legible and accurately written, no other text or seals. Style: expressive hand-written Chinese brush calligraphy (毛笔行书艺术字), confident bold strokes, lively forward momentum, natural dry-brush texture and tapered ink strokes. Color: luminous solid warm white/light ivory ink, suitable over dark navy game UI; no black ink. Composition: compact horizontal wordmark, all strokes inside image with generous transparent padding; four characters similar height, fluid but readable. Transparent background, no backdrop, no border, no mockup, no car, no extra icons. Aim wide 3:1 aspect ratio. This is production artwork, not a UI screenshot.
