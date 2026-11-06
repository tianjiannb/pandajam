extends StaticBody2D
class_name JumpObstacle

## 跳跃障碍（白模）：平时有碰撞、阻挡玩家；
## 接收到玩家跳跃状态（jump_state_changed(true)）时禁用碰撞让玩家通过，
## 玩家落地后恢复碰撞。视觉上半透明提示"可通过"。

@export var idle_color := Color(0.95, 0.65, 0.2, 1)
@export var passable_color := Color(0.95, 0.65, 0.2, 0.25)

@onready var _visual: Polygon2D = $Body
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_visual.color = idle_color
	call_deferred("_connect_players")


func _connect_players() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		player.jump_state_changed.connect(_on_player_jump_state)


func _on_player_jump_state(is_jumping: bool) -> void:
	_collision.set_deferred("disabled", is_jumping)
	_visual.color = passable_color if is_jumping else idle_color
