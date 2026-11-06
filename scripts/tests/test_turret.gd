extends SceneTree

## 机关枪测试：
##  1. 激光被墙体挡住时不开火
##  2. 玩家站在激光内 -> 开火，并进入冷却
##  3. 冷却期间不会连续开火；子弹命中玩家 -> 玩家归位且本轮录制变成副本
##  4. 冷却结束后重新检测，副本同样会被锁定并被打掉（子弹只击杀一个个体）
##
## 运行：Godot...console.exe --headless --path D:\pandajam\test2 --script res://scripts/tests/test_turret.gd

var _failed := 0
var _fires: Array = []


func _initialize() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failed += 1


func _on_fired(direction: Vector2) -> void:
	_fires.append(direction)


func _ghosts(scene: Node) -> Array:
	var out: Array = []
	for child in scene.get_children():
		if child.is_in_group("bullet_target") and not child.is_in_group("player"):
			out.append(child)
	return out


func _run() -> void:
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in range(3):
		await physics_frame

	var player: CharacterBody2D = scene.get_node("Player")
	var turret: StaticBody2D = scene.get_node("Turret")
	var obstacle: StaticBody2D = scene.get_node("Obstacle1")
	turret.fired.connect(_on_fired)

	_check(turret.is_in_group("turrets"), "turret is in turrets group")
	_check(absf(turret.fire_cooldown - 1.0) < 0.001, "default cooldown is 1s (adjustable)")
	_check(turret.laser_length > 0.0, "laser length is configurable")

	# 统一摆位：枪在 (0,-400) 朝下，玩家站在 (0,-250) 的激光内。
	turret.global_position = Vector2(0, -400)
	turret.rotation = PI / 2.0
	turret.laser_length = 240.0
	player.global_position = Vector2(0, -250)
	player.velocity = Vector2.ZERO

	# 1) 墙体挡激光：障碍放到枪口与玩家之间，不应开火。
	obstacle.global_position = Vector2(0, -330)
	for i in range(20):
		await physics_frame
	_check(_fires.size() == 0, "wall between turret and player blocks the laser")

	# 2) 移开障碍 -> 检测到玩家并开火
	obstacle.global_position = Vector2(0, 600)
	for i in range(6):
		await physics_frame
	_check(_fires.size() == 1, "turret fires when player is inside the laser (got %d)" % _fires.size())
	_check(turret.is_cooling(), "turret enters cooldown right after firing")

	# 3) 冷却期内不再开火；子弹命中玩家 -> 玩家归位 + 本轮录制变成副本
	for i in range(20):
		await physics_frame
	_check(_fires.size() == 1, "no second shot during cooldown")
	_check(player.global_position.distance_to(Vector2.ZERO) < 1.0,
		"player is reset to spawn after being shot (at %s)" % player.global_position)
	_check(_ghosts(scene).size() == 1, "killed run is kept as a ghost (got %d)" % _ghosts(scene).size())
	_check(get_nodes_in_group("corpses").is_empty(), "player corpse is cleared when the new cycle starts")

	# 4) 冷却结束后重新检测：副本还站在激光里 -> 再开火 -> 副本被打掉
	for i in range(40):
		await physics_frame
	_check(_fires.size() == 2, "turret fires again at the ghost after cooldown (got %d)" % _fires.size())
	for i in range(20):
		await physics_frame
	_check(_ghosts(scene).size() == 0, "bullet kills the ghost (only one target per shot)")
	_check(get_nodes_in_group("corpses").size() == 1, "ghost death leaves a corpse until the next reset")
	_check(get_nodes_in_group("player_corpses").is_empty(), "player corpse stays cleared in the new cycle")
	_check(get_nodes_in_group("ghost_corpses").size() == 1, "ghost corpse has a distinct visual group")

	# 下一次倒计时重置时清理尸体。
	player.get_node("CountdownTimer").start(0.05)
	for i in range(8):
		await physics_frame
	_check(get_nodes_in_group("corpses").is_empty(), "corpse disappears on the next round reset")

	if _failed == 0:
		print("RESULT: OK")
	else:
		print("RESULT: FAILED (", _failed, " failure(s))")
	quit()
