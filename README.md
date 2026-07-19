# Little Knight

一个使用 Godot 4.7 制作的高难度横版 ARPG 垂直切片。游戏以 640×360 逻辑分辨率运行，支持整数像素缩放、键鼠和手柄，并包含完整暂停菜单、精力制战斗、方向防御与完美防御、逐状态像素动画、手柄震动与 CC0 音效。

## 玩法

- `A / D` 或方向键：移动
- `Space / W / ↑`：跳跃（支持土狼时间与跳跃输入缓存）
- `鼠标左键 / J / Z`：两段轻击连招，可击破普通投射物
- `鼠标中键 / E / K`：重击；完美防御后的短暂窗口内会改为强力反击
- `鼠标右键 / Q / L`：按住正面防御；在攻击命中前 7 帧内按下可完美防御
- `Shift / X`：短距离无敌闪避（空中每次落地前限用一次）
- `Esc / P`：暂停或继续
- `R`：失败或通关后重新开始
- 手柄：左摇杆/十字键移动，南键跳跃，西键轻击，北键重击，LB 防御，东键闪避，Menu/Start 暂停或在结算界面重试

所有攻击、防御和闪避共用精力。轻击两段分别消耗 12/16，重击 32，反击 28，闪避 24；格挡普通攻击消耗 18，完美防御消耗 22–28。精力不足时招式不会发动，防御被打空则破防。

近战守卫拥有普通、黄光和红光三类攻击：普通攻击可防御或完美防御，黄光只能闪避或完美防御，红光只能闪避。远程守卫会混用可防御/可击破的普通投射物和不可防御、不可击破的红光投射物。敌人具有更高生命与韧性，双人遭遇由攻击令牌限制同时出手，但仍会保持进攻压力。

穿过五段废墟，躲开地刺和深坑，击败全部八名守卫，然后抵达最右侧城门。地图中段的月光祭坛会恢复 2 点生命并激活检查点；失败后可从祭坛继续挑战后半段。

## 运行

在 Godot 中导入本目录的 `project.godot`，按 `F6`/`F5` 运行即可。

自动化验证：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/smoke_test.gd
python3 .agents/skills/godot-input-parity/scripts/run_input_audit.py \
  --project . --contract tests/input_contract.json \
  --godot /Applications/Godot.app/Contents/MacOS/Godot
```

视觉回归脚本 `tests/visual_capture.gd` 会把重击、防御、完美防御、敌人黄/红光、低精力、检查点和暂停画面写入 `/private/tmp/little-knight-visual/`。

第三方字体与 CC0 音效来源见 [`THIRD_PARTY_ASSETS.md`](THIRD_PARTY_ASSETS.md)。
