extends SceneTree
## 无头测试：godot --headless --path <项目目录> --script res://Scripts/tests/test_core_loop.gd

var _failed := 0
var _main: Node


func _initialize() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failed += 1


func _new_main() -> void:
	if _main:
		_main.queue_free()
		await process_frame
	_main = (load("res://Scenes/Main.tscn") as PackedScene).instantiate()
	_main.auto_input = false
	root.add_child(_main)
	await physics_frame
	await physics_frame


func _step(dir: Vector2) -> void:
	await physics_frame
	_main.step(dir)


func _walk_to(target: Vector2, max_ticks: int = 600) -> void:
	for i in max_ticks:
		var to_target: Vector2 = target - _main.player.position
		if to_target.length() < 3.0:
			return
		await _step(to_target.normalized())


func _stand(ticks: int) -> void:
	for i in ticks:
		await _step(Vector2.ZERO)


func _run() -> void:
	# 1. 没有按钮时，门挡住出口
	await _new_main()
	await _walk_to(Vector2(700, 360))
	for i in 120:
		await _step(Vector2.RIGHT)
	_check(_main.player.position.x < 790.0, "门关着时玩家过不去")
	_check(_main.state == _main.State.RECORDING, "第 1 轮不会因为走到门前而结束")

	# 2. 站在按钮上门打开，离开后门关闭
	await _new_main()
	await _walk_to(_main.BUTTON_POS)
	await _stand(5)
	_check(_main.door_open, "站在按钮上门打开")
	await _walk_to(_main.BUTTON_POS + Vector2(60, 0))
	await _stand(2)
	_check(not _main.door_open, "离开按钮门关闭")

	# 3. 完整循环：录像 -> 影子替踩 -> 通关
	await _new_main()
	await _walk_to(_main.BUTTON_POS)
	await _stand(600)
	_main.finish_recording()
	_check(_main.state == _main.State.REPLAY and _main.round_no == 2, "进入第 2 轮回放")
	await _walk_to(Vector2(700, 360))
	_check(_main.door_open, "影子停在按钮上，门保持打开")
	await _walk_to(Vector2(1060, 360))
	_check(_main.state == _main.State.CLEARED, "穿过门到达出口，通关")

	# 4. 碰到影子 -> 重来本轮
	await _new_main()
	await _walk_to(_main.BUTTON_POS)
	await _stand(600)
	_main.finish_recording()
	# 玩家沿同一路线走，会追上影子；第一次失败发生时立即停下检查
	for i in 900:
		if _main.fail_count > 0:
			break
		var to_button: Vector2 = _main.BUTTON_POS - _main.player.position
		await _step(to_button.normalized())
	_check(_main.fail_count == 1 and _main.round_no == 2, "碰到影子计一次失败并留在第 2 轮")
	_check(_main.tick < 5 and _main.player.position.distance_to(_main.START) < 5.0, "失败后玩家回到出生点，影子重放")

	print("RESULT: %s" % ("OK" if _failed == 0 else "%d FAILED" % _failed))
	quit(0 if _failed == 0 else 1)
