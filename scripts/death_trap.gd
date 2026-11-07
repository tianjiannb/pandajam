extends Area2D
class_name DeathTrap

## 死亡触发装置：玩家或副本接触后立即死亡（与机关枪命中完全一致）。
## 广播自身编号与激活状态；激活状态默认 0，触发后变 1，循环重置时清零。
## 每轮只广播一次信号（active 由 0 变 1 时触发一次），但每轮都可以重新杀死
## 任意数量的个体——副本的录制内容本身就包含"走向本装置"，每一轮重置后
## 副本会重新回放并重新经过这里，必须能再次触发，这样信号控制器才能在
## 副本数量增多后，于同一轮内让多个编号一起点亮打开特殊门。
## 注意：active 的清零必须延迟到新一轮的第一帧（由玩家统一调用 restore()），
## 不能在触发死亡的同一调用栈内立即清零，否则信号会在控制器评估前被撤销。

## signal_id: 本装置编号（供死亡信号控制器匹配）。
## active: 0 = 本轮未触发，1 = 本轮已触发（用于向控制器广播一次性边沿信号）。
signal state_changed(signal_id: int, active: int)

@export var signal_id := 1
@export var idle_color := Color(0.85, 0.2, 0.2, 1)
@export var active_color := Color(1.0, 0.75, 0.1, 1)

## active: 广播给信号控制器的状态，本轮内只会由 0 变为 1 一次（边沿触发）。
var active := 0

@onready var _visual: Polygon2D = $Body


func _ready() -> void:
	add_to_group("death_traps")
	if _visual != null:
		_visual.color = idle_color
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("ghosts")):
		return
	if not body.has_method("on_bullet_hit"):
		return
	# 信号只在本轮内 0->1 的边沿广播一次；但杀人效果对每个进入的个体都生效，
	# 哪怕本轮已经广播过(active==1)，后来者依然会死（与机关枪命中一致）。
	if active == 0:
		active = 1
		if _visual != null:
			_visual.color = active_color
		state_changed.emit(signal_id, active)
	body.on_bullet_hit()


## 新一轮起始帧统一调用：恢复为未触发状态，允许本轮再次广播信号与杀人。
func restore() -> void:
	if active == 0:
		return
	active = 0
	if _visual != null:
		_visual.color = idle_color
	state_changed.emit(signal_id, active)
