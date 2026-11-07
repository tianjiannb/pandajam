# 队长游戏 UI 资产（ui-godot 交付）

基准分辨率 1280×720，stretch = `canvas_items`，纹理过滤 nearest。所有场景都可直接实例化进游戏场景；
除特别说明外，根节点尺寸已按基准分辨率写死，游戏里无需再拉伸。

## 目录

```
ui/
  scenes/     13 个可实例化场景（见下表）
  scripts/    组件脚本（API 在此文件「组件 API」一节）
  theme/      ui_theme.tres 全局主题
  gallery/    ui_gallery.tscn 独立展台（F6 直接运行）
  materials/  Lead 提供的倒计时手绘材质（只读）
  shaders/    Lead 提供的倒计时手绘 shader（只读）
```

美术位图统一位于 `assets/ui/`，字体位于 `assets/fonts/`，均按文件名引用，替换同名文件即可换皮。

## 组件清单（spec §3.4）

| 场景 | 中文名 | 尺寸 | 说明 |
| --- | --- | --- | --- |
| `ui_countdown.tscn` | 倒计时 | 96×56 | 图集数字 + 手绘材质；普通 / 警告 / 副本三种身份 |
| `ui_number_tag.tscn` | 编号标签 | 32×32 | 1–9，压力板 / 门两种图集与着色 |
| `ui_record_state_badge.tscn` | 录制徽章 | 148×36 | 录制中 / 回放中 / 循环开始 |
| `ui_controls_panel.tscn` | 操作提示 | 436×206（折叠 436×56） | WASD/方向键/Space/E/Q，Q 带「自杀」图标 |
| `ui_failure_popup.tscn` | 失败弹层 | 600×180 | collision / bullet / manual，0.8–1.5s 淡出 |
| `ui_success_popup.tscn` | 成功弹层 | 640×200 | 抵达出口 / 本轮挑战完成 |
| `ui_pause_menu.tscn` | 暂停菜单 | 全屏 | 继续 / 重新开始 / 设置 / 退出，键盘 + 鼠标 |
| `ui_settings_menu.tscn` | 设置菜单 | 全屏 | 音效 / 音乐音量、视野限制、恢复默认、返回 |
| `ui_mechanism_status.tscn` | 机关状态图标 | 24×24 | plate / door / turret 六态 |
| `ui_vision_hint.tscn` | 视野提示 | 430×42 | 默认不常驻，`show_hint()` 显示 3s |
| `ui_hud.tscn` | 总装 HUD | 全屏 CanvasLayer | 上列组件的总装 + 状态联动 |
| `ui/scripts/ui_cursor.gd` | 自绘光标 | — | 32×32，热点 (2,2)，按钮 hover/press 切换 |

## 组件 API（Lead 集成用）

### ui_countdown.gd
```gdscript
set_time_left(t: float)            # 也可用 set_time(t)（别名）
set_style(style)                   # &"player" / &"ghost"
set_digits_visible(v: bool)        # 只藏数字、保留底板
is_warning() -> bool
var warning_threshold := 3.0       # 剩余 ≤3s 自动切 warning 材质 + 抖动
var show_panel := true
var auto_follow_parent_timer := true
    # true 时每帧读父节点 CountdownTimer.time_left（player/ghost 直接挂在角色下即可）
```
数字由 `ui_countdown_digits.png`（768×80，12 格 64×80）逐位 AtlasTexture 显示，
每位复制一份材质并写 `atlas_cell_uv` 与独立 `time_seed`，因此每位独立抖动不串格。

### ui_number_tag.gd
```gdscript
set_number(n: int)                 # 1–9，自动 clamp
set_kind(kind)                     # &"plate" / &"door"
set_state(active: bool)            # plate: active/idle；door: open/closed
set_state_name(state_name)         # &"idle" / &"active" / &"closed" / &"open"
var auto_from_parent := true       # 读父节点 plate_id / door_id，并自动连 state_changed
```

### ui_mechanism_status.gd
```gdscript
set_kind(kind)                     # &"plate" / &"door" / &"turret"
set_state(state_name)              # idle/active/closed/open/alert/cooling
var auto_from_parent := true       # plate/door 连 state_changed；turret 轮询 is_cooling()、连 fired
```

### ui_record_state_badge.gd
```gdscript
set_state(state)                   # &"recording" / &"replay" / &"loop_start" / &"idle"
set_text_override(text)            # 可选
var auto_revert_loop := true       # loop_start 闪 0.8s 后回落到上个状态
```

### ui_controls_panel.gd
```gdscript
set_collapsed(v) / toggle_collapsed() / is_collapsed()
var collapsed := false
```

### ui_failure_popup.gd / ui_success_popup.gd
```gdscript
# 失败
show_failure(reason: String)       # "collision" / "bullet" / "manual"
is_showing() -> bool
# 成功
show_success(text := "")           # 标题可覆盖，副标题固定「本轮挑战完成，记录已保存」
is_showing() -> bool
# 两者都有 set_preview() 供 gallery 静态展示
```
淡入 0.12/0.15s → 保持 0.75/0.9s → 淡出 0.3s，总时长均在 0.8–1.5s 内。

### ui_vision_hint.gd
```gdscript
show_hint(text := "", duration := -1.0)   # 默认 3s；duration <= 0 常驻
hide_hint()
```

### ui_pause_menu.gd
```gdscript
open() / close(keep_paused := false) / toggle() / is_open() / resume()
request_restart() / request_quit()
signal resumed / restart_requested / settings_requested / quit_requested
var handle_escape := true    # 独立使用时 Esc 关闭
var pause_tree := true       # 独立使用时自己 get_tree().paused；由 HUD 集成时 HUD 会置 false
```

### ui_settings_menu.gd
```gdscript
open() / close() / is_open()
set_vision_target(node)            # 视野开关驱动的节点（游戏里传 VisionSystem）
get_values() -> Dictionary         # {sfx, music, vision}
set_values(sfx, music, vision)     # 0.0–1.0
signal settings_changed(sfx, music, vision)
signal closed
var vision_target_path := NodePath("../VisionSystem")
```
音量写 `AudioServer` 的 `SFX` / `Music` 总线；总线不存在时回退 `Master` 并在对应行显示说明。
视野开关写目标节点的 `enabled` 属性；找不到目标时该行禁用并提示。

### ui_hud.gd（总装，根是 CanvasLayer，`process_mode = ALWAYS`）
```gdscript
show_failure(reason)               # collision / bullet / manual
show_success(text := "")
flash_loop_start()                 # 徽章闪「循环开始」，0.9s 内不被自动状态覆盖
set_recording_state(state)         # recording / replay / loop_start / idle
set_recording(bool)                # 旧接口兼容
set_ghost_count(n) / get_ghost_count() -> int
toggle_pause() / open_pause() / is_pause_open() -> bool
open_settings()
set_vision_hint_visible(v: bool)
toggle_controls_panel()
debug_trigger(action)              # success / fail_collision / fail_bullet / fail_manual / pause / settings
get_pause_menu() / get_settings_menu() -> Node
signal restart_requested / quit_requested / settings_changed(sfx, music, vision)
var auto_state := true             # 按 ghosts 组数量自动切录制/回放
var auto_wire_game := true         # 自动连组 "player" 的 round_failed / round_restarted / killed
```
自动联动（所有连接都带 `has_signal` 保护，player.gd 还没加信号时不会报错）：
- `round_failed(reason)` → `show_failure(reason)`
- `round_restarted` → `flash_loop_start()`
- `killed` → 失败弹层（若 `round_failed` 已弹过则不重复）
- `ghosts` 组数量 > 0 → 徽章「回放中」，否则「录制中」
- Esc（动作 `pause_menu`，回退 `ui_cancel`/KEY_ESCAPE）按 设置 → 暂停 → 打开的层叠顺序关闭
- 设置菜单自动找场景里的 `VisionSystem` 节点（`../VisionSystem` / `../../VisionSystem` / 全局搜索）

### ui_cursor.gd
```gdscript
set_pointer_state(state: StringName)   # 可选 &"default" / &"hover" / &"press"
var enabled := true
```
`_ready` 里 `Input.set_custom_mouse_cursor()`，实时检测 hover 的 `BaseButton` / `Slider` 切手型。

## 主题 ui/theme/ui_theme.tres

- 默认字体：`assets/fonts/ui_zh_regular.otf`（Noto Sans SC Regular）；大标题用 `ui_hand_title.ttf`（Ma Shan Zheng）。
- Button：`ui_button_normal/hover/pressed/disabled.png` 四态 StyleBoxTexture，九宫格 margin 18/14；focus 为 MINT 边框。
- Label 变体：`Muted` / `Caption` / `Bold` / `BoldMuted` / `BoldSmall` / `Danger` / `HandTitle` / `HandMint` / `HandDanger` / `HandSmall` / `HandSmallMuted` / `KeyNum`。
- PanelContainer 变体：`HudPanel`（hud 面板）、`MenuPanel`（menu 面板）、`BadgePill`（徽章）。
- Button 变体：`MenuBigButton`（**不能**命名为 `MenuButton`，与内置类冲突）。
- 九宫格 margin：countdown 14 / failure 24 / success 28 / menu 36 / hud 20 / badge pill 18,12 / button 18,14。

## gallery

`ui/gallery/ui_gallery.tscn` 独立运行（F6），7 页：
1. 组件总览（倒计时三身份、编号、徽章、机关图标、视野提示、配色）
2. 操作提示 / 键帽 / 按钮四态 + 焦点 / 字体
3. 失败弹层三态
4. 成功弹层 / 九宫格面板 / 通用图标 / 光标 / HSlider + CheckButton
5. 暂停菜单
6. 设置菜单
7. HUD 总装在仿真实验室画面上的效果

快捷键：`1–7` 翻页、`←/→` 翻页、`G` 倒计时普通 12s、`H` 倒计时警告 2s、`J` 副本 12s、`F` 循环重播三种失败。
环境变量：`GALLERY_PAGE=1..7` 指定初始页；`GALLERY_HUD_ACTION=pause|settings|fail_bullet|fail_collision|fail_manual|success` 在 page7 的 HUD 上 0.5s 后自动触发对应状态（failure/success 每 0.9s 重放一次，便于截图）。

截图命令（工程根目录，窗口模式，勿与其它 Godot 实例同时运行，否则窗口拿不到渲染帧）：

```powershell
$env:GALLERY_PAGE='1'
.\tools\godot\shot.ps1 -Scene res://ui/gallery/ui_gallery.tscn `
  -Out D:\多劳多得队不队\UI交付\screenshots\ui_gallery_1280x720.png `
  -Res 1280x720 -Frames 60 -Wait 1.0
```

## 集成顺序建议

1. 玩家/副本场景根下加 `ui_countdown.tscn`（脚本会自动跟随 `CountdownTimer`）。
2. 压力板/门场景根下加 `ui_number_tag.tscn` 与 `ui_mechanism_status.tscn`（自动读 `plate_id` / `door_id`、连 `state_changed`）。
3. 主场景加 `ui_hud.tscn`（CanvasLayer）。player.gd 补上 `round_failed(reason)` / `round_restarted` 信号后 HUD 会自动接管失败弹层与循环开始徽章。
4. 设置菜单里的视野开关默认找 `../VisionSystem`；若节点路径不同，实例化后调 `hud.get_settings_menu().set_vision_target(节点)`。

## 已知说明

- `assets/ui/*.png` 已由 ui-pixels / ui-vectors 重绘覆盖，场景只依赖文件名与尺寸，不需要改引用。
- `ui_countdown_digits.png` 仍是 768×80 / 12 格 64×80；数字显示尺寸 38×48、底板 96×56（数字四周留 ~10px 墨框）。
- 素材替换后需要 `--headless --import` 刷新导入缓存（由 Lead 统一执行，避免并发 import）。
- 所有场景 11 个 `.tscn` + gallery 均以 `ResourceSaver.save()` 构建，构建脚本在 `tools/godot/build_ui.gd`、`tools/godot/build_gallery.gd`（改脚本后重新构建即可再生场景）。
- `tools/godot/build_ui.gd` 打包 HUD 时不会改写实例场景（如 PauseMenu/SettingsMenu/Badge）内部节点的 owner，只把实例根按 `instance=` 引用保存；若手动改构建脚本，务必保留这一规则，否则加载后实例内部节点会重复。重建 11 个场景命令：
  `& 'D:\c\Godot_v4.7.2-stable_win64.exe' --headless --path 'D:\多劳多得队不队\UI交付' --script res://tools/godot/build_ui.gd`
