extends Area2D

## 出口触发区：玩家穿过 SpecialDoor（door_id=99）后走到这里，触发结局过场。
## 挂在 main.tscn 的 door/ExitTrigger，位于特殊门上方（门外侧）。
## 只感应 Player（物理层 1），触发一次后切到 cinematic 场景播放结局。

@export var cinematic_id := "ending"

var _fired := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # 只感应 Player（物理层 1）
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _fired or not body.is_in_group("player"):
		return
	_fired = true
	GameConfig.cinematic_id = cinematic_id
	# 物理回调里不能直接切场景（会 free 碰撞节点），延迟到帧末。
	call_deferred("_go_cinematic")


func _go_cinematic() -> void:
	get_tree().change_scene_to_file("res://scenes/cinematic.tscn")
