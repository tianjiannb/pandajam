extends Area2D
class_name PressurePlate

## 压力板（白模）：玩家或副本站上去变色，并广播编号与激活状态。
## 响应 "plate_activator" 组内的物理体（玩家层 1、副本层 2，掩码 3 均覆盖）。

signal state_changed(plate_id: int, active: bool)

@export var plate_id := 1
@export var idle_color := Color(0.8, 0.8, 0.8, 1)
@export var active_color := Color(0.3, 0.9, 0.4, 1)

var is_active := false
var _bodies: Array[Node2D] = []

@onready var _visual: Polygon2D = $Body
@onready var _active_visual: Polygon2D = $ActiveBody


func _ready() -> void:
	add_to_group("pressure_plates")
	_visual.color = idle_color
	_active_visual.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("plate_activator") or _bodies.has(body):
		return
	_bodies.append(body)
	_refresh()


func _on_body_exited(body: Node2D) -> void:
	_bodies.erase(body)
	_refresh()


func _refresh() -> void:
	var now_active := _bodies.size() > 0
	if now_active == is_active:
		return
	is_active = now_active
	_visual.color = active_color if is_active else idle_color
	_active_visual.visible = is_active
	_visual.visible = not is_active
	state_changed.emit(plate_id, is_active)
	if is_active:
		SfxManager.play("switch")
