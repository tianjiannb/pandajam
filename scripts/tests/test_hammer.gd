extends SceneTree

## 锤子能力 + 副本回放 + 循环重置验证。
## 使用独立最小场景，避免主场景中机关枪、自动副本等互相干扰。

var _failed := 0


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failed += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node2D = Node2D.new()
	root.add_child(scene)
	current_scene = scene

	var player: CharacterBody2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	scene.add_child(player)
	player.global_position = Vector2(660, 500)
	player.get_node("CountdownTimer").stop()
	player._recording.append(Transform2D(0.0, player.global_position))
	player._recorded_actions.append(false)

	var hammer: Area2D = (load("res://scenes/hammer.tscn") as PackedScene).instantiate()
	scene.add_child(hammer)
	hammer.global_position = Vector2(700, 500)

	var breakable: StaticBody2D = (load("res://scenes/breakable.tscn") as PackedScene).instantiate()
	scene.add_child(breakable)
	breakable.global_position = Vector2(740, 500)

	var ghost: CharacterBody2D = (load("res://scenes/ghost.tscn") as PackedScene).instantiate()
	scene.add_child(ghost)
	var away_frames: Array[Transform2D] = []
	for i in range(30):
		away_frames.append(Transform2D(0.0, Vector2(900, 700)))
	ghost.start_replay(away_frames)

	await physics_frame
	await physics_frame

	# 玩家拾取。
	player.global_position = Vector2(700, 500)
	for i in range(4):
		await physics_frame
	_check(player.has_hammer, "player picks up hammer on contact")
	_check(hammer.is_available == false and not hammer.visible, "hammer disappears after pickup")
	var states: Array[bool] = []
	player.hammer_state_changed.connect(func(v: bool): states.append(v))

	# 同轮不能拾取第二次。
	ghost.start_replay(_standing_frames(hammer.global_position, 30))
	for i in range(5):
		await physics_frame
	_check(not ghost.has_hammer, "same hammer cannot be picked up twice in one cycle")

	# E 破坏附近物体。
	Input.action_press("use_hammer")
	await physics_frame
	await physics_frame
	Input.action_release("use_hammer")
	for i in range(3):
		await physics_frame
	_check(breakable.is_destroyed, "E destroys a nearby breakable object")
	_check(not breakable.visible, "destroyed breakable is hidden")

	# 新循环：所有个体远离锤子，避免归位瞬间被再次拾取。
	ghost.start_replay(away_frames)
	player.global_position = Vector2(1000, 900)
	player._recording.clear()
	player._recorded_actions.clear()
	for i in range(30):
		player._recording.append(Transform2D(0.0, Vector2(1000, 900)))
		player._recorded_actions.append(false)
	player.get_node("CountdownTimer").start(0.05)
	for i in range(8):
		await physics_frame
	_check(not player.has_hammer, "player hammer ability resets at new cycle")
	_check(hammer.is_available and hammer.visible, "hammer returns at new cycle")
	_check(not breakable.is_destroyed, "breakable is restored at new cycle")
	_check(breakable.visible, "restored breakable is visible again")
	_check(not breakable.get_node("CollisionShape2D").disabled, "restored breakable collision re-enabled")

	# 玩家保持远处，副本回来拾取。
	player.global_position = Vector2(1000, 900)
	ghost.start_replay(_standing_frames(hammer.global_position, 30))
	for i in range(6):
		await physics_frame
	_check(ghost.has_hammer, "ghost can pick up the reset hammer (pos=%s)" % ghost.global_position)
	_check(states.has(false), "hammer_state_changed(false) emitted at reset")

	# 副本按录制的 E 操作破坏新目标。
	var target: StaticBody2D = (load("res://scenes/breakable.tscn") as PackedScene).instantiate()
	scene.add_child(target)
	target.global_position = Vector2(740, 500)
	var replay_frames: Array[Transform2D] = []
	var actions: Array[bool] = []
	for i in range(30):
		replay_frames.append(Transform2D(0.0, hammer.global_position))
		actions.append(i == 1)
	ghost.start_replay(replay_frames, actions)
	for i in range(5):
		await physics_frame
	_check(target.is_destroyed, "ghost replays recorded E action and destroys breakable")

	ghost.reset_hammer()
	_check(not ghost.has_hammer, "ghost hammer ability can reset at cycle boundary")

	if _failed == 0:
		print("RESULT: OK")
	else:
		print("RESULT: FAILED (", _failed, " failure(s))")
	quit()


func _standing_frames(at: Vector2, count: int) -> Array[Transform2D]:
	var frames: Array[Transform2D] = []
	for i in range(count):
		frames.append(Transform2D(0.0, at))
	return frames
