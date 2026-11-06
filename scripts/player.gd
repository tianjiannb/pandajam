extends CharacterBody2D

## 2D 俯视角色：WASD/方向键八方向移动。
## 录制整个 12 秒倒计时窗口内每一物理帧的位置与朝向；
## 倒计时结束时：生成一个副本循环回放该段录制，自己回到出生点，重新开始下一轮。

@export var speed := 240.0
@export var acceleration := 1600.0
@export var ghost_scene: PackedScene
@export var corpse_scene: PackedScene

## 跳跃功能（可单独开关）：空格向最近移动方向跳跃一段固定距离。
@export var jump_enabled := true
@export var jump_distance := 96.0
@export var jump_duration := 0.25

## 玩家状态信号：一般状态(false) / 跳跃状态(true)。
signal jump_state_changed(is_jumping: bool)

## 被机关枪子弹命中（已按倒计时结束流程归位并生成本轮副本）时广播。
signal killed

var is_jumping := false
var _jump_direction := Vector2.RIGHT
var _jump_time_left := 0.0
var _last_move_dir := Vector2.RIGHT

@onready var countdown_timer: Timer = $CountdownTimer
@onready var countdown_label: Label = $CountdownLabel

var _start_transform: Transform2D
var _recording: Array[Transform2D] = []
var _ghost_count := 0


func _ready() -> void:
	add_to_group("plate_activator")
	add_to_group("player")
	# 机关枪可命中玩家；副本同样加入该组，命中判定与玩家一致。
	add_to_group("bullet_target")
	_start_transform = global_transform
	_update_countdown_label()
	countdown_timer.timeout.connect(_on_countdown_timeout)


func _process(_delta: float) -> void:
	_update_countdown_label()


func _update_countdown_label() -> void:
	countdown_label.text = str(int(ceil(countdown_timer.time_left)))


func _on_countdown_timeout() -> void:
	_reset_round_and_spawn_ghost()


## 玩家死亡：立即清空倒计时，统一由 timeout 执行重置。
## 新循环中不保留玩家尸体；副本死亡留下的尸体也随本次重置统一清理。
func on_bullet_hit() -> void:
	countdown_timer.stop()
	_on_countdown_timeout()
	killed.emit()


## 尸体只是视觉残留：不碰撞、不触发机关；下一次任意重置时消失。
func _spawn_corpse(death_transform: Transform2D) -> void:
	if corpse_scene == null:
		return
	var corpse: Node2D = corpse_scene.instantiate()
	corpse.is_ghost_corpse = false
	get_parent().add_child(corpse)
	corpse.global_transform = death_transform


func _clear_corpses() -> void:
	for corpse in get_tree().get_nodes_in_group("corpses"):
		corpse.queue_free()


## 一轮结束的统一流程：生成本轮副本 -> 自己归位 -> 清空录制 -> 重新开始倒计时。
func _reset_round_and_spawn_ghost() -> void:
	_clear_corpses()
	_spawn_ghost_from_recording()
	global_transform = _start_transform
	velocity = Vector2.ZERO
	if is_jumping:
		is_jumping = false
		jump_state_changed.emit(false)
	_recording.clear()
	countdown_timer.start()


func _spawn_ghost_from_recording() -> void:
	if _recording.is_empty() or ghost_scene == null:
		return
	var ghost: Node2D = ghost_scene.instantiate()
	_ghost_count += 1
	# 显式命名，避免同名实例被 Godot 自动改成 "@Ghost@2" 导致查找失败。
	ghost.name = "Ghost%d" % _ghost_count
	get_parent().add_child(ghost)
	ghost.start_replay(_recording.duplicate())


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.0:
		_last_move_dir = input_dir.normalized()

	if jump_enabled and not is_jumping and Input.is_action_just_pressed("jump"):
		_start_jump()

	if is_jumping:
		# 跳跃期间：固定方向、固定速度，在 jump_duration 内位移 jump_distance。
		velocity = _jump_direction * (jump_distance / jump_duration)
		_jump_time_left -= delta
		if _jump_time_left <= 0.0:
			is_jumping = false
			jump_state_changed.emit(false)
	else:
		# 2D 逻辑：玩家不随移动方向旋转，保持固定朝向，
		# 头顶倒计时标签因此始终位于屏幕上方、保持水平。
		var target_velocity := input_dir * speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)

	move_and_slide()

	_recording.append(global_transform)


func _start_jump() -> void:
	is_jumping = true
	_jump_direction = _last_move_dir
	_jump_time_left = jump_duration
	jump_state_changed.emit(true)
