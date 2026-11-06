extends SceneTree

## 2D 核心循环无头测试：
##  1. 倒计时配置与标签显示（时长从场景里的 Timer 读取，不写死秒数）
##  2. 按住 move_right 角色沿 +X 移动
##  3. 倒计时结束：玩家重置回出生点、生成副本
##  4. 副本循环回放（超过录制长度后回到起点附近）
##  5. 第二轮录制结束后：存在两个副本，旧副本仍在循环自己的录制
##
## 运行：Godot...console.exe --headless --path <project> --script res://scripts/tests/test_core.gd

var _failed := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failed += 1


func _get_ghosts(scene: Node) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child in scene.get_children():
		if child.has_method("start_replay"):
			result.append(child)
	return result


func _run() -> void:
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame

	var player: CharacterBody2D = scene.get_node("Player")
	var timer: Timer = player.get_node("CountdownTimer")
	var label: Label = player.get_node("CountdownLabel")

	# 1) Timer 配置与初始标签（时长以场景配置为准，默认 12s，可在编辑器里改）
	var cycle: float = timer.wait_time
	var cycle_ticks: int = int(round(cycle * 60.0))
	var cycle_label := str(int(ceil(cycle)))
	_check(cycle > 0.0, "timer wait_time configured (%.1fs)" % cycle)
	_check(timer.one_shot and not timer.is_stopped(), "timer one_shot + autostart")
	_check(label.text == cycle_label, "label starts at %s (got '%s')" % [cycle_label, label.text])

	# 2) 移动验证
	var start_pos: Vector2 = player.global_position
	Input.action_press("move_right")
	for i in range(60):
		await physics_frame
	_check(player.global_position.x > start_pos.x + 50.0, "player moved +X (dx=%.1f)" % (player.global_position.x - start_pos.x))
	_check(player.rotation == 0.0, "player does not rotate (2D movement)")
	_check(label.global_position.y < player.global_position.y and absf(label.global_position.x - player.global_position.x) < 15.0,
		"countdown label stays above player, unrotated")

	# 3) 继续按住直到第一轮录制结束（已跑 60 tick，再跑到整轮结束）
	for i in range(cycle_ticks - 62):
		await physics_frame
	Input.action_release("move_right")
	for i in range(4):
		await physics_frame

	var ghosts := _get_ghosts(scene)
	_check(ghosts.size() == 1, "one ghost spawned after first cycle (got %d)" % ghosts.size())
	_check(player.global_position.distance_to(start_pos) < 1.0, "player reset to start (pos=%s)" % player.global_position)
	_check(label.text == cycle_label or label.text == str(int(ceil(cycle)) - 1), "countdown restarted (label='%s')" % label.text)

	if ghosts.is_empty():
		print("RESULT: FAILED (no ghost)")
		quit()
		return
	var ghost1: Node2D = ghosts[0]
	_check(ghost1.global_position.distance_to(start_pos) < 30.0, "ghost1 begins near recorded start")

	# 4) 循环验证：录制长 cycle_ticks。推进一整轮后 ghost1 应绕回起点附近。
	for i in range(cycle_ticks + 2):
		await physics_frame
	_check(ghost1.global_position.distance_to(start_pos) < 40.0,
		"ghost1 looped back near start after >%d ticks (pos=%s)" % [cycle_ticks, ghost1.global_position])

	# 第二轮录制刚刚也在同一时刻超时结束（玩家静置 720 tick），应生成第二个副本。
	ghosts = _get_ghosts(scene)
	_check(ghosts.size() == 2, "two ghosts after second cycle (got %d)" % ghosts.size())
	if ghosts.size() < 2:
		print("RESULT: FAILED")
		quit()
		return
	var ghost2: Node2D = ghosts[1]
	_check(ghost2.global_position.distance_to(start_pos) < 1.0, "ghost2 loops stationary recording at start")

	# 5) 旧副本仍在动：推进 60 tick，ghost1 应移动、ghost2 应静止。
	var g1_before: Vector2 = ghost1.global_position
	var g2_before: Vector2 = ghost2.global_position
	for i in range(60):
		await physics_frame
	_check(ghost1.global_position.distance_to(g1_before) > 30.0, "ghost1 still replaying its own recording")
	_check(ghost2.global_position.distance_to(g2_before) < 1.0, "ghost2 stays put (stationary loop)")

	if _failed == 0:
		print("RESULT: OK")
	else:
		print("RESULT: FAILED (", _failed, " failure(s))")
	quit()
