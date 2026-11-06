extends SceneTree

## 跳跃功能无头测试：
##  1. 空格触发跳跃：信号 true、位移约 jump_distance、结束后信号 false
##  2. jump_enabled=false 时跳跃无效
##  3. 跳跃障碍：普通状态阻挡玩家；跳跃时禁用碰撞可穿过、落地恢复
##
## 运行：Godot...console.exe --headless --path <project> --script res://scripts/tests/test_jump.gd

var _failed := 0
var _jump_events: Array = []


func _initialize() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failed += 1


func _on_jump_state(is_jumping: bool) -> void:
	_jump_events.append(is_jumping)


func _run() -> void:
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	await physics_frame

	var player: CharacterBody2D = scene.get_node("Player")
	player.countdown_timer.stop()  # 避免 12 秒重置干扰测试
	player.jump_state_changed.connect(_on_jump_state)

	# 1) 跳跃位移与信号（默认方向 +X，跳跃 0.25s = 15 tick，距离 96）
	player.global_position = Vector2.ZERO
	await physics_frame
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	_check(player.is_jumping, "jump starts on Space")
	_check(_jump_events == [true], "jump_state_changed(true) emitted")
	for i in range(17):
		await physics_frame
	_check(not player.is_jumping, "jump ends after jump_duration")
	_check(_jump_events == [true, false], "jump_state_changed(false) emitted on landing")
	_check(absf(player.global_position.x - 96.0) < 8.0,
		"jump moved ~jump_distance (x=%.1f)" % player.global_position.x)

	# 2) 开关关闭时无效
	player.jump_enabled = false
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	await physics_frame
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for i in range(17):
		await physics_frame
	_check(not player.is_jumping, "no jump when jump_enabled=false")
	_check(_jump_events.size() == 2, "no extra jump signals when disabled")
	_check(absf(player.global_position.x) < 1.0, "no displacement when jump disabled")
	player.jump_enabled = true

	# 3) 跳跃障碍：独立实例，避免场景其它节点干扰。
	var ob: StaticBody2D = (load("res://scenes/jump_obstacle.tscn") as PackedScene).instantiate()
	scene.add_child(ob)
	ob.global_position = Vector2(400, 0)
	await physics_frame
	await physics_frame

	# 3a) 普通状态被阻挡：玩家从 (340,0) 向右走 40 tick。
	player.global_position = Vector2(340, 0)
	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	for i in range(40):
		await physics_frame
	Input.action_release("move_right")
	_check(player.global_position.x < 385.0,
		"obstacle blocks player normally (x=%.1f)" % player.global_position.x)

	# 3b) 跳跃穿过：玩家回到障碍左侧，向右跳（96 距离跨过 32 宽障碍），继续右移。
	player.global_position = Vector2(340, 0)
	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await physics_frame  # 让 _last_move_dir 更新为 +X
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	_check(ob.get_node("CollisionShape2D").disabled or player.is_jumping,
		"obstacle collision disabled while player jumping")
	for i in range(20):
		await physics_frame
	Input.action_release("move_right")
	_check(player.global_position.x > 420.0,
		"player passed through obstacle during jump (x=%.1f)" % player.global_position.x)
	_check(not ob.get_node("CollisionShape2D").disabled, "obstacle collision restored after landing")

	if _failed == 0:
		print("RESULT: OK")
	else:
		print("RESULT: FAILED (", _failed, " failure(s))")
	quit()
