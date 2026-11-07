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

var has_gun := false
@export var gun_fire_cooldown := 0.35
@export var gun_bullet_speed := 900.0
@export var gun_bullet_max_distance := 900.0
var _gun_cooldown_left := 0.0
var _gun_shot_count := 0
const GUN_BULLET_SCENE := preload("res://scenes/gun_bullet.tscn")

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
var _pending_death_reset := false
var _devouring := false  # 被死亡装置吞噬中：冻结移动与走路摇晃，交给吞噬动画驱动
var _tick_played := false
var _gun_direction := Vector2.RIGHT
var _sprite_home_scale := Vector2.ONE


func _ready() -> void:
	add_to_group("plate_activator")
	add_to_group("player")
	# 机关枪可命中玩家；副本同样加入该组，命中判定与玩家一致。
	add_to_group("bullet_target")
	_start_transform = global_transform
	_sprite_home = _sprite.position
	_sprite_home_scale = _sprite.scale
	_sprite.play(&"idle")
	_update_countdown_label()
	countdown_timer.timeout.connect(_on_countdown_timeout)
	# 显式启动，避免场景重新保存后 autostart 标记丢失导致副本机制停止。
	countdown_timer.start()


func _process(_delta: float) -> void:
	_update_countdown_label()
	# 倒计时剩余 3 秒时只播放一次提示音；每轮重置时复位标记。
	if not _tick_played and not countdown_timer.is_stopped() and countdown_timer.time_left <= 3.0:
		_tick_played = true
		SfxManager.play("tick")


func _update_countdown_label() -> void:
	countdown_label.text = str(int(ceil(countdown_timer.time_left)))


func _on_countdown_timeout() -> void:
	_reset_round_and_spawn_ghost()


## 玩家死亡：立即清空倒计时，统一由 timeout 执行重置。
## 新循环中不保留玩家尸体；副本死亡留下的尸体也随本次重置统一清理。
func on_bullet_hit() -> void:
	if _pending_death_reset:
		return
	_pending_death_reset = true
	countdown_timer.stop()
	_spawn_corpse(global_transform)
	visible = false
	velocity = Vector2.ZERO
	killed.emit()
	SfxManager.play("death")
	var death_animation_time := 0.75
	var timer := get_tree().create_timer(death_animation_time, true, false, true)
	timer.timeout.connect(_finish_player_death)


## 被血肉能量垃圾桶吞噬：不播放默认死亡、不留尸体，而是被吸向桶口、旋转缩小消失。
## 仍走正常重置流程——本轮结束会生成「过去的你」，开门信号机制不受影响。
func on_devoured(trap: Node2D) -> void:
	if _pending_death_reset:
		return
	_pending_death_reset = true
	_devouring = true
	countdown_timer.stop()
	killed.emit()
	SfxManager.play("death")
	visible = true
	# 吞噬动画期间禁用碰撞，防止 tween 路径误触发终点/其他机关。
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var mouth: Vector2 = trap.global_position + Vector2(0, -26.0)
	var t := create_tween()
	t.set_parallel(true)
	# 被吸向桶口（加速），旋转卷入血肉漩涡，同时缩小、染血。
	t.tween_property(self, "global_position", mouth, 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_sprite, "rotation", TAU * 1.5, 0.8)
	t.tween_property(_sprite, "scale", Vector2.ONE * 0.04, 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_sprite, "modulate", Color(1.0, 0.45, 0.5, 1.0), 0.6)
	# 全部吞入后：隐藏本体，走正常死亡重置（生成副本、开启新一轮）。
	t.chain().tween_callback(_on_devour_animation_done)


func _on_devour_animation_done() -> void:
	visible = false
	_finish_player_death()


func _finish_player_death() -> void:
	if not _pending_death_reset:
		return
	_pending_death_reset = false
	visible = true
	_on_countdown_timeout()



## Q：提前结束当前循环，不视为死亡，不播放死亡动画。
## 保留本轮录制，并立即生成“过去的你”进入下一轮。
func end_round_early() -> void:
	if _pending_death_reset:
		return
	countdown_timer.stop()
	_on_countdown_timeout()


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
## 死亡触发装置与信号控制器的重置延迟到下一帧，让本轮的信号累积有机会完整评估。
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
	# 恢复碰撞（吞噬动画期间被禁用）。
	collision_layer = 1
	collision_mask = 4
	_reset_visual()
	if is_jumping:
		is_jumping = false
		jump_state_changed.emit(false)
	_recording.clear()
	_recorded_actions.clear()
	countdown_timer.start()
	# 死亡触发装置与信号控制器延迟到下一帧重置，让本轮内所有 ghost 的触发信号
	# 先传递给控制器完成评估（例如 ghost1 触发 trap1 + player 触发 trap2 = 开门），
	# 然后才在新循环的起始帧清空进度、关门，准备下一轮的重新点亮。
	call_deferred("_reset_traps_and_controllers")
	_tick_played = false
	SfxManager.play("rewind")


## 延迟到下一帧执行：清空死亡触发装置与信号控制器的本轮状态。
## 必须晚于 _reset_round_and_spawn_ghost() 本身一帧，否则会在同一次死亡
## 触发的调用栈内把刚刚点亮的信号立刻撤销，导致控制器永远看不到多个
## 编号同时点亮。
func _reset_traps_and_controllers() -> void:
	for trap in get_tree().get_nodes_in_group("death_traps"):
		trap.restore()
	for controller in get_tree().get_nodes_in_group("death_signal_controllers"):
		controller.restore()


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


func pickup_gun() -> bool:
	if has_gun:
		return false
	has_gun = true
	return true


func reset_gun() -> void:
	pass


func fire_gun() -> void:
	if not has_gun or _gun_cooldown_left > 0.0:
		return
	_gun_cooldown_left = gun_fire_cooldown
	_gun_shot_count += 1
	var bullet := GUN_BULLET_SCENE.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position + _gun_direction * 18.0
	bullet.setup(_gun_direction, gun_bullet_speed, gun_bullet_max_distance, get_rid(), _gun_shot_count)


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q or event.keycode == KEY_Q:
			end_round_early()


func _physics_process(delta: float) -> void:
	if _devouring:
		return  # 吞噬动画期间冻结移动 / 录制 / 摇晃，避免覆盖动画
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.0:
		_last_move_dir = input_dir.normalized()
		_gun_direction = _last_move_dir
	_gun_cooldown_left = maxf(_gun_cooldown_left - delta, 0.0)

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
	if Input.is_action_just_pressed("fire_gun"):
		fire_gun()

	_recording.append(global_transform)
	_recorded_actions.append(Input.is_action_just_pressed("use_hammer"))


func _start_jump() -> void:
	is_jumping = true
	_jump_direction = _last_move_dir
	_jump_time_left = jump_duration
	jump_state_changed.emit(true)
	_spawn_jump_slash()


## 起跳瞬间的一次性位移白线，朝向跳跃方向，长度对齐本次跳跃实际位移距离。
func _spawn_jump_slash() -> void:
	var slash := JUMP_SLASH_SCENE.instantiate()
	slash.rotation = _jump_direction.angle()
	slash.fit_to_distance(jump_distance)
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


## 循环边界重置时让角色姿态立刻回正（含吞噬动画带来的缩放/染色/旋转）。
func _reset_visual() -> void:
	_wobble_phase = 0.0
	_devouring = false
	if _sprite != null:
		_sprite.rotation = 0.0
		_sprite.position = _sprite_home
		_sprite.scale = _sprite_home_scale
		_sprite.modulate = Color.WHITE
