extends Node2D

## 终点线：玩家进入检测范围后完成本局，并显示最小通关反馈。
signal win

## 留空时为最终终点；设置路径时传送到下一关。
@export_file("*.tscn") var next_scene_path := ""

var _won := false
var _overlay: CanvasLayer

@onready var _area: Area2D = $Area2D


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	if _won and Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()


func _on_body_entered(body: Node2D) -> void:
	if _won or not body.is_in_group("player"):
		return
	# 玩家正在死亡/被吞噬动画中时不触发终点（动画 tween 可能把玩家推入检测区）。
	if body.get("_pending_death_reset") or body.get("_devouring"):
		return
	_won = true
	print("win")
	win.emit()
	SfxManager.play("ending")
	if not next_scene_path.is_empty():
		call_deferred("_travel", body)
		return
	if body.has_method("set_physics_process"):
		body.set_physics_process(false)
	_show_win_overlay()


func _travel(body: Node2D) -> void:
	# 先验证资源，失败时允许再次进入终点，不把玩家困在完成状态。
	var destination := load(next_scene_path) as PackedScene
	if destination == null:
		push_error("无法加载下一关：" + next_scene_path)
		_won = false
		return
	var keep_gun := bool(body.get("has_gun"))
	var tree := get_tree()
	# 一次性监听由 SceneTree 持有，旧场景释放后仍能给新玩家恢复能力。
	if keep_gun:
		# scene_changed 的其他等待者可能先恢复，安排在新玩家 ready 后应用。
		tree.scene_changed.connect(_restore_gun.bind(tree), CONNECT_ONE_SHOT)
	var result := tree.change_scene_to_packed(destination)
	if result != OK:
		push_error("切换场景失败：%s" % result)
		_won = false


static func _restore_gun(tree: SceneTree) -> void:
	for player in tree.get_nodes_in_group("player"):
		if player.has_method("pickup_gun"):
			player.pickup_gun()


func _show_win_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.07, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(400, 180)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(panel)

	var title := Label.new()
	title.text = "完成"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	panel.add_child(title)

	var detail := Label.new()
	detail.text = "你到达了终点\n按 R 重新开始"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 24)
	panel.add_child(detail)
