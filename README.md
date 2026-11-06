# test2 — 2D 影子回放原型

2D 俯视角原型：录制 → 重置 → 副本循环回放，验证"与过去的自己同时行动"的核心机制。全部白模占位，纯色背景。

## 核心机制

录制 12 秒操作 → 玩家回到出生点 → 生成副本无限循环回放该段录制 → 下一轮录制再次生成新副本。每个副本各自独立循环，互不干扰。

## 当前内容

- `project.godot`：Godot 4.7 / GL Compatibility 渲染；主场景 `scenes/main.tscn`；纯色背景（蓝灰）；输入 `move_left/right/up/down`（WASD + 方向键）。
- `scenes/main.tscn`：
  - `Player`（`CharacterBody2D`）：蓝色方块白模 + 胶囊碰撞；`Camera2D` 跟随；头顶 `Label` 倒计时；`CountdownTimer`（12 秒、one_shot、autostart）。
  - `Obstacle1` / `Obstacle2`：灰色方块障碍（`StaticBody2D`）。
- `scenes/ghost.tscn`：半透明紫色方块副本（`CharacterBody2D`，碰撞层 2 / 掩码 0），`scripts/ghost.gd` 驱动。
- `scenes/pressure_plate.tscn` + `scripts/pressure_plate.gd`：压力板（`Area2D` 白模，掩码 3 覆盖玩家层 1 与副本层 2）。玩家或副本（`plate_activator` 组）站上去变绿色并发出 `state_changed(plate_id, active)` 信号（含编号与激活状态），离开恢复灰色；持续站上不重复发信号。
- `scenes/door.tscn` + `scripts/door.gd`：机关门（`StaticBody2D`，显示为一条 Line2D 线）。关闭时红色并阻挡玩家，开启时绿色半透明并禁用碰撞。自动监听 `pressure_plates` 组中同编号压力板：板激活开门、取消关门；状态变化发出 `state_changed(door_id, is_open)`；`set_open()` 幂等。
- `scripts/player.gd`：八方向移动（无重力、不旋转，`move_and_slide`）；每物理帧记录 `Transform2D`；倒计时结束时生成副本、重置位置、清空录制并重启计时。副本显式命名 `Ghost1/Ghost2/...`。
- `scripts/ghost.gd`：逐物理帧回放 `Transform2D` 数组，取模无限循环；与玩家功能一致（带碰撞体、可触发压力板），独立碰撞层保证不推挤玩家、不被墙阻挡。
- 测试：`scripts/tests/test_core.gd`（15 项）、`test_pressure_plate.gd`（9 项）、`test_door.gd`（12 项）、`test_ghost_plate.gd`（8 项）。

## 已验证（无头）

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/tests/test_core.gd
# 其余测试同理替换脚本名：test_pressure_plate / test_door / test_ghost_plate
```

全部通过：核心循环 15/15（移动、不旋转、标签在上方、超时重置、副本生成与循环、双副本各自独立回放）；压力板 9/9（信号含编号与激活态、变色、去重、离开恢复）；门 12/12（关闭阻挡、同编号板开门、信号、幂等、开启通行、关门恢复）；副本机关 8/8（副本踩板激活、开门、离开关闭、不推挤玩家）。

## 未验证 / 临时数值

- 未做可视化窗口测试，手感与观感需在编辑器中运行确认。
- `speed=240`、`acceleration=1600`、障碍位置、倒计时 12 秒均为临时值。
- 无美术、无动画；玩家/副本/障碍均为纯色 Polygon2D 白模。
- 副本与玩家之间暂无接触判定（失败规则未加入）。
