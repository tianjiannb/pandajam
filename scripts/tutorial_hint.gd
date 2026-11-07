@tool
extends Node2D
## 关卡内的可调提示。Target Path 相对于本节点；留空使用本节点位置。
@export var enabled := true
@export var lesson_id := ""
@export_enum("proximity", "jump", "hammer", "breakable", "plate", "door", "trap", "special_door", "turret") var kind := "proximity"
@export var target_path: NodePath
@export var related_path: NodePath
@export_multiline var message := ""
@export_multiline var help_message := ""
@export_range(24, 600, 1) var trigger_radius := 130.0
@export_range(0, 120, 1) var help_after_seconds := 25.0
@export var priority := 10
@export var label_offset := Vector2(0, -60)
@export var marker_color := Color(0.5, 0.9, 1.0)
@export var show_editor_radius := true
var nearby_seconds := 0.0
var target: Node2D
var related: Node

func _ready() -> void:
	if not Engine.is_editor_hint():
		target = get_node_or_null(target_path) as Node2D if not target_path.is_empty() else self
		related = get_node_or_null(related_path) if not related_path.is_empty() else null

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint() and show_editor_radius:
		var anchor := get_node_or_null(target_path) as Node2D if not target_path.is_empty() else self
		if anchor != null:
			draw_arc(to_local(anchor.global_position), trigger_radius, 0, TAU, 64, marker_color, 1.0)
