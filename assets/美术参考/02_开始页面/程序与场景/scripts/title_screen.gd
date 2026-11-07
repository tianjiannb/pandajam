extends Control
## 标题页：进入游戏、设置、操作说明。全部 UI 由代码生成。

const VIEW := Vector2(1280, 720)
const UI_DIR := "res://assets/ui/"
const AUDIO_DIR := "res://assets/audio/"

var font: Font
var menu_box: VBoxContainer
var buttons: Array[Button] = []
var music: AudioStreamPlayer
var settings_layer: Control
var help_layer: Control
var _dust: Array[Dictionary] = []


func _ready() -> void:
	_build_font()
	_build_background()
	_build_left_column()
	_build_settings()
	_build_help()
	_start_ambient()
	set_process(true)


func _build_font() -> void:
	font = load("res://assets/fonts/ui_zh_regular.otf")
	theme = load("res://ui/theme/ui_theme.tres")


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(UI_DIR + "title_bg.png"):
		bg.texture = load(UI_DIR + "title_bg.png")
	bg.modulate = Color(0.62, 0.68, 0.72)
	add_child(bg)

	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.05, 0.06, 0.45)
	add_child(veil)

	if ResourceLoader.exists(UI_DIR + "title_veil.png"):
		var grad := TextureRect.new()
		grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		grad.stretch_mode = TextureRect.STRETCH_SCALE
		grad.texture = load(UI_DIR + "title_veil.png")
		add_child(grad)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107
	for i in range(46):
		_dust.append({
			"pos": Vector2(rng.randf_range(0, VIEW.x), rng.randf_range(0, VIEW.y)),
			"speed": rng.randf_range(4.0, 16.0),
			"size": rng.randf_range(0.6, 1.8),
			"alpha": rng.randf_range(0.06, 0.22),
		})


func _build_left_column() -> void:
	var margin := MarginContainer.new()
	margin.name = "LeftMenuMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 88)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)
	var column := VBoxContainer.new()
	column.name = "TitleMenu"
	column.custom_minimum_size = Vector2(430, 0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var logo := Label.new()
	logo.name = "GameTitle"
	logo.text = "DL-Circle"
	logo.add_theme_font_override("font", load("res://assets/fonts/ui_zh_bold.otf"))
	logo.add_theme_font_size_override("font_size", 68)
	logo.add_theme_color_override("font_color", Color("#9cebd0"))
	logo.add_theme_color_override("font_outline_color", Color("#0c2728"))
	logo.add_theme_constant_override("outline_size", 5)
	logo.add_theme_color_override("font_shadow_color", Color(0.29, .92, .72, .3))
	logo.add_theme_constant_override("shadow_offset_x", 3)
	logo.add_theme_constant_override("shadow_offset_y", 3)
	column.add_child(logo)

	var sub := Label.new()
	sub.text = "十二秒一轮 · 影子会替你记住"
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color("#93bdb9"))
	sub.add_theme_color_override("font_outline_color", Color("#08110f"))
	sub.add_theme_constant_override("outline_size", 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	column.add_child(spacer)

	menu_box = VBoxContainer.new()
	menu_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 10)
	column.add_child(menu_box)

	var items := [
		["开始实验", _on_start],
		["设置", _show_settings],
		["操作说明", _show_help],
		["退出", _on_quit],
	]
	for entry in items:
		var btn := Button.new()
		btn.text = entry[0]
		btn.custom_minimum_size = Vector2(252, 44)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color("#cfe8e2"))
		btn.add_theme_color_override("font_hover_color", Color("#dffbf2"))
		btn.add_theme_color_override("font_focus_color", Color("#dffbf2"))
		btn.add_theme_color_override("font_pressed_color", Color("#dffbf2"))
		for state in ["normal", "hover", "focus", "pressed"]:
			btn.add_theme_stylebox_override(state, theme.get_stylebox(state, "Button"))
		btn.pressed.connect(entry[1])
		menu_box.add_child(btn)
		buttons.append(btn)

	for i in range(buttons.size()):
		buttons[i].focus_neighbor_top = buttons[(i - 1 + buttons.size()) % buttons.size()].get_path()
		buttons[i].focus_neighbor_bottom = buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_mode = Control.FOCUS_ALL

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap2)

	var foot := Label.new()
	foot.text = "PandaJam 2026 · 多劳多得队不队"
	foot.add_theme_font_override("font", font)
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color(0.55, 0.68, 0.68, 0.7))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(foot)

	buttons[0].grab_focus()


func _build_settings() -> void:
	var center := _make_layer()
	settings_layer = center.get_parent()
	var panel := _panel(Vector2(320, 0))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_title_label("设置"))
	box.add_child(_slider_row("主音量", "master", GameConfig.master))
	box.add_child(_slider_row("音乐", "music", GameConfig.music))
	box.add_child(_slider_row("音效", "sfx", GameConfig.sfx))

	var full := Button.new()
	full.custom_minimum_size = Vector2(0, 30)
	full.text = "全屏：%s" % ("开" if GameConfig.fullscreen else "关")
	full.add_theme_font_override("font", font)
	full.add_theme_font_size_override("font_size", 15)
	full.add_theme_color_override("font_color", Color("#cfe8e2"))
	full.add_theme_color_override("font_hover_color", Color("#dffbf2"))
	full.add_theme_stylebox_override("normal", _style(Color(0.04, 0.08, 0.1, 0.9), Color(0.24, 0.42, 0.4, 0.8)))
	full.add_theme_stylebox_override("hover", _style(Color(0.11, 0.29, 0.27, 0.98), Color(0.62, 0.94, 0.84, 1.0)))
	full.add_theme_stylebox_override("focus", _style(Color(0.11, 0.29, 0.27, 0.98), Color(0.62, 0.94, 0.84, 1.0)))
	full.pressed.connect(func() -> void:
		var on: bool = not GameConfig.fullscreen
		GameConfig.set_value("fullscreen", on)
		full.text = "全屏：%s" % ("开" if on else "关"))
	box.add_child(full)

	var back := _small_button("返回")
	back.pressed.connect(_hide_overlays)
	box.add_child(back)


func _build_help() -> void:
	var center := _make_layer()
	help_layer = center.get_parent()
	var panel := _panel(Vector2(500, 0))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	box.add_child(_title_label("操作说明"))
	for line in [
		"WASD / 方向键　　移动",
		"空格　　　　　　　跳跃",
		"E　　　　　　　　 交互 / 使用扳手",
		"Q / R　　　　　　 结束本轮，留下回声",
		"Esc　　　　　　　 暂停",
		"",
		"目标：借助过去的自己，逃出实验室。",
		"影子会重演你上一轮的动作——利用它。",
	]:
		var label := Label.new()
		label.text = line
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 15 if line != "" else 8)
		label.add_theme_color_override("font_color", Color("#b9d6d2"))
		box.add_child(label)
	var back := _small_button("返回")
	back.pressed.connect(_hide_overlays)
	box.add_child(back)


func _make_layer() -> CenterContainer:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.visible = false
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	return center


func _panel(min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.07, 0.09, 0.97)
	sb.border_color = Color(0.34, 0.6, 0.57, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	return panel


func _title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("#8fe6cf"))
	return label


func _slider_row(caption: String, key: String, value: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(70, 0)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#cfe8e2"))
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(170, 24)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.07, 0.13, 0.15, 1.0)
	track.border_color = Color(0.24, 0.42, 0.4, 0.9)
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.33, 0.85, 0.71, 1.0)
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	var fill_hi := StyleBoxFlat.new()
	fill_hi.bg_color = Color(0.55, 0.95, 0.82, 1.0)
	fill_hi.set_corner_radius_all(3)
	fill_hi.content_margin_top = 5
	fill_hi.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hi)
	slider.value_changed.connect(func(v: float) -> void: GameConfig.set_value(key, v))
	row.add_child(slider)
	return row


func _small_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 32)
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color("#cfe8e2"))
	btn.add_theme_color_override("font_hover_color", Color("#dffbf2"))
	btn.add_theme_stylebox_override("normal", _style(Color(0.04, 0.08, 0.1, 0.9), Color(0.34, 0.6, 0.57, 0.5)))
	btn.add_theme_stylebox_override("hover", _style(Color(0.11, 0.29, 0.27, 0.98), Color(0.62, 0.94, 0.84, 1.0)))
	btn.add_theme_stylebox_override("focus", _style(Color(0.11, 0.29, 0.27, 0.98), Color(0.62, 0.94, 0.84, 1.0)))
	return btn


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb


func _start_ambient() -> void:
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.volume_db = -8.0
	var path := AUDIO_DIR + "cycle_ambient.wav"
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamWAV:
			var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = wav.data.size() / (4 if wav.stereo else 2)
			music.stream = wav
	add_child(music)
	if music.stream != null:
		music.play()


func _show_settings() -> void:
	settings_layer.visible = true
	help_layer.visible = false


func _show_help() -> void:
	help_layer.visible = true
	settings_layer.visible = false


func _hide_overlays() -> void:
	settings_layer.visible = false
	help_layer.visible = false
	buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_layer.visible or help_layer.visible:
			_hide_overlays()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	for d in _dust:
		d["pos"].y -= d["speed"] * delta
		d["pos"].x += sin(d["pos"].y * 0.02) * 3.0 * delta
		if d["pos"].y < -4:
			d["pos"] = Vector2(randf_range(0, VIEW.x), VIEW.y + 4)
	queue_redraw()


func _draw() -> void:
	for d in _dust:
		draw_rect(Rect2(d["pos"], Vector2(d["size"], d["size"])),
			Color(0.62, 0.92, 0.85, d["alpha"]))


func _on_start() -> void:
	GameConfig.session_iteration = 1
	if music != null:
		var tween := create_tween()
		tween.tween_property(music, "volume_db", -60.0, 0.5)
	await ScreenFade.goto_scene("res://scenes/test2_entry.tscn")


func _on_quit() -> void:
	get_tree().quit()
