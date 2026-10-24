# Roadster：氮气飞驰 v0.5

Windows 电脑端 2D 横版飞行试玩版。驾驶银色跑车，收集金币与氮气罐，飞越霓虹城市、沙漠、天空和海底。

## 开始试玩

双击 [v0.5 Windows 程序](builds/windows-v0.5/RoadsterFlight.exe)，或完整解压 [v0.5 Windows ZIP](builds/RoadsterFlight-v0.5-Windows.zip) 后运行 `RoadsterFlight.exe`。请保留同目录的 `icudt_godot.dat` 等文件，无需安装 Godot。

本轮按场景重新制作障碍物，并加入随机路线：

- 城市：无人机、卫星、带电能量球；沙漠：不规则岩石、晶簇、风滚草。
- 天空：雷云闪电、热气球、滑翔机；海底：水母、水雷、分叉珊瑚。
- 使用圆弧、多角形、尖刺和组合轮廓，绘制与碰撞共用同一组多边形，空白角落不会碰伤车辆。
- 随机改变高度、体型和横向间距，上、中、下区域均会出现；同一造型不连续重复，每次重试继续产生新路线。
- 难度提升后随机加入错开的双障碍，保留每组可通行路线；金币和氮气罐避开障碍，预览图同步更新。
- 延续默认全屏、Esc 退出全屏、喇叭音乐按钮、动画轮播及精简 HUD。

![四场景障碍物](builds/qa/v5/obstacles-overview.png)

| 操作 | 按键或按钮 |
| --- | --- |
| 选择场景 | ← / →、预览两侧箭头，或点击场景名称 |
| 开始飞行 | Enter 或“开始飞行” |
| 喷氮上升 / 下落 | 按住空格或鼠标左键 / 松开 |
| 退出全屏 | Esc（优先于暂停 / 继续处理） |
| 暂停 / 继续 | 对应按钮；窗口模式下也可按 Esc |
| 切换全屏 / 窗口 | F11 或 Alt+Enter |
| 重试 | 暂停或结算时按 R，或点击重试 |
| 音乐 | M 或喇叭图标 |

失去焦点会自动暂停，回来后主动继续。点击界面按钮不会作为喷氮输入。

## 玩法

每局 3 颗红心、100 点氮气，前 10 秒无障碍练习。金币补充 1 点氮气，高压氮气罐补充 35 点，最多 100 点。撞障碍或触地扣生命；空罐坠落且仍有生命时，救援回安全高度并恢复 50% 氮气。普通触地不额外补气，生命耗尽后结算。

速度在前 180 秒从 340 增至 620 像素 / 秒，障碍组间隔从约 3.9 秒降至 1.7 秒；60 秒后有 65% 概率出现横向错开的双障碍。随机安全通道从 224 收窄至 184 像素，相邻组的通道中心最多变化 112 像素。最大障碍完整进入画面后仍留有至少 1.5 秒反应时间。暂停与倒计时不推进难度。四场景各有背景、专属障碍和原创循环音乐；重试保留场景，本机保存最高距离。

当前仍为试玩版，金币只在本局计数和补气；尚无车库、永久成长、独立关卡、通关目标和音量滑杆。

## 验证

244 项断言通过、0 失败（77 障碍专项 + 37 基础 + 74 功能回归 + 6 退出 + 50 真实窗口界面检查）。专项检查生成 4,420 个障碍，四个场景均覆盖上、中、下区域；12 种造型通过实际物理空间查询，检查实体部位可碰撞、空白角落不碰撞。启动全屏在 1920 × 1200 显示器实测，另验证 1280 × 800、1600 × 720 窗口铺满。

日志、截图、输入辅助飞行结果与发行包校验位于 `builds/qa/v5`，详见 [当前状态](docs/prototype-status.md)。输入辅助仅用于 QA，不向游戏提供自动驾驶。此前界面发布记录见 [v0.4 历史状态](docs/prototype-status-v0.4.md)。

## 开发

Godot 4.7.2 / GDScript，入口 `project.godot`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\setup-godot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build.ps1
```

首次准备工具需要联网；引擎与模板在 `.tools`，构建子进程的用户目录和临时目录隔离在工作区。构建遇到引擎错误时失败，日志在输出目录。

已有导入缓存后，可按顺序运行测试。请使用工作区内的 QA 用户目录，避免修改玩家记录：

```powershell
$env:APPDATA = "$PWD\.tools\qa-v5\appdata"
$env:LOCALAPPDATA = "$PWD\.tools\qa-v5\localappdata"
$godot = '.\.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . -s res://tests/prototype_smoke.gd
& $godot --headless --path . -s res://tests/v2_features.gd
& $godot --headless --path . -s res://tests/quit_lifecycle.gd
& $godot --headless --path . -s res://tests/v5_obstacles.gd
& $godot --headless --fixed-fps 60 --path . -s res://tests/flight_route_probe.gd -- --duration=210 --theme=city --seed=2026
& $godot --path . -s res://tests/v4_interface.gd -- --capture-dir=res://builds/qa/v5
& $godot --path . -s res://tests/render_v5_obstacles.gd
& '.\tools\verify-windows-release.ps1'
& '.\tools\package-windows.ps1'
```

`v4_interface.gd` 使用实际显示器测试全屏，需要真实 Windows 图形会话。`v3_interface.gd` 转发到当前界面检查。`render_v2.gd` 名称保留，实际截图使用当前版本界面。单独的发行检查脚本隔离子进程用户目录，并检查实际窗口边界、正常关闭 EXE。

## 素材

本轮 12 种障碍由项目 Godot 脚本绘制，轮廓和碰撞共用几何数据；四幅预览由正式绘制脚本重新渲染。详见 [v0.5 素材记录](docs/assets-v0.5.md)。标题和 SVG 图标沿用 [v0.4 素材](docs/assets-v0.4.md)，车辆与配乐沿用 [v0.2 素材](docs/assets-v0.2.md)。

普通界面通过系统字体显示中文，不捆绑系统字体。Windows 包附带 Godot MIT 许可。v0.1–v0.4 程序和对应 ZIP 均保留。
