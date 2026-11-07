extends Node
## 本局学习状态独立于循环。只观察玩法，不改变倒计时、碰撞或录制。
@export var enabled := true
@export var player_path: NodePath
@export_range(1, 20, 0.5) var notification_seconds := 6.0
@export_range(16, 40, 1) var font_size := 22
@export var bottom_margin := 36.0
@export var world_labels := true
@export_multiline var move_message := "WASD / 方向键移动"
@export_multiline var ghost_message := "过去的你，会重复刚才的行动。"
@export_multiline var end_round_message := "安排好行动后，按 Q 提前结束本轮，留下过去的你。"
@export_multiline var death_message := "这段行动已留下。过去的你会重演它；每轮都需要重新点亮装置。"
@export_multiline var cooperate_message := "过去的你正在踩住压力板，现在你可以通过对应的门。"
var learned: Dictionary = {}
var _player: Node2D
var _hints: Array[Node] = []
var _labels: Dictionary = {}
var _ui: CanvasLayer
var _banner: Label
var _context: Label
var _notice_queue: Array[Dictionary] = []
var _notice_time := 0.0
var _notice_key := ""
var _previous_position := Vector2.ZERO
var _travel := 0.0
var _ghost_count := 0
var _jump_hint: Node
var _jump_start := Vector2.ZERO
var _door_sides: Dictionary = {}
var _pulse := 0.0

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		push_warning("Tutorial: Player Path 无效，已关闭引导")
		set_process(false)
		return
	_previous_position = _player.global_position
	_ui = CanvasLayer.new()
	_ui.layer = 30
	add_child(_ui)
	_banner = _make_label()
	_context = _make_label()
	_ui.add_child(_banner)
	_ui.add_child(_context)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 24
	_banner.offset_bottom = 106
	_context.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_context.offset_top = -120 - bottom_margin
	_context.offset_bottom = -bottom_margin
	for child in get_children():
		if child.get_script() == preload("res://scripts/tutorial_hint.gd"):
			_hints.append(child)
			var label := _make_label()
			label.add_theme_font_size_override("font_size", maxi(16, font_size - 3))
			_ui.add_child(label)
			_labels[child] = label
	_player.jump_state_changed.connect(_on_jump)
	_player.hammer_state_changed.connect(_on_hammer)
	call_deferred("_connect_events")

func _make_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.95, 0.98, 1))
	label.add_theme_color_override("font_outline_color", Color(0.025, 0.045, 0.07, 0.95))
	label.add_theme_constant_override("outline_size", 7)
	return label

func _connect_events() -> void:
	for hint in _hints:
		var target: Node = hint.target
		if target == null:
			push_warning("Tutorial: 无效目标 " + str(hint.get_path()))
			continue
		if hint.kind == "trap":
			# 连接发生在机关自身回调之后；识别被重置前的进入对象，不依赖玩家当前位置。
			target.body_entered.connect(_on_trap_entered)
		if hint.kind == "breakable":
			target.destroyed.connect(_on_box_destroyed.bind(hint))

func _on_trap_entered(body: Node2D) -> void:
	if body == _player:
		_notify("trap_death", death_message)

func _on_box_destroyed(hint: Node) -> void:
	# 不把过去的你的破坏操作误算为玩家已学会按键。
	if _player.has_hammer and Input.is_action_just_pressed("use_hammer"):
		learned[hint.lesson_id] = true

func _on_hammer(owned: bool) -> void:
	if owned:
		learned["pickup"] = true

func _on_jump(jumping: bool) -> void:
	if jumping:
		_jump_start = _player.global_position
		_jump_hint = null
		for hint in _hints:
			if hint.kind == "jump" and is_instance_valid(hint.target) and _near(hint):
				_jump_hint = hint
	else:
		if is_instance_valid(_jump_hint):
			var obstacle: Node2D = _jump_hint.target
			var before := obstacle.to_local(_jump_start)
			var after := obstacle.to_local(_player.global_position)
			if before.x * after.x < 0 and _jump_start.distance_to(_player.global_position) > 24:
				learned[_jump_hint.lesson_id] = true
		_jump_hint = null

func _notify(key: String, text: String) -> void:
	if learned.has(key):
		return
	learned[key] = true
	_notice_queue.append({"key": key, "text": text})

func _near(hint: Node) -> bool:
	return _player.global_position.distance_to(hint.target.global_position) <= hint.trigger_radius

func _process(delta: float) -> void:
	_ui.visible = enabled
	if not enabled:
		return
	_pulse += delta
	var traveled := _previous_position.distance_to(_player.global_position)
	_previous_position = _player.global_position
	if traveled < 40.0:
		_travel += traveled
	if _travel > 80:
		learned["move"] = true
	if Input.is_action_just_pressed("suicide"):
		learned["q_used"] = true
	var count := get_tree().get_nodes_in_group("ghosts").size()
	if count > _ghost_count:
		_ghost_count = count
	# 过去的你出现不再弹文字：弱引导只保留基础操作和死亡机制。
	_notice_time -= delta
	if _notice_time <= 0:
		_banner.text = ""
		if not _notice_queue.is_empty():
			var notice: Dictionary = _notice_queue.pop_front()
			_notice_key = notice.key
			_banner.text = notice.text
			_notice_time = notification_seconds
	var best: Node = null
	var best_text := ""
	for hint in _hints:
		var label: Label = _labels[hint]
		label.visible = false
		if not hint.enabled or not is_instance_valid(hint.target):
			continue
		var nearby := _near(hint)
		if nearby:
			hint.nearby_seconds += delta
		var text := str(hint.message)
		var available := nearby and not learned.has(hint.lesson_id)
		# 普通门/压力板不再承担文字教学；死亡装置是唯一保留的机制引导。
		if hint.kind == "plate" or hint.kind == "door":
			available = false
		match hint.kind:
			"hammer":
				available = available and hint.target.is_available and not _player.has_hammer
			"breakable":
				available = available and _player.has_hammer and not hint.target.is_destroyed
			"plate":
				var bodies: Array = hint.target.get_overlapping_bodies()
				if bodies.has(_player):
					learned["plate_seen"] = true
				for body in bodies:
					if body.is_in_group("ghosts") and not body.get("_dead") and nearby:
						_notify("ghost_plate", cooperate_message)
				if nearby and hint.related != null:
					text += "  → 门 %s" % hint.target.plate_id
			"door":
				_check_passage(hint)
				available = nearby and not learned.has(hint.lesson_id)
			"special_door":
				_check_passage(hint)
				available = nearby and not learned.has(hint.lesson_id)
				text += "\n" + _signal_status(hint)
			"trap":
				text = text.replace("{id}", str(hint.target.signal_id))
		if available and hint.nearby_seconds >= hint.help_after_seconds and not hint.help_message.is_empty():
			text += "\n" + str(hint.help_message)
		if available and (best == null or hint.priority > best.priority):
			best = hint
			best_text = text
		if world_labels and nearby and hint.kind == "trap":
			_show_world(label, hint.target, hint.label_offset, "%s  %s" % [hint.target.signal_id, "●" if hint.target.active == 1 else "○"], hint.marker_color)
	if best != null:
		_context.text = best_text
		if world_labels:
			var marker: Node2D = best.related if best.related is Node2D else best.target
			_show_world(_labels[best], marker, best.label_offset, "▼", best.marker_color)
	else:
		_context.text = ""

func _signal_status(hint: Node) -> String:
	if hint.related == null:
		return ""
	var result := PackedStringArray()
	for i in range(hint.related.total_signals):
		result.append("%d %s" % [i + 1, "●" if hint.related._progress[i] == 1 else "○"])
	return "   ".join(result)

func _check_passage(hint: Node) -> void:
	var local: Vector2 = hint.target.to_local(_player.global_position)
	var previous: Vector2 = _door_sides.get(hint, local)
	# 门沿局部 X 轴；只把门洞范围内、开门期间的近距离跨越算作通过，排除归位传送。
	if hint.target.is_open and previous.y * local.y < 0 and previous.distance_to(local) < 40 and absf(local.x) < hint.target.door_length * 0.5 + 12:
		learned[hint.lesson_id] = true
		if hint.kind == "door":
			learned["door_guided"] = true
			for other in _hints:
				if other.kind == "plate" and other.related == hint.target:
					learned[other.lesson_id] = true
	_door_sides[hint] = local

func _show_world(label: Label, target: Node2D, offset: Vector2, text: String, color: Color) -> void:
	var screen := target.get_global_transform_with_canvas().origin + offset
	var viewport_size := get_viewport().get_visible_rect().size
	screen.x = clampf(screen.x, 70, viewport_size.x - 70)
	screen.y = clampf(screen.y, 60, viewport_size.y - 140)
	label.position = screen - Vector2(65, 20)
	label.size = Vector2(130, 40)
	label.text = text
	label.modulate = color
	label.visible = true
