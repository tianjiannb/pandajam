extends StaticBody2D
class_name BreakableObject

## 可破坏物体：加入 breakable 组；持有锤子能力的玩家或副本按 E 后可破坏。
## 破坏后隐藏并禁用碰撞，每次循环开始时恢复原状。

signal destroyed
signal restored

@export var idle_color := Color(0.65, 0.45, 0.3, 1)

var is_destroyed := false

@onready var _visual: Polygon2D = $Body
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("breakable")
	_visual.color = idle_color


func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	visible = false
	_collision.set_deferred("disabled", true)
	destroyed.emit()


## 循环重置：恢复原状。
func restore() -> void:
	if not is_destroyed:
		return
	is_destroyed = false
	visible = true
	_collision.set_deferred("disabled", false)
	restored.emit()
