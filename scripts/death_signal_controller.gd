extends Node
class_name DeathSignalController

## 死亡信号控制器：统计 total_signals 个死亡触发装置的激活状态。
## 维护一个 1..n 的进度列表，全部为 1 时打开对应的特殊门；
## 循环重置时清零进度并关闭门，要求重新点亮全部编号。

## total_signals: 需要追踪的死亡装置编号数量（对应编号 1..total_signals）。
@export var total_signals := 1
## door_path: 指向特殊门节点（DoorGate）；留空则只广播 all_signals_active 信号。
@export var door_path: NodePath

## active: 1 = 全部编号已点亮（门已开），0 = 未集齐（门关闭）。
signal all_signals_active(active: int)

var _progress: Array[int] = []
var _door: Node


func _ready() -> void:
	add_to_group("death_signal_controllers")
	_progress.resize(total_signals)
	_progress.fill(0)
	if not door_path.is_empty():
		_door = get_node_or_null(door_path)
	call_deferred("_connect_traps")


func _connect_traps() -> void:
	for trap in get_tree().get_nodes_in_group("death_traps"):
		if not trap.state_changed.is_connected(_on_trap_state_changed):
			trap.state_changed.connect(_on_trap_state_changed)


func _on_trap_state_changed(signal_id: int, active: int) -> void:
	var index := signal_id - 1
	if index < 0 or index >= _progress.size():
		return
	_progress[index] = active
	_evaluate()


func _evaluate() -> void:
	var all_active := _progress.size() > 0 and _progress.all(func(v: int) -> bool: return v == 1)
	all_signals_active.emit(1 if all_active else 0)
	if _door != null and _door.has_method("set_open"):
		_door.set_open(all_active)


## 循环重置：清空进度列表，关闭对应门，等待重新点亮全部编号。
func restore() -> void:
	_progress.fill(0)
	all_signals_active.emit(0)
	if _door != null and _door.has_method("set_open"):
		_door.set_open(false)
