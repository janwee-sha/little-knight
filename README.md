# Little Knight

一个使用 Godot 4.7 制作的横版动作垂直切片。游戏以 640×360 逻辑分辨率运行，支持整数像素缩放、键鼠和手柄，并包含完整暂停菜单、两段剑术连招、逐状态原创像素动画、手柄震动与 CC0 音效。

## 玩法

- `A / D` 或方向键：移动
- `Space / W / ↑`：跳跃（支持土狼时间与跳跃输入缓存）
- `鼠标左键 / J / Z`：两段挥剑连招，可击破敌人的火球
- `鼠标右键 / K / X / Shift`：短距离无敌闪避
- `Esc / P`：暂停或继续
- `R`：失败或通关后重新开始
- 手柄：左摇杆/十字键移动，南键跳跃，西键攻击，东键闪避，Menu/Start 暂停

穿过五段废墟，躲开地刺和深坑，击败全部八名近战/远程守卫，然后抵达最右侧城门。地图中段的月光祭坛可恢复生命。

## 运行

在 Godot 中导入本目录的 `project.godot`，按 `F6`/`F5` 运行即可。

自动化验证：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/smoke_test.gd
```

视觉回归脚本 `tests/visual_capture.gd` 会把游戏、战斗和暂停画面写入 `/private/tmp/little-knight-visual/`。

第三方字体与 CC0 音效来源见 [`THIRD_PARTY_ASSETS.md`](THIRD_PARTY_ASSETS.md)。
