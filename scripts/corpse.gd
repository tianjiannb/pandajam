extends Node2D
class_name Corpse

## 尸体：纯视觉残留，不参与碰撞、机关、激光或子弹判定。
## 玩家与副本死亡时都会生成；每次重置统一清理。
## 通过 corpses 组区分玩家尸体与副本尸体，方便统一清理与调试。

@export var is_ghost_corpse := false
@export var player_color := Color(0.3, 0.35, 0.45, 0.75)
@export var ghost_color := Color(0.55, 0.25, 0.55, 0.65)

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	add_to_group("corpses")
	add_to_group("ghost_corpses" if is_ghost_corpse else "player_corpses")
	_body.color = ghost_color if is_ghost_corpse else player_color
