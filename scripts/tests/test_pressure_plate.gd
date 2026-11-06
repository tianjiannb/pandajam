extends SceneTree

## 压力板无头测试：
##  1. 玩家站上去 -> 收到 state_changed(1, true)，颜色变为激活色
##  2. 持续站上不重复发信号
##  3. 玩家离开 -> 收到 state_changed(1, false)，颜色恢复
##
## 运行：Godot...console.exe --headless --path <project> --script res://scripts/tests/test_pressure_plate.gd

var _failed := 0
var _events: Array = []


func _initialize() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failed += 1


func _on_plate_state(plate_id: int, active: bool) -> void:
	_events.append([plate_id, active])


func _run() -> void:
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame

	var player: CharacterBody2D = scene.get_node("Player")
	var plate: Area2D = scene.get_node("PressurePlate")
	plate.state_changed.connect(_on_plate_state)

	_check(not plate.is_active, "plate starts inactive")
	_check(_events.is_empty(), "no signal before contact")

	# 站上压力板
	player.global_position = plate.global_position
	for i in range(4):
		await physics_frame

	_check(plate.is_active, "plate active while player stands on it")
	_check(_events == [[1, true]], "signal emitted once with plate_id=1, active=true (got %s)" % [_events])
	var visual: Polygon2D = plate.get_node("Body")
	_check(visual.color == plate.active_color, "plate color changed to active color")

	# 持续站上，不应重复发信号
	for i in range(10):
		await physics_frame
	_check(_events.size() == 1, "no duplicate signal while staying on plate")

	# 离开压力板
	player.global_position = Vector2(-400, -300)
	for i in range(4):
		await physics_frame

	_check(not plate.is_active, "plate inactive after player leaves")
	_check(_events == [[1, true], [1, false]], "deactivate signal emitted with plate_id=1 (got %s)" % [_events])
	_check(visual.color == plate.idle_color, "plate color restored to idle color")

	if _failed == 0:
		print("RESULT: OK")
	else:
		print("RESULT: FAILED (", _failed, " failure(s))")
	quit()
