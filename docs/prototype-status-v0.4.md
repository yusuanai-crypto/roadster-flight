# Roadster 飞行试玩版 v0.4 状态

记录日期：2026-10-24。本轮四项界面要求已完成，并交付独立 Windows v0.4。

## 变更与原因

上一版实现了手动进入全屏，但项目启动模式仍是普通窗口。真实窗口回归先复现了两个失败：启动并未全屏、窗口尺寸未覆盖显示器。现设置 `display/window/size/mode=4`，在引擎创建窗口时即进入独占全屏。保留画面铺满设置，删除首页及暂停页的全屏按钮。

- Esc 优先退出全屏，保留当前菜单或游戏状态；窗口模式下再按 Esc 暂停或继续。F11 / Alt+Enter 可切回全屏。实际游戏仍保留失焦自动暂停。
- 菜单、HUD 和暂停页使用喇叭图标，静音时显示叉号，按钮与 M 键状态同步。
- 四场景卡片以 0.38 秒横向移动、缩放和明暗变化完成一次切换，支持首尾循环。连续输入更新最终目标；当前移动完成后继续过渡，不积累隐藏卡片。动画中起飞采用最新选择。
- N₂ 标签置于氮气进度条内部，去掉氮气栏目名、数值、生命栏目名、本局金币和飞行距离栏目名，保留红心与实际数值。
- HUD 与结算金币数字前均加入金币图标。
- 结算页删除 RUN COMPLETE、死亡原因说明、统计栏目名、底部操作说明；重新收紧面板布局。暂停和结算时隐藏飞行通知。

新增图标及历史素材来源见 [素材记录](assets-v0.4.md)。

## 验证

167 项断言通过，0 失败：

| 验证 | 结果与证据 |
| --- | --- |
| 基础玩法 | 37 / 37；`builds/qa/v4/smoke.log` |
| 难度、救援、场景、音乐回归 | 74 / 74；`builds/qa/v4/v2-features.log` |
| 退出生命周期 | 6 / 6；`builds/qa/v4/quit-lifecycle.log` |
| v0.4 真实窗口界面 | 50 / 50；`builds/qa/v4/interface.log` |
| 启动全屏回归 | 修复前 3 项中 2 失败；修复后全部通过；`startup-before.log`、`startup-after.log` |
| 全屏与窗口比例 | 默认 1920 × 1200 全屏，四角无黑边；1280 × 800、1600 × 720 窗口铺满 |
| Esc | 首页退出全屏、飞行中优先退出全屏、窗口暂停和继续、暂停中退出全屏不自动继续均通过 |
| 轮播动画 | 检查中间位置和尺寸、左右方向、四场景选择、首尾循环、连续切换、过渡中起飞与卡片释放 |
| UI | 0–3 红心、条内 N₂、金币图标、三处喇叭同步、指定文字删除、结算数值通过 |
| 画面 | 目视检查四场景菜单和飞行、暂停、结算、全屏及滑动中间帧；无错位或裁字 |
| 导出程序 | 独立 EXE 启动后窗口与客户区均为 1920 × 1200，和显示器边界完全一致，无标题栏；`release-check.json` |
| 正常关闭 | EXE 正常关闭主窗口，退出码 0，stderr 0；`release.stdout.log`、`release.stderr.log` |
| ZIP | 5 个文件逐项解流 SHA256 和长度均匹配；`package-check.json` |

最终界面、渲染、基础、功能、退出和导出日志均无 ERROR / Parse Error / Script Error。本轮没有修改物理或难度规则，未重复历史 210 秒路线测试；其证据见 [v0.2 历史记录](prototype-status-v0.2.md)。尚未完成长期真人试玩及实声听音。

## 截图

- [1920 × 1200 默认全屏](../builds/qa/v4/menu-fullscreen.png)
- [四场景菜单与飞行总览](../builds/qa/v4/scene-contact-sheet.png)
- [海底飞行 HUD](../builds/qa/v4/flight-underwater.png)
- [右滑中间帧](../builds/qa/v4/carousel-right-midpoint.png)、[左滑中间帧](../builds/qa/v4/carousel-left-midpoint.png)
- [暂停](../builds/qa/v4/pause-city.png)、[结算](../builds/qa/v4/result-empty-tank.png)

## 交付

| 项目 | 结果 |
| --- | --- |
| 程序 | `builds/windows-v0.4/RoadsterFlight.exe` |
| EXE 大小 | 118,715,800 字节 |
| EXE SHA256 | `02a55570bc0434e9d556c3eb87715e8bee84a4c12d6afc70eee5793000a15590` |
| ZIP | `builds/RoadsterFlight-v0.4-Windows.zip` |
| ZIP 大小 | 49,414,623 字节（约 49.41 MB） |
| ZIP SHA256 | `23f21254d3a2b81fe44ab0bd9734664a151bf4d982c476f4a4ce71ba22f05cba` |

ZIP 内含 EXE、ICU 数据、Godot MIT 许可、引擎来源记录、中文试玩说明。v0.1–v0.3 程序和 ZIP 均保留；上一版状态归档于 [v0.3 历史记录](prototype-status-v0.3.md)。构建与测试命令见 [README](../README.md)。
