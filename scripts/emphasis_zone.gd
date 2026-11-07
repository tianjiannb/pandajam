extends Area2D
class_name EmphasisZone

## 第一阶段强调节点：玩家首次进入范围时暂停玩法并让镜头聚焦目标。
## triggered 只存在于本次场景运行期间，循环重置不会清除它。

@export var emphasis_id := "emphasis_zone"
@export var focus_target_path: NodePath
@export var focus_position := Vector2.ZERO
@export var focus_zoom := Vector2(1.6, 1.6)
@export var move_duration := 0.65
@export var hold_duration := 1.5
@export var return_duration := 0.65
@export var trigger_once := true
@export var pause_game := true

var triggered := false
var _camera: Camera2D
var _player: Node2D
var _original_zoom := Vector2.ONE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	body_entered.connect(_on_body_entered)
	monitoring = true


func _on_body_entered(body: Node2D) -> void:
	if trigger_once and triggered:
		return
	if not body.is_in_group("player"):
		return
	if not is_instance_valid(body):
		return
	_player = body
	_camera = body.get_node_or_null("Camera2D") as Camera2D
	if _camera == null:
		return

	triggered = true
	_original_zoom = _camera.zoom
	var target := _resolve_focus_position()
	if pause_game:
		get_tree().paused = true
	_start_focus(target)


func _resolve_focus_position() -> Vector2:
	if not focus_target_path.is_empty():
		var target := get_node_or_null(focus_target_path) as Node2D
		if target != null:
			return target.global_position
	return focus_position


func _start_focus(target: Vector2) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(_camera, "global_position", target, move_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "zoom", focus_zoom, move_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(false)
	tween.tween_interval(hold_duration)
	tween.tween_callback(_return_to_player)


func _return_to_player() -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_player):
		_finish()
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(_camera, "global_position", _player.global_position, return_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "zoom", _original_zoom, return_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(false)
	tween.tween_callback(_finish)


func _finish() -> void:
	if is_instance_valid(_camera):
		_camera.position = Vector2.ZERO
		_camera.zoom = _original_zoom
	if pause_game:
		get_tree().paused = false
