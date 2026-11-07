# 美术资源接入范围与优先级文档

状态：规划文档，不含代码改动。读取范围：`scripts/*.gd`（player/ghost/door/pressure_plate/death_trap/death_signal_controller/turret/bullet/hammer/gun/breakable/corpse/deadline/vision/tutorial_*）、`scenes/main.tscn`（结构，未改动）、`assets/美术参考/` 全部 10 个子目录及其中的 `.gd`/`.md`/`.tscn`。

## 0. 关键前提发现（影响后续所有建议）

读取 `assets/美术参考/` 里的脚本后发现，这批资源**不是为本项目从零设计的**，而是另一个"交付预览工程"的产物，里面假设了一些本项目目前不存在的东西：

- `assets/美术参考/02_开始页面/程序与场景/scripts/title_screen.gd` 引用 `GameConfig`（全局单例，`assets/美术参考/06_设置页面/程序与场景/scripts/game_config.gd`，本项目 `project.godot` 的 `[autoload]` 里没有任何自动加载单例）、`ScreenFade`（代码里 `await ScreenFade.goto_scene(...)`，本项目没有这个脚本/单例）、目标场景 `res://scenes/test2_entry.tscn`（不存在）。
- 所有 UI 场景（`ui_countdown.tscn`/`ui_controls_panel.tscn`/`ui_pause_menu.tscn`/`ui_settings_menu.tscn`）内部用 `ext_resource` 固定引用 `res://assets/fonts/ui_zh_bold.otf`、`res://assets/fonts/ui_zh_regular.otf`、`res://assets/fonts/ui_hand_title.ttf`、`res://ui/theme/ui_theme.tres`、`res://ui/materials/ui_countdown_*.tres`。本项目目前**没有** `assets/fonts/`、`res://ui/`（主题与材质）这两个目录；倒计时材质/shader 虽然在 `assets/美术参考/04_倒计时/程序与场景/ui/materials|shaders/` 下能找到源文件，但没有被复制到 `res://ui/materials/`、`res://ui/shaders/`。
- `assets/美术参考/02_.../title_screen.gd` 引用的环境音 `res://assets/audio/cycle_ambient.wav`、`horror_sound_bank.gd` 引用的 `res://assets/audio/horror/*.wav`：本项目目前**没有** `assets/audio/` 目录（现有背景乐是 `assets/media/backgroun.wav`，目录名和位置都不同）。
- 唯一已经物理落在本项目里、可以直接引用的，是 `assets/ui/*.png` 和 `assets/ui/svg/*.svg`（图集/图标/按钮四态等，268 个文件，路径即 `res://assets/ui/...`，与文档一致）。

结论：**这批资源是"半成品参考"，不是"开箱即用组件"**。接入时必须：
1. 把 `.wav`、`.otf`/`.ttf` 等素材从 `assets/美术参考/0X_.../` 的原始位置复制到文档约定的项目路径（`assets/audio/`、`assets/fonts/`，`assets/ui/` 已就位不用动）；
2. 把 `assets/美术参考/.../ui/materials|shaders/` 下的倒计时材质/shader 复制到 `res://ui/materials/`、`res://ui/shaders/`（文档引用的固定路径）；
3. 对每个场景脚本做**适配性改写**（不是整体照搬），尤其是 `title_screen.gd` 里对 `GameConfig`/`ScreenFade`/`test2_entry.tscn` 的依赖必须替换成本项目的实际机制（见下文模块说明），`ui_settings_menu.gd`/`ui_hud.gd` 等纯 UI 组件逆向依赖较少，基本可直接用。
4. `原组件API说明.md` 第187-192行"集成顺序建议"提到的 `ui_hud.tscn`、`ui_number_tag.tscn`、`ui_record_state_badge.tscn`、`ui_failure_popup.tscn`、`ui_success_popup.tscn`、`ui_mechanism_status.tscn`、`ui_vision_hint.tscn`、`ui_cursor.gd`、`ui_gallery.tscn` 这些场景/脚本文件**没有在 `assets/美术参考/` 任何子目录的 glob 结果里出现**——文档描述的是完整交付包的内容，但本次拿到的 10 个子目录只包含 02/03/04/05/06/07/08/09/10 对应的部分组件（标题页、操作指引、倒计时、暂停、设置、音效、BGM/SFX、字体说明、验收），`ui_hud` 总装场景和 `ui_number_tag`/`ui_mechanism_status`/`ui_failure_popup`/`ui_success_popup`/`ui_vision_hint`/`ui_cursor`/gallery 均未随附。本文档的优先级和落地方式只覆盖**实际到手的模块**（02/03/04/05/06/07/08/09），HUD 总装与弹层/编号标签/机关图标/光标等组件视为未交付，暂不规划（见第7节"需要人类确认"）。

## 1. 接入优先级分级

### P0（必须，风险低，收益大）

| 模块 | 理由 |
| --- | --- |
| **04 倒计时 UI** | 直接挂在 `player.gd`/`ghost.gd` 节点下，只读 `CountdownTimer.time_left`（`auto_follow_parent_timer`），零侵入、零信号依赖；现有倒计时只是裸 `Label`，替换成手绘风格数字对"循环机制"这个核心玩法的可读性/识别度提升最大，且 player/ghost/warning 三态正好对应游戏唯一的三种身份（本体/副本/即将重置）。风险仅在于美术对齐（字号、锚点）。 |
| **08 原版音效与BGM（机关类）** | `switch.wav`（压力板/门状态切换）、`door.wav`（开门）、`pickup.wav`（拾取锤子/枪）、`rewind.wav`（循环重开）、`tick.wav`（倒计时最后3秒）——这些事件在 `pressure_plate.gd`/`door.gd`/`hammer.gd`/`gun.gd`/`player.gd` 里都已经有现成的信号或调用点（见第3节），只需新增一个轻量 `AudioManager` autoload 做信号→播放映射，不触碰任何判定逻辑。音效反馈对解谜类游戏的操作确认感是刚需，且实现风险最低（纯新增监听，不改时序）。 |
| **03 左下角操作指引面板** | 纯静态 UI，WASD/Space/E/Q 键帽+文字说明，不依赖任何游戏内信号（除了可选的折叠快捷键）。现有项目完全没有操作提示，新玩家上手成本高，这是对现有"弱引导"系统（`tutorial_manager.gd`）的直接美术增强，且 `tutorial_manager.gd` 本身已经证明"纯展示层挂件"模式在本项目可行。 |

### P1（建议，收益中高，需要新增少量信号/脚本改动）

| 模块 | 理由 |
| --- | --- |
| **05 暂停页面** | `ui_pause_menu.gd` 本身不侵入核心逻辑（只操作 `get_tree().paused`），但要做成"Esc 暂停"需要新增一个输入动作 `pause_menu`（当前 `project.godot` 的 `[input]` 没有这个动作，`ui_pause_menu.gd`/`ui_settings_menu.gd` 都靠 `event.is_action_pressed("pause_menu")`，没有这个 action 会直接报错或静默失效，必须先在项目设置里新增）。暂停菜单本身对核心循环零风险（暂停时 `get_tree().paused=true`，`CountdownTimer`、`ghost.gd` 的 `_physics_process` 都会随 `process_mode` 默认值自动冻结），但"重新开始"按钮（`request_restart` → `reload_current_scene`）要确认是否符合"循环重开"的设计意图而不是误导玩家（见第7节确认项）。 |
| **06 设置页面** | 音量滑条本身低风险（写 `AudioServer` 总线）；视野开关直接对接现有 `vision.gd` 的 `enabled` 属性（已验证字段名一致，`ui_settings_menu.gd` 的 `_sync_vision_check()`/`_on_vision_toggled()` 读写的正是 `enabled`），这是现成的集成点。但依赖 05（暂停菜单）才有入口，且需要先建好 `assets/fonts/`、`res://ui/theme/ui_theme.tres`。 |
| **02 开始页面** | 收益高（第一印象、项目完整度），但 `title_screen.gd` 原始代码耦合了不存在的 `GameConfig`/`ScreenFade`/`test2_entry.tscn`，必须改写这部分粘合代码（不是美术层面，是启动流程），工作量和风险比 03/04/05/06 都高。标题页"开始"按钮的目标应改为直接 `change_scene_to_file("res://scenes/main.tscn")`，设置面板的音量滑条可以复用 06 落地后的 `AudioServer` 总线方案而不必依赖 `GameConfig` 单例。 |
| **07 恐怖音效（选用部分）** | `horror_sound_bank.gd` 自带播放封装，但音效风格（"恐怖"）是否契合当前解谜游戏的整体调性需要人类判断（见第7节）；建议仅用于死亡/子弹类事件的"加强版"可选音效，不建议替换 08 的常规 `switch`/`door`/`pickup` 等中性机关音效。 |

### P2（可选，收益较低或依赖较多）

| 模块 | 理由 |
| --- | --- |
| **08 的氛围类 BGM（explore/tension/ending）与氛围音效（cycle_ambient/pressure_pulse/echo/reveal/insert）** | 提升沉浸感，但当前唯一关卡没有"区域"概念，BGM 切换（explore→tension→ending）需要设计触发时机（例如基于副本数量或剩余关卡进度），属于新增玩法外壳而非直接映射现有事件，需要人类明确触发规则。现有 `BackgroundMusic` 节点循环播放单曲 `backgroun.wav`，替换为分段 BGM 之前建议先确认是否要做"动态音乐"这个范围外的功能，否则简单替换成单曲循环的 `bgm_explore.wav` 即可（P0/P1 范围内的最小改动）。 |
| **字体全面替换（Ma Shan Zheng 手写标题等）** | 装饰性，不影响玩法，优先级最低，但实现简单（建主题文件时顺带做）。 |

## 2. 各模块落地方式

| 模块 | 落地方式 | 说明 |
| --- | --- | --- |
| 02 开始页面 | **整场景替换 + 启动流程改写**：新建 `res://scenes/title_screen.tscn`（或直接复用整理后的 `title_screen.gd` 挂到新 `Control` 根节点），`project.godot` 的 `run/main_scene` 改指向它；标题页"开始实验"按钮调用 `get_tree().change_scene_to_file("res://scenes/main.tscn")` 代替原来的 `ScreenFade.goto_scene("res://scenes/test2_entry.tscn")`。`main.tscn` 本身不改。 |
| 03 操作指引面板 | **组件嵌入**：在 `main.tscn` 新增一个 `CanvasLayer`（例如 `UILayer`，`layer` 设一个高于 `Tutorial` 的 `CanvasLayer`(layer=30) 的值，比如 40，避免盖住教学提示；或者并列放置于屏幕不同区域），下挂 `ui_controls_panel.tscn` 实例，锚点设为左下角。纯静态展示，不需要任何新信号。F1 折叠快捷键需要新增一个输入动作（或直接在 `_unhandled_input` 里硬编码 `KEY_F1`，不走 InputMap，影响面更小）。 |
| 04 倒计时 UI | **组件嵌入**：`ui_countdown.tscn` 分别实例化挂到 `player.gd` 根节点和 `ghost.gd` 根节点下（与现有 `CountdownLabel` 同级或替换其位置），`auto_follow_parent_timer=true` 时零代码改动即可读到各自的 `CountdownTimer.time_left`。`style` 属性在 player 实例设为 `&"player"`，ghost 实例设为 `&"ghost"`。现有的 `countdown_label: Label` 节点可以保留（隐藏）作为后备，或在美术验收通过后移除——移除 `CountdownLabel` 节点不影响任何判定逻辑（`player.gd`/`ghost.gd` 里 `countdown_label.text=...` 只是纯展示赋值），但保留它作为零风险后备更安全，先隐藏 `visible=false` 即可。 |
| 05 暂停页面 | **组件嵌入**：`ui_pause_menu.tscn` 挂到 `main.tscn` 新增的 `CanvasLayer`（`process_mode=ALWAYS`，已在脚本里设置）下。需要新增输入动作 `pause_menu`（映射 Esc）。"重新开始"若保留默认行为 `get_tree().reload_current_scene()`，效果等价于强制立即开始新一轮循环（清空所有副本和录制，回到初始状态）——这与现有 Q 键"提前结束本轮"不同，是"丢弃本局全部进度"，需要人类确认是否是预期行为（见第7节）。 |
| 06 设置页面 | **组件嵌入**：`ui_settings_menu.tscn` 可以独立挂（通过暂停菜单的"设置"按钮 `settings_requested` 信号打开），也可以挂在标题页。`vision_target_path` 默认 `../VisionSystem`，需要按实际挂载位置调整为指向 `main.tscn` 里 `system/VisionSystem` 的相对路径，或在代码里显式 `set_vision_target()`。 |
| 07 恐怖音效 | **新增音效播放器节点**（不是场景替换）：把 `horror_sound_bank.gd` 挂到 `main.tscn` 的 `system` 节点下作为子节点（类似现有 `BackgroundMusic`），在死亡/子弹相关事件触发时调用其 `fire()`/`impact()`/`death()` 方法。 |
| 08 原版音效与BGM | **新增轻量 AudioManager 脚本**（新建，不在现有脚本里塞逻辑）：建议新建 `scripts/audio_manager.gd` 作为 `main.tscn` 下的新节点（或 autoload），内部持有若干 `AudioStreamPlayer`，监听各机关/事件信号后播放对应 `.wav`。具体映射见第4节。BGM 替换：现有 `BackgroundMusic` 节点的 `stream` 资源从 `backgroun.wav` 换成 `bgm_explore.wav`（P0/P1 最小改动），分段 BGM 属于 P2。 |
| 09 字体与主题 | **新建目录+主题资源**：复制字体文件到新建的 `res://assets/fonts/` 目录（`ui_zh_regular.otf`/`ui_zh_bold.otf`/`ui_hand_title.ttf`/`ui_countdown_digits.ttf`，连同 `licenses/` 子目录保留授权文件）；新建 `res://ui/theme/ui_theme.tres`（文档里提到的全局主题，本次资源包未直接提供 `.tres` 文件本体，需要根据 `原组件API说明.md` 第155-162行描述的变体清单重新制作，或者如果能找到交付方补发 `ui_theme.tres` 原文件就直接复制）。各 UI 场景的 `ext_resource` 已经硬编码指向这些路径，目录建好后场景即可正常加载字体。 |

## 3. 现有脚本信号/方法现状（供 UI 挂接参考，以当前文件内容为准）

逐一确认了 `player.gd`/`ghost.gd`/`death_trap.gd`/`hammer.gd`/`gun.gd`/`corpse.gd`/`death_signal_controller.gd`/`door.gd`/`pressure_plate.gd`/`turret.gd`/`bullet.gd`/`breakable.gd`/`deadline.gd` 的当前内容，现状如下：

### 已存在、可直接给 UI/音效挂接的信号

- `player.gd:26` `signal jump_state_changed(is_jumping: bool)` —— 已被 `tutorial_manager.gd:59` 使用。
- `player.gd:29` `signal killed` —— 玩家被子弹/死亡装置杀死时触发（`player.gd:102`）。**注意**：`原组件API说明.md:143` 提到 `ui_hud.gd` 会监听 `killed` 显示失败弹层，"若 round_failed 已弹过则不重复"——但本模块（`ui_hud.tscn`）本身未随附（见第0节），所以这个信号目前只需要给音效/未来HUD用，不需要额外处理。
- `player.gd:32` `signal hammer_state_changed(has_hammer: bool)` —— 已被 `tutorial_manager.gd:60` 使用。
- `ghost.gd:12` `signal destroyed` —— 副本被杀死时触发（`ghost.gd:93`）。
- `ghost.gd:13` `signal hammer_state_changed(has_hammer: bool)`。
- `death_trap.gd:15` `signal state_changed(signal_id: int, active: int)` —— 每轮 0→1 边沿触发一次（`death_trap.gd:45`），已被 `death_signal_controller.gd:32` 和 `tutorial_manager.gd:83` 消费。
- `death_signal_controller.gd:14` `signal all_signals_active(active: int)` —— 全部编号点亮/重置时广播。
- `door.gd:8` `signal state_changed(door_id: int, is_open: bool)` —— 门状态变化时广播，已被 `原组件API说明.md` 里 `ui_number_tag.gd`/`ui_mechanism_status.gd` 的"auto_from_parent 连 state_changed"设计假定存在（这两个组件未随附，但信号本身已经就位，可供未来使用）。
- `pressure_plate.gd:7` `signal state_changed(plate_id: int, active: bool)` —— 同上，已被 `door.gd:44` 消费。
- `turret.gd:10` `signal fired(direction: Vector2)` —— 每次开火广播，可直接挂音效（如 07 的 `fire()` 或 08 的某个射击音效）。
- `breakable.gd:7-8` `signal destroyed` / `signal restored` —— 已被 `tutorial_manager.gd:85` 使用。
- `corpse.gd:12` `signal animation_finished` —— 尸体动画播完广播，当前没有任何地方消费它。
- `deadline.gd:4` `signal win` —— 终点触发时广播。

### 已存在、无信号但可直接复用的方法/调用点（供新增信号或直接 hook 用）

- `player.gd:94 on_bullet_hit()` / `ghost.gd:84 on_bullet_hit()` —— 子弹/死亡装置命中统一入口；`killed`/`destroyed` 信号已经在这两个方法内部触发，**不需要新增信号**即可在这两处挂音效（死亡类）。
- `hammer.gd:26 _on_body_entered()` 拾取成功分支（`is_available and body.pickup_hammer()`成立时）、`gun.gd:18` 同理（`body.pickup_gun()`成立时）—— **目前没有拾取成功信号**，`hammer.gd`/`gun.gd` 都没有 `signal picked_up` 之类的广播。要挂音效需要：(a) 新增 `signal picked_up` 并在成功分支 `emit()`（纯新增，不改判定），或 (b) 在 `player.gd`/`ghost.gd` 的 `pickup_hammer()`/`pickup_gun()` 返回 `true` 的分支里新增信号（同样是纯新增表现性钩子，`hammer_state_changed(true)` 本身已经能当"拾到锤子"的代理信号用，`gun.gd` 则完全没有等价信号，拾枪音效需要新增）。
- `door.gd:52 set_open()` —— 状态翻转时已经 `state_changed.emit()`，**不需要新增信号**，音效可以直接监听 `state_changed` 并判断 `is_open` 从 false→true 的边沿。

### 文档提到但确认当前不存在的信号（必须新增才能满足 `原组件API说明.md` 的 HUD 自动联动契约，仅供将来若引入 `ui_hud.tscn` 时参考；本次 P0-P1 范围不依赖它们）

- `round_failed(reason: String)` —— `player.gd` 当前**没有**这个信号。`原组件API说明.md:141` 描述的 `reason` 取值是 `"collision"`/`"bullet"`/`"manual"`，与 `player.gd` 现有的死亡来源（`on_bullet_hit` 统一入口，不区分子弹/装置/碰撞来源）不完全对应，新增时需要决定是否要在 `on_bullet_hit()` 调用点区分来源，或者统一传一个值。
- `round_restarted` —— `player.gd` 当前**没有**这个信号；最接近的挂接点是 `_reset_round_and_spawn_ghost()`（`player.gd:144`），可以在该方法末尾新增 `round_restarted.emit()`，属于纯表现性钩子，不影响其内部任何判定顺序。

以上两个信号属于"未随附组件（`ui_hud.tscn`）的集成契约"，本文档不建议在 P0/P1 阶段新增——没有消费者的信号不要加；如果后续人类决定引入完整 HUD 总装（但该场景本次没有交付），再按需新增。

## 4. 音效/BGM 映射建议

| 游戏事件 | 现有挂接点 | 建议素材 | 备注 |
| --- | --- | --- | --- |
| 拾取锤子 | `player.gd`/`ghost.gd` 的 `pickup_hammer()` 成功分支，或 `hammer_state_changed(true)` | `08/pickup.wav` | 需确认是否新增拾取成功信号（见第3节），或直接监听 `hammer_state_changed(true)` 代理。 |
| 拾取枪 | `player.gd` 的 `pickup_gun()` 成功分支 | `08/pickup.wav`（复用） | 需新增信号，`gun.gd` 当前完全没有等价广播。 |
| 开门（压力板联动门 / 特殊门） | `door.gd:52 set_open()` 的 `state_changed` 边沿 false→true | `08/door.wav` | 现成信号，直接监听即可。 |
| 压力板激活/取消（机关点亮） | `pressure_plate.gd:48 state_changed` | `08/switch.wav`（激活时播） | 现成信号；取消时可不播或播放更轻的变体，由人类定。 |
| 死亡信号装置点亮（death_trap） | `death_trap.gd:45 state_changed` 的 0→1 边沿 | `08/switch.wav` 或单独一个更"重"的音效 | 和压力板区分建议：压力板用 `switch.wav`，死亡装置点亮可以叠加 07 的恐怖音效 `impact()` 强化紧张感（可选）。 |
| 玩家死亡（子弹/装置命中） | `player.gd:94 on_bullet_hit()` / `killed` 信号 | `08/death.wav`，或 07 恐怖死亡系列三选一随机（`horror_sound_bank.gd` 的 `death()`） | 恐怖版本更强调惊悚感，建议作为可选增强，不强制替换 08 的中性 `death.wav`。 |
| 副本死亡（被子弹/装置命中） | `ghost.gd:84 on_bullet_hit()` / `destroyed` 信号 | `08/death.wav`（音量调低或音高微调以区分本体死亡） | 避免和玩家死亡音效完全一致导致误判"自己死了"。 |
| 机关枪开火 | `turret.gd:10 fired` 信号 | 07 恐怖射击系列三选一随机（`horror_sound_bank.gd` 的 `fire()`），或 08 若有通用射击音（08 清单里没有专门的"枪声"，建议用 07） | 07 恐怖音效的射击类音效比 08 更贴合"被机关枪追杀"的紧张感，这是本模块最适合用恐怖音效的场景。 |
| 子弹命中墙体/目标 | `bullet.gd:50 _resolve_hit()` | 07 恐怖冲击系列（`horror_sound_bank.gd` 的 `impact()`） | 可选，命中墙体和命中角色可以用同一个 `impact()` 或区分。 |
| 可破坏物体被破坏 | `breakable.gd:29 destroyed` 信号 | `08/tool.wav`（工具/破坏类） | 现成信号直接监听。 |
| 倒计时最后3秒（玩家） | `player.gd` 的 `countdown_timer.time_left`（需要在新增的 AudioManager 里每帧或用 Timer 判断阈值） 或直接复用 04 倒计时 UI 组件的 `is_warning()` | `08/tick.wav`（循环播放或每秒触发一次） | 建议新增一个一次性 `Timer`（阈值 3 秒）触发而非每帧判断，避免重复触发；04 的 `ui_countdown.gd` 已经有 `is_warning()` 可查询，可作为触发条件参考但不直接耦合。 |
| 循环重开（新一轮开始） | `player.gd:144 _reset_round_and_spawn_ghost()` | `08/rewind.wav` | 现有方法末尾挂一个表现性调用（不改内部逻辑顺序，只在最后追加播放音效的调用，或通过新增的 `round_restarted` 信号间接触发，若该信号被采用）。 |
| 到达终点 | `deadline.gd:4 win` 信号 | `08/checkpoint.wav`（中间点/小目标感）或 `08/sfx_ending.wav`（最终收尾感） | 本关卡 `deadline.gd` 没有区分"中间检查点"和"终局"，当前只有一个 `deadline` 节点（`main.tscn:270`），建议用 `sfx_ending.wav`，因为这是唯一终点；若未来有多关卡再引入 `checkpoint.wav` 区分中间点。 |
| 背景音乐（当前唯一关卡） | 现有 `BackgroundMusic` 节点（`main.tscn:276`） | 最小改动：换成 `08/bgm_explore.wav` 循环；P2 可选：按紧张度切换到 `bgm_tension.wav`，终点播放 `bgm_ending.wav` | 分段 BGM 触发规则需要人类定义（见第7节）。 |
| 开始页面氛围音 | 02 标题页脚本里 `_start_ambient()` | `08/cycle_ambient.wav` | title_screen.gd 原代码已经写好了加载+循环逻辑，只需要把文件从 `assets/美术参考/08_.../cycle_ambient.wav` 复制到 `res://assets/audio/cycle_ambient.wav`。 |

不要求把 07 恐怖音效全部用上；07 建议限定在"机关枪开火/子弹冲击/死亡"这三类强调危险和惊悚感的场景，其余中性机关音效（开门/压力板/拾取/工具）统一用 08，保持整体音效风格不被恐怖音效过度渲染成惊悚游戏。

## 5. 字体与主题接入方式

项目目前没有 `assets/fonts/` 目录，也没有 `Theme` 资源（`res://ui/theme/ui_theme.tres` 不存在）。接入方式：

1. 新建 `res://assets/fonts/` 目录，从 `assets/美术参考/09_共用UI素材与字体说明/字体许可证/` 对应的字体文件实际物理位置（文档提到字体文件本体应在交付包的 `assets/fonts/` 下，但本次拿到的 10 个子目录里只看到了 `字体许可证/*.txt`（许可证文本）和说明 `.md`，**没有看到 `.otf`/`.ttf` 字体文件本体**——glob 全项目 `**/*.ttf`/`**/*.otf` 均为空）。**这是一个缺口：字体文件本体未随附，只有许可证文本和使用说明**，需要人类确认字体文件从哪里补齐（见第7节）。
2. 字体到位后，新建 `res://ui/theme/ui_theme.tres`，按 `原组件API说明.md:155-162` 描述的变体清单（`Muted`/`Caption`/`Bold`/`BoldMuted`/`BoldSmall`/`Danger`/`HandTitle`/`HandMint`/`HandDanger`/`HandSmall`/`HandSmallMuted`/`KeyNum` 等 Label 变体，`MenuBigButton` 等 Button 变体，`HudPanel`/`MenuPanel`/`BadgePill` 等 PanelContainer 变体）逐一配置字体引用和九宫格边距。由于各 UI 场景的 `.tscn` 文件内部已经各自内嵌了一份完整的 `Theme` 资源定义（每个 `.tscn` 都有自己的 `Bold/fonts/font = ExtResource(...)` 等条目，见 `ui_countdown.tscn`/`ui_pause_menu.tscn`/`ui_settings_menu.tscn`/`ui_controls_panel.tscn` 各自文件内的主题 override 段），实际上**可以不单独抽取全局 `ui_theme.tres`，先让各场景使用自带的内嵌主题跑起来，全局主题作为后续统一换肤时的优化项**（P2）。
3. 复制授权文件 `licenses/*_OFL.txt` 和 `NOTICE.md` 到 `res://assets/fonts/licenses/`，保持 OFL 许可合规（允许嵌入游戏分发，不能单独售卖字体）。

## 6. 明确声明：不能做的事

- 不改 `scenes/main.tscn` 的机关位置、数量、连接关系（压力板编号、门编号、死亡装置编号、信号控制器的 `total_signals`/`door_path` 等 `@export` 数值一律不动）。
- 不改 `scripts/player.gd`、`scripts/ghost.gd` 的移动/跳跃/录制回放/循环重置/死亡核心判定逻辑（`_physics_process` 的移动计算、`_reset_round_and_spawn_ghost()` 的执行顺序、`on_bullet_hit()` 的死亡流程时序等）。允许的改动范围仅限：**新增信号**（如第3节提到的拾取成功信号）、**在现有方法末尾追加纯表现性调用**（如播放音效、触发视觉特效），不允许改变任何已有赋值顺序、提前或延后任何现有逻辑分支。
- 不改倒计时时长等已调好的数值（`player.gd`/`ghost.gd` 的 `countdown_timer.wait_time`、`jump_distance`/`jump_duration`、`hammer_use_range`、`gun_fire_cooldown` 等所有 `@export` 数值参数）。
- 不引入新关卡（`main.tscn` 是唯一关卡，`deadline.gd` 的 `next_scene_path` 留空表示当前是最终终点，不新增 `next_scene_path` 指向的下一关场景）。
- 不替换/不绕过 `scripts/tutorial_manager.gd`/`tutorial_hint.gd` 的弱引导逻辑（03 操作指引面板是新增的"静态常驻提示"，与"动态弱引导"是两套并行系统，不要互相替代或合并判断逻辑）。

## 7. 风险点与需要人类确认的事项

1. **字体文件本体缺失**：`assets/美术参考/09_共用UI素材与字体说明/` 下只有许可证文本（`字体许可证/*.txt`）和说明文档，没有实际的 `.otf`/`.ttf` 文件（全项目 glob 确认为空）。在拿到字体文件本体之前，依赖这些字体的场景（04/05/06 的 `.tscn` 内嵌 `ext_resource` 指向 `res://assets/fonts/...`）无法在编辑器里正常打开/预览，会报资源缺失。**需要人类提供字体文件或确认改用项目当前能找到的替代字体**。
2. **`assets/音频`文件的实际存放目录**：08 的 BGM/SFX 和 07 的恐怖音效当前都在 `assets/美术参考/07_.../`、`assets/美术参考/08_.../` 下，需要复制到 `res://assets/audio/`（07 的子目录结构还要保持 `assets/audio/horror/` 这一层，因为 `horror_sound_bank.gd:5` 的 `ROOT` 常量硬编码了这个路径）。这是机械的文件搬运操作，风险低，但需要人类确认搬运后是否删除/保留 `assets/美术参考/` 原始目录（建议保留作为美术源文件备份，不占用运行时资源）。
3. **05 暂停菜单的"重新开始"语义**：`request_restart()` 默认行为是 `get_tree().reload_current_scene()`，相当于把整局（所有已录制的副本、循环进度）清零重来，这和现有 Q 键"提前结束当前循环（end_round_early）"是完全不同粒度的操作（Q 是"收尾这一轮，继续下一轮"，暂停菜单重开是"整局推倒重来"）。**需要人类确认**这个语义是否符合预期，还是应该让"重新开始"按钮改成等价于触发一次 `player.gd` 的完整重置但不清空已有副本历史（目前没有这样的方法，需要新增，属于范围变化，建议先用默认的整局重开语义，除非人类要求改）。
4. **07 恐怖音效的调性契合度**：当前游戏整体是解谜向玩法（压力板/门/锤子/跳跃），07 恐怖音效（"实验体崩解""窒息回声""循环吞噬"等命名）明显偏惊悚风格。第4节的映射建议把恐怖音效限定在机关枪/子弹/死亡场景，但**是否要引入"恐怖"这个调性标签本身**，还是保持中性解谜氛围（全部用08的中性音效），需要人类定调。
5. **分段 BGM 触发规则（P2）**：`bgm_explore`/`bgm_tension`/`bgm_ending` 三段式音乐如果要接入，需要定义"什么时候算 tension"（比如副本数量超过某个阈值？剩余倒计时进入警告区？死亡次数累积？）。这是新的游戏状态判断逻辑，不是简单的事件映射，**需要人类明确规则**，否则建议 P2 阶段只做单曲循环替换（最小改动，不引入新状态判断）。
6. **`ui_hud.tscn`/`ui_number_tag.tscn`/`ui_mechanism_status.tscn`/`ui_failure_popup.tscn`/`ui_success_popup.tscn`/`ui_vision_hint.tscn`/`ui_cursor.gd`/gallery 均未随附**（见第0节）：如果人类后续希望做"失败/成功弹层""机关状态小图标""HUD总装自动联动"这类体验，需要先补齐这些场景文件（找交付方要，或基于现有组件自行搭建），当前文档范围内的 P0-P1 不依赖它们。
7. **`02 开始页面` 的 `title_screen.gd` 改写范围**：原脚本里 `GameConfig`/`ScreenFade` 的替换方案（第2节已给出：直接 `change_scene_to_file`，音量滑条改接 `AudioServer` 总线）属于"让它能跑起来的最小改写"，但原脚本里的 `GameConfig.session_iteration`、`fullscreen` 存档等功能如果人类认为有价值保留，需要确认是否要顺带引入一个简化版的本地设置存档单例（范围略微扩大，建议先确认是否需要，否则 P0/P1 阶段可以先不做持久化，每次用引擎默认值）。

---

文档结束。如需调整优先级分级或某一模块的落地细节，请在确认第7节各项后告知，再进入具体实现阶段。
