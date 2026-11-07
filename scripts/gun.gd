extends Area2D
class_name GunPickup

## 枪：玩家或过去的你拾取后获得射击能力；每轮恢复，可再次拾取。
## 拾取成功时广播（纯新增信号，不影响 pickup_gun() 判定）。
signal picked_up

@export var idle_color := Color(0.35, 0.8, 0.95, 1.0)
var is_available := true
@onready var _visual: Polygon2D = $Body

func _ready() -> void:
	add_to_group("guns")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not is_available or not body.has_method("pickup_gun"):
		return
	if global_position.distance_to(body.global_position) > 40.0:
		return
	if body.pickup_gun():
		is_available = false
		visible = false
		set_deferred("monitoring", false)
		picked_up.emit()
		SfxManager.play("pickup")

func reset_pickup() -> void:
	is_available = true
	visible = true
	monitoring = false
	set_deferred("monitoring", true)
