extends SceneTree

## 机关门无头测试：
##  1. 初始关闭、碰撞启用
##  2. 玩家站上同编号压力板 -> 门开：state_changed(1, true)、碰撞禁用、线变色
##  3. 关闭时门能挡住玩家（实际位移测试），开启后可穿过
##  4. 离开压力板 -> 门关：state_changed(1, false)
##
## 运行：Godot...console.exe --headless --path <project> --script res://scripts/tests/test_door.gd

var _failed := 0
var _events: Array = []


func _initialize() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failed += 1


func _on_door_state(door_id: int, is_open: bool) -> void:
	_events.append([door_id, is_open])


func _run() -> void:
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	await physics_frame  # 等 door 的 deferred 连接完成

	var player: CharacterBody2D = scene.get_node("Player")
	var plate: Area2D = scene.get_node("PressurePlate")
	var door: StaticBody2D = scene.get_node("Door")
	door.state_changed.connect(_on_door_state)

	_check(not door.is_open, "door starts closed")
	_check(not door.get_node("CollisionShape2D").disabled, "door collision enabled when closed")

	# 1) 关闭时阻挡：玩家放在门上方，向下走 60 tick，应被挡住。
	player.global_position = Vector2(door.global_position.x, door.global_position.y - 60)
	Input.action_press("move_down")
	for i in range(60):
		await physics_frame
	Input.action_release("move_down")
	_check(player.global_position.y < door.global_position.y - 10.0,
		"closed door blocks player (y=%.1f, door_y=%.1f)" % [player.global_position.y, door.global_position.y])

	# 2) 站上压力板 -> 门开
	player.global_position = plate.global_position
	for i in range(4):
		await physics_frame
	_check(door.is_open, "door opens when matching plate activated")
	_check(_events == [[1, true]], "door emitted state_changed(1, true) (got %s)" % [_events])
	_check(door.get_node("CollisionShape2D").disabled, "door collision disabled when open")
	var line: Line2D = door.get_node("Line")
	_check(line.default_color == door.open_color, "door line changed to open color")

	# 3) 实际通行测试：用独立门实例（编号 99，不匹配压力板 1，避免被板状态干扰）。
	var solo_door: StaticBody2D = (load("res://scenes/door.tscn") as PackedScene).instantiate()
	solo_door.door_id = 99
	scene.add_child(solo_door)
	solo_door.global_position = Vector2(400, 280)
	solo_door.set_open(true)
	await physics_frame
	await physics_frame
	player.global_position = Vector2(400, 220)
	Input.action_press("move_down")
	for i in range(60):
		await physics_frame
	Input.action_release("move_down")
	_check(player.global_position.y > 300.0,
		"open door lets player pass (y=%.1f)" % player.global_position.y)
	solo_door.queue_free()

	# 4) 离开压力板后门应已关闭（玩家早已离开板），检查关门信号与状态。
	for i in range(4):
		await physics_frame
	_check(not door.is_open, "door closed after player left plate")
	_check(_events.has([1, false]), "door emitted state_changed(1, false) (got %s)" % [_events])
	_check(not door.get_node("CollisionShape2D").disabled, "door collision re-enabled when closed")
	_check(line.default_color == door.closed_color, "door line restored to closed color")

	if _failed == 0:
		print("RESULT: OK")
	else:
		print("RESULT: FAILED (", _failed, " failure(s))")
	quit()
