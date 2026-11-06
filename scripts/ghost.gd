extends CharacterBody2D

## 副本：逐物理帧回放一段录制好的 Transform2D 序列，无限循环。
## 与玩家功能一致：带碰撞体、属于 plate_activator 组，可触发压力板等机关。
## 使用独立碰撞层 2、掩码 0：不与玩家/墙体发生推挤或阻挡（纯位置回放），
## 但压力板等 Area2D（掩码含层 2）能正常检测到它。
## 视作"过去的自己"：与玩家共用子弹命中判定（bullet_target 组），被子弹打中即留下尸体并消失。

## 被子弹击杀时广播。
signal destroyed

var _frames: Array[Transform2D] = []
var _playhead := 0


func _ready() -> void:
	add_to_group("plate_activator")
	add_to_group("bullet_target")


## 与玩家完全一致：被子弹击杀后在原地留下尸体；尸体在下一次重置时统一清理。
func on_bullet_hit() -> void:
	var corpse: Node2D = (load("res://scenes/corpse.tscn") as PackedScene).instantiate()
	corpse.is_ghost_corpse = true
	get_parent().add_child(corpse)
	corpse.global_transform = global_transform
	destroyed.emit()
	queue_free()


func start_replay(frames: Array[Transform2D]) -> void:
	_frames = frames
	_playhead = 0
	if _frames.is_empty():
		return
	global_transform = _frames[0]


func _physics_process(_delta: float) -> void:
	if _frames.is_empty():
		return
	global_transform = _frames[_playhead]
	_playhead = (_playhead + 1) % _frames.size()
