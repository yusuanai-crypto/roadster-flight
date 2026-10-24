# Roadster 飞行试玩版 v0.3 状态

记录日期：2026-10-24。用户本轮界面修改已完成并交付独立 Windows 版本。

## 实现

- 左上角“氮气飞驰”使用透明毛笔艺术字。素材由内置 image_gen 生成，完整提示词和路径见 [素材记录](assets-v0.3.md)。
- 删除用户三张截图红框内文案，包括首页英文标识、版本、场景描述、说明文字、操作页脚，飞行中的场景 / 速度行与页脚，以及暂停页英文标题、提示语和快捷键页脚。
- 四幅 1280 × 720 实际场景预览占据中央大幅区域（900 × 424 设计像素，占设计画面约 41.4%），两侧显示相邻场景；支持左右箭头、← / → 以及场景名称按钮。循环切换与起飞选择保持一致。
- 新增首页与暂停页全屏按钮，支持 F11 / Alt+Enter。全屏使用当前显示器完整区域，窗口缩放同样铺满；当前采用忽略固定宽高比的缩放方式，不同显示器比例会分别缩放横纵方向。
- 生命显示为红色实心红心，失去的生命显示为空心暗色心形。暂停按钮采用三角图标，仍执行暂停操作。

## 验证

144 项断言通过，0 失败：

| 验证 | 结果与证据 |
| --- | --- |
| 基础行为 | 37 / 37；`builds/qa/v3/smoke.log` |
| 原有 v0.2 功能回归 | 74 / 74；`builds/qa/v3/v2-features.log` |
| 正常退出生命周期 | 6 / 6；`builds/qa/v3/quit-lifecycle.log` |
| 本轮真实窗口界面 | 27 / 27；`builds/qa/v3/interface.log` |
| 真实全屏 | 当前显示器 1920 × 1200，全屏占满且四角无黑边；`menu-fullscreen.png` |
| 非标准窗口比例 | 1280 × 800 与 1600 × 720 均铺满；`menu-16x10.png`、`menu-wide.png` |
| 全屏输入 | F11、Alt+Enter、菜单按钮、暂停按钮均通过；恢复窗口正常，暂停世界不意外继续 |
| UI 行为 | 四场景切换 / 首尾循环、场景锁定、0–3 颗红心、三角暂停、指定文字删除通过 |
| 画面 | 已渲染并目视检查四场景菜单，飞行与暂停界面，以及全屏画面 |
| 导入与导出 | 日志无 ERROR / Parse Error / Script Error；正式预览、标题和图标已进入导出包 |
| 独立 EXE | 从独立输出目录真实 OpenGL 启动，正常关闭主窗口，退出码 0、stderr 0；`release-check.json` |
| ZIP | 5 个文件逐项解流读取，SHA256 与长度均匹配；`package-check.json` |

本轮主要变更界面，不重复 v0.2 的 210 秒耐久测试；其证据和限制保留在 [v0.2 历史记录](prototype-status-v0.2.md)。尚未完成长期真人试玩及实声听音，不将自动化检查等同于最终体验验收。

## 截图

| 场景 | 菜单 | 飞行 |
| --- | --- | --- |
| 霓虹城市 | [菜单](../builds/qa/v3/menu-city.png) | [飞行](../builds/qa/v3/flight-city.png) |
| 沙漠 | [菜单](../builds/qa/v3/menu-desert.png) | [飞行](../builds/qa/v3/flight-desert.png) |
| 天空 | [菜单](../builds/qa/v3/menu-sky.png) | [飞行](../builds/qa/v3/flight-sky.png) |
| 海底 | [菜单](../builds/qa/v3/menu-underwater.png) | [飞行](../builds/qa/v3/flight-underwater.png) |

另见 [暂停页](../builds/qa/v3/pause-city.png) 与 [1920 × 1200 全屏](../builds/qa/v3/menu-fullscreen.png)。

## 交付

| 项目 | 结果 |
| --- | --- |
| 程序 | `builds/windows-v0.3/RoadsterFlight.exe` |
| EXE 大小 | 118,710,184 字节 |
| EXE SHA256 | `a3fd53b0946efc4dd1985a08c719ab3853673bc5b1d8d77d335d52d2b239c69d` |
| ZIP | `builds/RoadsterFlight-v0.3-Windows.zip` |
| ZIP 大小 | 48,128,922 字节（约 48.13 MB） |
| ZIP SHA256 | `2adf9429c99c14fd12e10b2bad0a82779477a03a67eb4cdd524d27a82825fddc` |

ZIP 含 EXE、ICU 数据、Godot MIT 许可、引擎来源记录和新版中文试玩说明。原始参考图、开发脚本、测试、QA 截图与日志均不进入运行包。v0.1 和 v0.2 的程序及压缩包保留。

复现构建、测试及预览生成命令见 [README](../README.md) 和 [素材记录](assets-v0.3.md)。
