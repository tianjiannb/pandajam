extends CharacterBody2D

## 副本：逐物理帧回放一段录制好的 Transform2D 序列，无限循环。
## 与玩家功能一致：带碰撞体、属于 plate_activator 组，可触发压力板等机关。
## 使用独立碰撞层 2、掩码 0：不与玩家/墙体发生推挤或阻挡（纯位置回放），
## 但压力板等 Area2D（掩码含层 2）能正常检测到它。
## 视作"过去的自己"：与玩家共用子弹命中判定（bullet_target 组），被子弹打中即留下尸体并消失。

## 被击杀时广播（子弹/死亡装置等）。副本不会因此消失：游戏核心规则是
## 保留所有历史副本，死亡只是让它在原地留下尸体标记，直到下一次循环重置
## 时回到录制起点、恢复正常回放。
signal destroyed
signal hammer_state_changed(has_hammer: bool)

var has_hammer := false
@export var hammer_use_range := 72.0

## 与玩家共用同一张序列图；移动时同样靠左右摇晃 + 轻微起伏表现动效（不换走路帧）。
@export var walk_wobble_degrees := 10.0
@export var walk_wobble_speed := 14.0
@export var walk_bob_height := 3.0

var _frames: Array[Transform2D] = []
var _actions: Array[bool] = []
var _playhead := 0
var _cycle_duration := 12.0

## 本轮是否已死亡：死亡后停留在原地（不再前进播放头），直到 restart_cycle()。
var _dead := false

## 回放时根据上一帧与当前帧的位移方向选动画/摇摆，而非实时输入。
var _prev_position := Vector2.ZERO
var _sprite_home := Vector2.ZERO
var _wobble_phase := 0.0

@onready var countdown_timer: Timer = $CountdownTimer
@onready var countdown_label: Label = $CountdownLabel
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("ghosts")
	add_to_group("plate_activator")
	add_to_group("bullet_target")
	countdown_timer.timeout.connect(restart_cycle)
	_sprite_home = _sprite.position
	_sprite.play(&"idle")
	_apply_random_tint()
	# 手动调用 start_replay 时可能在 add_child 之前设置位置；入树后恢复首帧，
	# 防止 Node2D 的通知流程把全局位置重置为默认值。
	if not _frames.is_empty():
		global_transform = _frames[0]
		_prev_position = global_position
		countdown_timer.wait_time = _cycle_duration
		countdown_timer.start()
	_update_countdown_label()


## 每个副本实例随机生成一个色调，让多个历史副本在视觉上可以互相区分，
## 同时与玩家当前使用的正常贴图颜色区别开（"过去的自己"的既定美术意图）。
func _apply_random_tint() -> void:
	var material := _sprite.material as ShaderMaterial
	if material == null:
		return
	# 复制一份独立的 ShaderMaterial，避免所有副本共享同一个资源实例改动互相影响。
	material = material.duplicate() as ShaderMaterial
	_sprite.material = material
	var hue := randf()
	var color := Color.from_hsv(hue, 0.55, 0.95, 1.0)
	material.set_shader_parameter("tint_color", color)


func _process(_delta: float) -> void:
	_update_countdown_label()


func _update_countdown_label() -> void:
	countdown_label.text = str(int(ceil(countdown_timer.time_left)))


## 被击杀（子弹/死亡装置等）：在原地留下尸体标记，但副本本身不会消失。
## 游戏核心规则是保留所有历史副本：死亡只是让它停在原地直到下一轮重置，
## 重置后回到录制起点，恢复正常回放（与之前完全一样）。
func on_bullet_hit() -> void:
	if _dead:
		return
	_dead = true
	var corpse: Node2D = (load("res://scenes/corpse.tscn") as PackedScene).instantiate()
	corpse.is_ghost_corpse = true
	get_parent().add_child(corpse)
	corpse.global_transform = global_transform
	visible = false
	destroyed.emit()


func start_replay(frames: Array[Transform2D], actions: Array[bool] = [], cycle_duration: float = 12.0) -> void:
	_frames = frames
	_actions = actions
	_cycle_duration = cycle_duration
	_playhead = 0
	_dead = false
	visible = true
	reset_hammer()
	_reset_visual()
	if _frames.is_empty():
		return
	global_transform = _frames[0]
	_prev_position = global_position
	if is_node_ready():
		countdown_timer.wait_time = _cycle_duration
		countdown_timer.start()


## 全局循环边界：回到本轮录制的起点，清除临时能力并重启自己的倒计时。
## 由玩家重置流程统一调用；自己的 Timer 超时也走同一入口。
## 即使本轮已死亡也会在这里复活：核心规则是副本永不真正消失。
func restart_cycle() -> void:
	_playhead = 0
	_dead = false
	visible = true
	reset_hammer()
	_reset_visual()
	if not _frames.is_empty():
		global_transform = _frames[0]
		_prev_position = global_position
	if is_node_ready():
		countdown_timer.stop()
		countdown_timer.start()
		_update_countdown_label()


## 循环边界重置时让角色姿态立刻回正（与 player.gd 的 _reset_visual 一致）。
func _reset_visual() -> void:
	_wobble_phase = 0.0
	if _sprite != null:
		_sprite.rotation = 0.0
		_sprite.position = _sprite_home


func pickup_hammer() -> bool:
	if has_hammer:
		return false
	has_hammer = true
	hammer_state_changed.emit(true)
	return true


func reset_hammer() -> void:
	if has_hammer:
		has_hammer = false
		hammer_state_changed.emit(false)


func pickup_gun() -> bool:
	return false


func reset_gun() -> void:
	pass


func use_hammer() -> void:
	if not has_hammer:
		return
	for object in get_tree().get_nodes_in_group("breakable"):
		if object is Node2D and global_position.distance_to(object.global_position) <= hammer_use_range:
			object.destroy()


func _physics_process(delta: float) -> void:
	if _frames.is_empty() or _dead:
		return
	global_transform = _frames[_playhead]
	if _playhead < _actions.size() and _actions[_playhead]:
		use_hammer()
	_update_animation(delta)
	_prev_position = global_position
	# 循环边界由倒计时统一控制；尾帧之后停留在原地，等待同步释放。
	_playhead = mini(_playhead + 1, _frames.size() - 1)


## 按回放的逐帧位移方向选择四向动画；停止移动时回到 idle。与 player.gd 的
## _direction_anim_name/_update_animation 逻辑保持一致，直接复用回放位移作为"输入方向"。
func _direction_anim_name(dir: Vector2) -> StringName:
	if absf(dir.x) >= absf(dir.y):
		return &"right" if dir.x > 0.0 else &"left"
	return &"down" if dir.y > 0.0 else &"up"


func _update_animation(delta: float) -> void:
	var movement := global_position - _prev_position
	var moving := movement.length() > 0.5
	if not moving:
		if _sprite.animation != &"idle":
			_sprite.play(&"idle")
		_wobble_phase = 0.0
		var back := minf(1.0, delta * 14.0)
		_sprite.rotation = lerpf(_sprite.rotation, 0.0, back)
		_sprite.position = _sprite.position.lerp(_sprite_home, back)
		return

	_sprite.play(_direction_anim_name(movement))
	_wobble_phase += delta * walk_wobble_speed
	var swing := sin(_wobble_phase)
	_sprite.rotation = deg_to_rad(walk_wobble_degrees) * swing
	_sprite.position = _sprite_home + Vector2(0.0, -absf(swing) * walk_bob_height)
