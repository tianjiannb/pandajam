extends CharacterBody2D

## 副本：逐物理帧回放一段录制好的 Transform2D 序列，无限循环。
## 与玩家功能一致：带碰撞体、属于 plate_activator 组，可触发压力板等机关。
## 使用独立碰撞层 2、掩码 0：不与玩家/墙体发生推挤或阻挡（纯位置回放），
## 但压力板等 Area2D（掩码含层 2）能正常检测到它。
## 视作"过去的自己"：与玩家共用子弹命中判定（bullet_target 组），被子弹打中即留下尸体并消失。

## 被击杀时广播（子弹/死亡装置等）。副本不会因此消失：游戏核心规则是
## 保留所有历史副本，死亡只是让它在原地留下尸体标记，直到下一次循环重置
## 时回到录制起点、恢复正常回放。
signal destroyed
signal hammer_state_changed(has_hammer: bool)

var has_hammer := false
@export var hammer_use_range := 72.0

var _frames: Array[Transform2D] = []
var _actions: Array[bool] = []
var _playhead := 0
var _cycle_duration := 12.0

## 本轮是否已死亡：死亡后停留在原地（不再前进播放头），直到 restart_cycle()。
var _dead := false

@onready var countdown_timer: Timer = $CountdownTimer
@onready var countdown_label: Label = $CountdownLabel


func _ready() -> void:
	add_to_group("ghosts")
	add_to_group("plate_activator")
	add_to_group("bullet_target")
	countdown_timer.timeout.connect(restart_cycle)
	# 手动调用 start_replay 时可能在 add_child 之前设置位置；入树后恢复首帧，
	# 防止 Node2D 的通知流程把全局位置重置为默认值。
	if not _frames.is_empty():
		global_transform = _frames[0]
		countdown_timer.wait_time = _cycle_duration
		countdown_timer.start()
	_update_countdown_label()


func _process(_delta: float) -> void:
	_update_countdown_label()


func _update_countdown_label() -> void:
	countdown_label.text = str(int(ceil(countdown_timer.time_left)))


## 被击杀（子弹/死亡装置等）：在原地留下尸体标记，但副本本身不会消失。
## 游戏核心规则是保留所有历史副本：死亡只是让它停在原地直到下一轮重置，
## 重置后回到录制起点，恢复正常回放（与之前完全一样）。
func on_bullet_hit() -> void:
	if _dead:
		return
	_dead = true
	var corpse: Node2D = (load("res://scenes/corpse.tscn") as PackedScene).instantiate()
	corpse.is_ghost_corpse = true
	get_parent().add_child(corpse)
	corpse.global_transform = global_transform
	visible = false
	destroyed.emit()


func start_replay(frames: Array[Transform2D], actions: Array[bool] = [], cycle_duration: float = 12.0) -> void:
	_frames = frames
	_actions = actions
	_cycle_duration = cycle_duration
	_playhead = 0
	_dead = false
	visible = true
	reset_hammer()
	if _frames.is_empty():
		return
	global_transform = _frames[0]
	if is_node_ready():
		countdown_timer.wait_time = _cycle_duration
		countdown_timer.start()


## 全局循环边界：回到本轮录制的起点，清除临时能力并重启自己的倒计时。
## 由玩家重置流程统一调用；自己的 Timer 超时也走同一入口。
## 即使本轮已死亡也会在这里复活：核心规则是副本永不真正消失。
func restart_cycle() -> void:
	_playhead = 0
	_dead = false
	visible = true
	reset_hammer()
	if not _frames.is_empty():
		global_transform = _frames[0]
	if is_node_ready():
		countdown_timer.stop()
		countdown_timer.start()
		_update_countdown_label()


func pickup_hammer() -> bool:
	if has_hammer:
		return false
	has_hammer = true
	hammer_state_changed.emit(true)
	return true


func reset_hammer() -> void:
	if has_hammer:
		has_hammer = false
		hammer_state_changed.emit(false)


func use_hammer() -> void:
	if not has_hammer:
		return
	for object in get_tree().get_nodes_in_group("breakable"):
		if object is Node2D and global_position.distance_to(object.global_position) <= hammer_use_range:
			object.destroy()


func _physics_process(_delta: float) -> void:
	if _frames.is_empty() or _dead:
		return
	global_transform = _frames[_playhead]
	if _playhead < _actions.size() and _actions[_playhead]:
		use_hammer()
	# 循环边界由倒计时统一控制；尾帧之后停留在原地，等待同步释放。
	_playhead = mini(_playhead + 1, _frames.size() - 1)
