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

## 移动表现：不另外做走路帧，用角色左右摇晃 + 轻微上下起伏表现动效。
@export var walk_wobble_degrees := 10.0
@export var walk_wobble_speed := 14.0
@export var walk_bob_height := 3.0

## 跳跃不做独立动画：起跳瞬间生成一次刀光着色器特效。
const JUMP_SLASH_SCENE := preload("res://scenes/jump_slash.tscn")

## 玩家状态信号：一般状态(false) / 跳跃状态(true)。
signal jump_state_changed(is_jumping: bool)

## 被机关枪子弹命中（已按倒计时结束流程归位并生成本轮副本）时广播。
signal killed

## 锤子能力状态：拾取锤子后为 true，新循环开始重置为 false。
signal hammer_state_changed(has_hammer: bool)

var has_hammer := false
@export var hammer_use_range := 72.0

var is_jumping := false
var _jump_direction := Vector2.RIGHT
var _jump_time_left := 0.0
var _last_move_dir := Vector2.RIGHT

@onready var countdown_timer: Timer = $CountdownTimer
@onready var countdown_label: Label = $CountdownLabel
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

## 角色贴图的原始局部位置，摇晃时以此为中心。
var _sprite_home := Vector2.ZERO
var _wobble_phase := 0.0

var _start_transform: Transform2D
var _recording: Array[Transform2D] = []
var _recorded_actions: Array[bool] = []
var _ghost_count := 0


func _ready() -> void:
	add_to_group("plate_activator")
	add_to_group("player")
	# 机关枪可命中玩家；副本同样加入该组，命中判定与玩家一致。
	add_to_group("bullet_target")
	_start_transform = global_transform
	_sprite_home = _sprite.position
	_sprite.play(&"idle")
	_update_countdown_label()
	countdown_timer.timeout.connect(_on_countdown_timeout)
	# 显式启动，避免场景重新保存后 autostart 标记丢失导致副本机制停止。
	countdown_timer.start()


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
	for hammer in get_tree().get_nodes_in_group("hammers"):
		hammer.reset_pickup()
	for actor in get_tree().get_nodes_in_group("bullet_target"):
		actor.reset_hammer()
	# 可破坏物体也随每轮循环恢复原状。
	for object in get_tree().get_nodes_in_group("breakable"):
		object.restore()
	# 所有旧副本与玩家在同一循环边界归位并重启倒计时。
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		ghost.restart_cycle()
	_spawn_ghost_from_recording()
	global_transform = _start_transform
	velocity = Vector2.ZERO
	_reset_visual()
	if is_jumping:
		is_jumping = false
		jump_state_changed.emit(false)
	_recording.clear()
	_recorded_actions.clear()
	countdown_timer.start()


func _spawn_ghost_from_recording() -> void:
	if _recording.is_empty() or ghost_scene == null:
		return
	var ghost: Node2D = ghost_scene.instantiate()
	_ghost_count += 1
	# 显式命名，避免同名实例被 Godot 自动改成 "@Ghost@2" 导致查找失败。
	ghost.name = "Ghost%d" % _ghost_count
	# 先写入首帧位置，再进入场景树，避免出生时短暂出现在玩家归位点上。
	ghost.start_replay(_recording.duplicate(), _recorded_actions.duplicate(), countdown_timer.wait_time)
	get_parent().add_child(ghost)


## 锤子是能力而非背包物品：碰到锤子后由锤子道具调用，返回是否成功拾取。
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


## 按 E 破坏附近带有 breakable 标签的物体；没有能力时不产生效果。
func use_hammer() -> void:
	if not has_hammer:
		return
	for object in get_tree().get_nodes_in_group("breakable"):
		if object is Node2D and global_position.distance_to(object.global_position) <= hammer_use_range:
			object.destroy()


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
	_update_animation(delta)

	if Input.is_action_just_pressed("use_hammer"):
		use_hammer()

	_recording.append(global_transform)
	_recorded_actions.append(Input.is_action_just_pressed("use_hammer"))


func _start_jump() -> void:
	is_jumping = true
	_jump_direction = _last_move_dir
	_jump_time_left = jump_duration
	jump_state_changed.emit(true)
	_spawn_jump_slash()


## 起跳瞬间的一次性刀光弧线，朝向跳跃方向。
func _spawn_jump_slash() -> void:
	var slash := JUMP_SLASH_SCENE.instantiate() as Node2D
	slash.rotation = _jump_direction.angle()
	add_child(slash)


## 按实际移动方向选择四向动画；停止移动时回到 idle。
func _direction_anim_name(dir: Vector2) -> StringName:
	if absf(dir.x) >= absf(dir.y):
		return &"right" if dir.x > 0.0 else &"left"
	return &"down" if dir.y > 0.0 else &"up"


## 移动时不换走路帧，只让角色左右摇晃并轻微起伏；停下时平滑收回。
func _update_animation(delta: float) -> void:
	var moving := not is_jumping and velocity.length() > 20.0
	if not moving:
		if _sprite.animation != &"idle":
			_sprite.play(&"idle")
		_wobble_phase = 0.0
		var back := minf(1.0, delta * 14.0)
		_sprite.rotation = lerpf(_sprite.rotation, 0.0, back)
		_sprite.position = _sprite.position.lerp(_sprite_home, back)
		return

	_sprite.play(_direction_anim_name(velocity))
	_wobble_phase += delta * walk_wobble_speed
	var swing := sin(_wobble_phase)
	_sprite.rotation = deg_to_rad(walk_wobble_degrees) * swing
	_sprite.position = _sprite_home + Vector2(0.0, -absf(swing) * walk_bob_height)


## 循环边界重置时让角色姿态立刻回正。
func _reset_visual() -> void:
	_wobble_phase = 0.0
	if _sprite != null:
		_sprite.rotation = 0.0
		_sprite.position = _sprite_home

