extends StaticBody2D
class_name DoorGate

## 机关门（白模一条线）：关闭时阻挡玩家，开启时放行。
## 自动监听同编号压力板：板激活则开门，板取消则关门。
## 状态变化时广播自身编号与开关状态。

signal state_changed(door_id: int, is_open: bool)

@export var door_id := 1
## 门的总长度（像素）；视觉和碰撞箱同步调整。
@export_range(16.0, 1024.0, 1.0) var door_length := 96.0:
	set(value):
		door_length = maxf(value, 16.0)
		_update_length()
@export var closed_color := Color(0.95, 0.35, 0.3, 1)
@export var open_color := Color(0.3, 0.9, 0.4, 0.4)

var is_open := false

@onready var _line: Line2D = $Line
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_update_length()
	_line.default_color = closed_color
	# 延迟到整棵场景树 ready 后再连接，保证压力板已入组。
	call_deferred("_connect_plates")


func _update_length() -> void:
	if not is_node_ready():
		return
	var half := door_length * 0.5
	_line.points = PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0)])
	var shape := _collision.shape as RectangleShape2D
	if shape != null:
		shape.size = Vector2(door_length, shape.size.y)


func _connect_plates() -> void:
	for plate in get_tree().get_nodes_in_group("pressure_plates"):
		plate.state_changed.connect(_on_plate_state_changed)


func _on_plate_state_changed(plate_id: int, active: bool) -> void:
	if plate_id == door_id:
		set_open(active)


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	_line.default_color = open_color if is_open else closed_color
	# 物理回调中不能直接改碰撞，延迟设置。
	_collision.set_deferred("disabled", is_open)
	state_changed.emit(door_id, is_open)
