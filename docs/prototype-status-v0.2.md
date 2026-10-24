# Roadster 飞行原型 v0.2 状态

记录日期：2026-10-24。当前范围是 Windows 可试玩原型，完整方案中的车库与永久升级尚未实现。

## 本轮实现

- 将代码绘制的红车替换为用户附图中的银色跑车。内置 `image_gen` 去背景，保留银色车体、轮廓与朝向，使用透明 PNG。素材记录见 [assets-v0.2.md](assets-v0.2.md)。
- 随有效飞行时间递增难度：前 180 秒速度从 340 增长至 620 像素 / 秒；前 10 秒保留无障碍练习，此后障碍间隔从约 3.9 秒降至 1.7 秒。达到上限后保持；暂停和倒计时不推进难度。
- 仅在氮气耗尽坠地且还有生命时，救援到安全高度并恢复 50 / 100 氮气。普通触地不额外补气，最后一条生命耗尽仍正常结算。
- 首页新增霓虹城市、沙漠、天空、海底四场景选择，背景、障碍外观和音乐同步切换；所选场景贯穿当前对局，重试保持选择。
- 四首原创循环音乐：城市电子节奏、沙漠暖色拨弦与手鼓、天空钟琴、海底缓慢氛围。菜单和结算较轻，飞行时稍响；暂停续播，`M` 和界面按钮开关音乐，暂无音量滑杆。

原有倒计时、自动前进、喷氮上升 / 松开下落、氮气与金币拾取、伤害保护、生命结算、暂停、失焦自动暂停、重试及本机最高距离保存继续保留。场景共享玩法与难度，尚无独立关卡、通关目标、巡航无人机或成长系统。

## 最终验证结果

最终源码已冻结并重导出，**117 项断言通过、0 失败**：37 项基础、74 项 v0.2 新增、6 项正常退出。覆盖渐进速度与障碍密度、最小可见反应时间、实际生成数量、空罐及普通触地救援、四场景切换、音乐暂停 / 恢复 / 静音、动态资源、音频清理及重复退出保护。对应测试 stderr 均为 0。

| 验收项 | 当前状态 |
| --- | --- |
| Godot 4.7.2 源码检查 | 通过，最终导入及导出日志无引擎错误 |
| 基础行为回归 | 37 / 37，通过；`builds/qa/v2/root-final-prototype_smoke.{log,stdout.log,stderr.log}` |
| v0.2 新行为检查 | 74 / 74，通过；`builds/qa/v2/root-final-v2_features.{log,stdout.log,stderr.log}` |
| 正常退出生命周期 | 6 / 6，通过；`builds/qa/v2/quit-lifecycle.{stdout.txt,stderr.txt}` |
| 自动路线探测 | 210.00 秒通过，覆盖 180 秒难度上限；`builds/qa/v2/root-route210.{log,stdout.log,stderr.log}` |
| 四场景画面与控件 | 已渲染并目视核对首页、飞行、暂停、空罐救援及结算截图 |
| Windows release 导出 | 通过，`builds/windows-v0.2/RoadsterFlight.exe` |
| 独立 EXE 启动及正常关闭 | 真实 OpenGL 窗口通过；CloseMainWindow 正常关闭，Exit 0，stderr 0；`builds/qa/v2/release-final.{log,stdout.log,stderr.log}` |
| ZIP 打包与内容校验 | 5 文件逐项解流 SHA256 与长度匹配；`builds/qa/v2/package-check.json` |
| 真人长时间试玩与实声听音 | 未完成 |

210 秒探测通过测试脚本按真实 Input 发送空格按压与释放，跟随视野中实际氮气罐；它不修改角色速度、燃料或碰撞规则。结果为 8399.8 米、3 格生命、164 枚金币、剩余氮气 97.52 / 100、最低氮气 64.87、最多同时存在 12 个实体，前 10 秒无障碍。独立重跑结果一致，退出码 0、stderr 0。这证明后期路线与补给可持续通过，不代表真人难度已完成平衡。

最终 EXE 从 `builds/windows-v0.2` 目录直接启动，使用 Intel UHD Graphics / OpenGL 3.3 Compatibility；关闭该测试进程的主窗口后正常退出，未依赖编辑器。电影采样文件 `builds/qa/v2/release.wav` 和 `release00000001.png` 用于音画输出取证；正常运行与关闭以独立的 `release-final.*` 为准。

| 场景 | 首页 | 飞行 |
| --- | --- | --- |
| 霓虹城市 | [菜单](../builds/qa/v2/menu-city.png) | [飞行](../builds/qa/v2/flight-city.png) |
| 沙漠 | [菜单](../builds/qa/v2/menu-desert.png) | [飞行](../builds/qa/v2/flight-desert.png) |
| 天空 | [菜单](../builds/qa/v2/menu-sky.png) | [飞行](../builds/qa/v2/flight-sky.png) |
| 海底 | [菜单](../builds/qa/v2/menu-underwater.png) | [飞行](../builds/qa/v2/flight-underwater.png) |

另有 [50% 氮气救援](../builds/qa/v2/rescue-50-percent.png)、[空罐结算](../builds/qa/v2/result-empty-tank.png) 及四场景暂停截图。

音乐资源已完成 Node 语法检查和生成检查；`music_director.gd` 已通过 Godot 4.7.2 `--check-only`。PCM 资源为 32kHz、双声道、16bit，总 14,089,552 字节（13.44MiB）。

| 场景 | 曲名 | 时长 | RMS / dBFS | 循环边界采样步长 |
| --- | --- | ---: | ---: | ---: |
| 霓虹城市 | Midnight Ion Drive | 30.00 秒 | −15.468 | 0.0102234 |
| 沙漠 | Amber Dune Horizon | 27.69 秒 | −14.744 | 0.0096436 |
| 天空 | Cloudline Daybreak | 25.71 秒 | −15.584 | 0.0097351 |
| 海底 | Below the Blue | 26.67 秒 | −15.419 | 0.0016785 |

四首峰值均为 0.799988，无数字削波；循环边界步长低于各曲正常内部最大步长。完整指标在 `assets/music/music-report.json`，生成器为 `tools/generate-music.mjs`。这些是数值与资源验证，headless 的 Dummy 音频和播放状态检查不能代替实声听音。

发行验证期间还采集了 0.6 秒实际混音输出：PCM32、双声道、48kHz，峰值 0.06860、RMS 0.011765，确认音频输出非静音。这个检查证明音频数据进入输出链路，没有声称完成真人听音验收。

## v0.2 Windows 交付

Windows 导出预设版本为 `0.2.0.0`，显式包含透明车辆 PNG 与四首 WAV。参考原图、音频分析 JSON、源码测试、开发工具、文档、QA 图片与构建日志不进入运行包。

`tools/build.ps1` 新增 `-OutputDirectory`，本轮使用 `builds/windows-v0.2`，保留旧输出；脚本默认值仍为 `builds/windows`，支持项目相对或绝对输出目录。Godot 子进程的 `APPDATA`、`LOCALAPPDATA`、`TEMP`、`TMP` 隔离在工作区，遇到非零退出码或日志引擎错误会失败。PowerShell AST 检查通过。最终构建日志为 `builds/windows-v0.2/import.log` 与 `export.log`。

发行 ZIP 仅包含以下 5 个文件，全部解流读取并计算 SHA256，与对应源文件及长度逐项匹配：

1. `RoadsterFlight.exe`
2. `icudt_godot.dat`
3. `LICENSE-Godot.txt`
4. `engine-source-record.json`
5. `试玩说明.txt`

| 交付项 | 结果 |
| --- | --- |
| Windows EXE | `builds/windows-v0.2/RoadsterFlight.exe` |
| EXE 大小 | 117,753,904 字节 |
| EXE SHA256 | `a8502db8fcfe9f4e129394c2c8ff46b280777b82f78f7787da957a494f6312c2` |
| 可分发 ZIP | `builds/RoadsterFlight-v0.2-Windows.zip` |
| ZIP 大小 | 48,456,493 字节（约 48.46MB / 46.21MiB） |
| ZIP SHA256 | `0c0e2bcf815c97c659de25f955b1f5d4dbb1fbe89f85a305a8374ec3c28bad89` |
| ZIP 校验记录 | `builds/qa/v2/package-check.json` |

打包前后 EXE 哈希均与独立启动验证的最终文件一致。ZIP 不含构建日志、开发工具、测试源码、QA 截图、原始参考图或音乐分析报告。

字体通过 `SystemFont` 查找 Windows 的 Microsoft YaHei 等系统中文字体，不捆绑系统字体文件。解压后双击 EXE 运行，需保留同目录配套文件。

## 保留的 v0.1 历史证据

旧版文件 `builds/windows/RoadsterFlight.exe` 和 `builds/RoadsterFlight-Prototype-Windows.zip` 保留，不被本轮输出覆盖。旧版结果不代替 v0.2 最终验收。

| 旧版项目 | 历史结果 |
| --- | --- |
| 基础回归 | 37 项断言通过、0 失败，`builds/qa/root-smoke.log` |
| 自动路线 | 90.02 秒、2804.9 米、3 格生命、72 枚金币 |
| 独立发行包启动与渲染 | 退出码 0；Intel UHD Graphics / OpenGL 3.3 下渲染 1280 × 720 菜单 |
| EXE | 114,116,984 字节；SHA256 `81ddd9af590a19e378a2cc4a81eed0f1243eb214738ab80d8baec06ff5bff8bd` |
| ZIP | 45,062,640 字节；SHA256 `cf1f947a4cf0d3993765b5403f9409143622f6d58a47d3765b886d17950aed75` |
| ZIP 校验 | 5 个文件与源文件逐一匹配，`builds/qa/package-check.json` |

可复现的准备、构建和测试命令见根目录 [README](../README.md)。
