# 关卡内引导调整说明

引导直接挂在 `system/Tutorial`，没有新增教学关卡。它只显示提示和状态标记，不改变移动、碰撞、倒计时、录制、副本回放或机关逻辑。

## 编辑器中可调整的位置

打开 `scenes/main.tscn`，展开 `system/Tutorial`：

- `Tutorial`：全局开关、提示停留时间、字体大小、是否显示机关旁标记。
- `JumpHint`：跳跃提示的位置、触发半径、文案。
- `HammerHint`：锤子拾取提示。
- `BoxHint`：箱体破坏提示和卡住后的追加提示。
- `Plate1Hint` / `Plate2Hint` / `Plate3Hint`：压力板提示及对应门的关联路径。
- `Door1Hint` / `Door2Hint` / `Door3Hint`：门旁提示及通过检测。
- `Trap1Hint` / `Trap2Hint`：死亡装置提示、编号和颜色。
- `SpecialDoorHint`：特殊门的多副本协作提示与编号状态。
- `TurretHint`：炮塔危险提示。

## 常用参数

- `enabled`：单独关闭某一条提示。
- `target_path`：提示跟随的机关节点路径。
- `related_path`：关联的门、压力板或信号控制器路径。
- `trigger_radius`：玩家靠近多少像素时出现提示。
- `help_after_seconds`：玩家在附近停留多久后追加更明确的帮助；设为 `0` 可立即显示。
- `priority`：多个提示重叠时的优先级，数值大的优先。
- `message`：第一次提示。
- `help_message`：玩家暂时没有进展时显示的追加提示。
- `label_offset`：机关旁编号、箭头的屏幕偏移。
- `marker_color`：编号和箭头颜色。

## 当前学习记录

学习记录只存在于本次关卡运行，不会因循环重置清除。玩家完成过对应行为后，该提示不会重复出现；重新运行关卡会重新开始学习记录。

已覆盖：移动、跳跃、锤子拾取、箱体破坏、压力板与门、副本出现、副本踩压力板、Q 结束循环、死亡装置、特殊门、炮塔。

## 人类试玩时建议优先调整

1. 如果提示挡住角色，把对应节点的 `label_offset` 改为 `Vector2(0, -90)` 或更高。
2. 如果提示出现太早，把 `trigger_radius` 从 130 调小到 80–100。
3. 如果玩家容易错过提示，把 `help_after_seconds` 调到 8–12 秒。
4. 如果特殊门提示压过死亡装置提示，把 `SpecialDoorHint.priority` 调低，或把 `Trap1Hint` / `Trap2Hint.priority` 调高。
5. 如果某个区域暂时不想教学，把该 Hint 的 `enabled` 关闭，不需要删除节点。
6. 若关卡布局改动，只需更新对应 `target_path` / `related_path`，不需要改脚本。

## 目前的刻意保留项

- 没有加入强制教学路线、教学场景或自动传送。
- 没有为玩家直接解出谜题，只在卡住后提供方向。
- 没有把视野系统强制打开，保留现有关卡 `VisionSystem.enabled` 的人工决定。
- 没有加入音效和额外美术资源，方便先人工试玩确认提示密度和位置。
