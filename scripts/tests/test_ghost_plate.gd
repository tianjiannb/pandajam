extends SceneTree

## 副本触发机关测试：
##  1. 副本站压力板 -> 板激活并发 state_changed(1, true)、变色
##  2. 同编号门随之打开
##  3. 副本离开 -> 板取消激活、门关闭
##  4. 副本与玩家不互相推挤（纯位置回放）
##
## 运行：Godot...console.exe --headless --path <project> --script res://scripts/tests/test_ghost_plate.gd

var _failed := 0
var _plate_events: Array = []


func _initialize() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failed += 1


func _on_plate_state(plate_id: int, active: bool) -> void:
	_plate_events.append([plate_id, active])


func _run() -> void:
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	await physics_frame

	var plate: Area2D = scene.get_node("PressurePlate")
	var door: StaticBody2D = scene.get_node("Door")
	plate.state_changed.connect(_on_plate_state)

	# 手工生成一个副本，回放内容为"一直站在压力板上"。
	var ghost: CharacterBody2D = (load("res://scenes/ghost.tscn") as PackedScene).instantiate()
	scene.add_child(ghost)
	var frames: Array[Transform2D] = []
	for i in range(30):
		frames.append(Transform2D(0.0, plate.global_position))
	ghost.start_replay(frames)

	for i in range(6):
		await physics_frame

	_check(ghost.is_in_group("plate_activator"), "ghost is in plate_activator group")
	_check(plate.is_active, "plate activated by ghost standing on it")
	_check(_plate_events == [[1, true]], "plate emitted (1, true) for ghost (got %s)" % [_plate_events])
	_check(door.is_open, "door opened by ghost-triggered plate")

	# 副本移走：重放一段远处录制。
	var away: Array[Transform2D] = []
	for i in range(30):
		away.append(Transform2D(0.0, Vector2(-500, -400)))
	ghost.start_replay(away)
	for i in range(6):
		await physics_frame

	_check(not plate.is_active, "plate deactivated after ghost left")
	_check(_plate_events == [[1, true], [1, false]], "plate emitted (1, false) (got %s)" % [_plate_events])
	_check(not door.is_open, "door closed after ghost left plate")

	# 副本与玩家不推挤：把副本放到玩家位置，玩家应原地不动。
	var player: CharacterBody2D = scene.get_node("Player")
	var player_pos: Vector2 = player.global_position
	var at_player: Array[Transform2D] = []
	for i in range(30):
		at_player.append(Transform2D(0.0, player_pos))
	ghost.start_replay(at_player)
	for i in range(10):
		await physics_frame
	_check(player.global_position.distance_to(player_pos) < 0.01, "ghost does not push player")

	if _failed == 0:
		print("RESULT: OK")
	else:
		print("RESULT: FAILED (", _failed, " failure(s))")
	quit()
