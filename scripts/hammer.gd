extends Area2D
class_name HammerPickup

## 锤子：玩家或副本碰到后获得能力，锤子本身消失。
## 同一个锤子每轮只能被拾取一次；下一轮统一归位并恢复可拾取状态。

## 拾取成功时广播（纯新增信号，不影响 pickup_hammer() 判定）。
signal picked_up

@export var idle_color := Color(0.85, 0.65, 0.2, 1)

var is_available := true

@onready var _visual: Polygon2D = $Body


func _ready() -> void:
	add_to_group("hammers")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not is_available or not body.has_method("pickup_hammer"):
		return
	# 忽略 Area2D 重新开启监测时可能滞留的上一帧进入事件。
	if global_position.distance_to(body.global_position) > 40.0:
		return
	# 同一个物理帧内可能同时进入多个个体，只有第一个能成功取得能力。
	if is_available and body.pickup_hammer():
		is_available = false
		visible = false
		set_deferred("monitoring", false)
		picked_up.emit()
		SfxManager.play("pickup")


## 新循环开始：锤子回到原位，可再次被任意一个个体拾取。
func reset_pickup() -> void:
	is_available = true
	visible = true
	# 先同步恢复可拾取状态，再延迟开启 Area2D 监测，避免物理回调冲突。
	monitoring = false
	set_deferred("monitoring", true)
