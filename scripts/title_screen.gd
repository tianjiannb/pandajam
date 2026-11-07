extends Control
## 标题页：进入游戏、设置、操作说明。
## 节点树在 scenes/title_screen.tscn 里可视化编辑，本脚本只负责逻辑接线。

const VIEW := Vector2(1280, 720)
const AUDIO_DIR := "res://assets/audio/"

var buttons: Array[Button] = []
var music: AudioStreamPlayer
var settings_layer: Control
var help_layer: Control
var _dust: Array[Dictionary] = []

@onready var _dust_layer: Control = $DustLayer  # TitleDustLayer script draws from its own dust_ref
@onready var _btn_start: Button = $LeftMenuMargin/TitleMenu/MenuBox/BtnStart
@onready var _btn_settings: Button = $LeftMenuMargin/TitleMenu/MenuBox/BtnSettings
@onready var _btn_help: Button = $LeftMenuMargin/TitleMenu/MenuBox/BtnHelp
@onready var _btn_quit: Button = $LeftMenuMargin/TitleMenu/MenuBox/BtnQuit

@onready var _slider_master: HSlider = $SettingsLayer/Center/Panel/Box/RowMaster/Slider
@onready var _slider_music: HSlider = $SettingsLayer/Center/Panel/Box/RowMusic/Slider
@onready var _slider_sfx: HSlider = $SettingsLayer/Center/Panel/Box/RowSfx/Slider
@onready var _btn_fullscreen: Button = $SettingsLayer/Center/Panel/Box/BtnFullscreen
@onready var _btn_settings_back: Button = $SettingsLayer/Center/Panel/Box/BtnBack
@onready var _btn_help_back: Button = $HelpLayer/Center/Panel/Box/BtnBack


func _ready() -> void:
	settings_layer = $SettingsLayer
	help_layer = $HelpLayer
	buttons = [_btn_start, _btn_settings, _btn_help, _btn_quit]

	_apply_button_style(_btn_start)
	_apply_button_style(_btn_settings)
	_apply_button_style(_btn_help)
	_apply_button_style(_btn_quit)
	_apply_small_button_style(_btn_fullscreen)
	_apply_small_button_style(_btn_settings_back)
	_apply_small_button_style(_btn_help_back)
	_style_sliders()

	for i in range(buttons.size()):
		buttons[i].focus_neighbor_top = buttons[(i - 1 + buttons.size()) % buttons.size()].get_path()
		buttons[i].focus_neighbor_bottom = buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_mode = Control.FOCUS_ALL

	_btn_start.pressed.connect(_on_start)
	_btn_settings.pressed.connect(_show_settings)
	_btn_help.pressed.connect(_show_help)
	_btn_quit.pressed.connect(_on_quit)
	_btn_settings_back.pressed.connect(_hide_overlays)
	_btn_help_back.pressed.connect(_hide_overlays)

	_slider_master.value = GameConfig.master
	_slider_music.value = GameConfig.music
	_slider_sfx.value = GameConfig.sfx
	_slider_master.value_changed.connect(func(v: float) -> void: GameConfig.set_value("master", v))
	_slider_music.value_changed.connect(func(v: float) -> void: GameConfig.set_value("music", v))
	_slider_sfx.value_changed.connect(func(v: float) -> void: GameConfig.set_value("sfx", v))

	_btn_fullscreen.text = "全屏：%s" % ("开" if GameConfig.fullscreen else "关")
	_btn_fullscreen.pressed.connect(func() -> void:
		var on: bool = not GameConfig.fullscreen
		GameConfig.set_value("fullscreen", on)
		_btn_fullscreen.text = "全屏：%s" % ("开" if on else "关"))

	_build_dust()
	_dust_layer.set("dust_ref", _dust)
	_start_ambient()
	buttons[0].grab_focus()
	set_process(true)


func _apply_button_style(btn: Button) -> void:
	# 正常显示按钮：深色底 + 描边，hover 时高亮。
	var normal := _style(Color(0.04, 0.08, 0.1, 0.9), Color(0.24, 0.42, 0.4, 0.8))
	var hover := _style(Color(0.11, 0.29, 0.27, 0.98), Color(0.62, 0.94, 0.84, 1.0))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	var text_color := Color(0.81, 0.91, 0.89, 1)
	var text_hi := Color(0.87, 0.98, 0.95, 1)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_hi)
	btn.add_theme_color_override("font_focus_color", text_hi)
	btn.add_theme_color_override("font_pressed_color", text_hi)


func _apply_small_button_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _style(Color(0.04, 0.08, 0.1, 0.9), Color(0.34, 0.6, 0.57, 0.5)))
	btn.add_theme_stylebox_override("hover", _style(Color(0.11, 0.29, 0.27, 0.98), Color(0.62, 0.94, 0.84, 1.0)))
	btn.add_theme_stylebox_override("focus", _style(Color(0.11, 0.29, 0.27, 0.98), Color(0.62, 0.94, 0.84, 1.0)))


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb


func _style_sliders() -> void:
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
	for slider in [_slider_master, _slider_music, _slider_sfx]:
		slider.add_theme_stylebox_override("slider", track)
		slider.add_theme_stylebox_override("grabber_area", fill)
		slider.add_theme_stylebox_override("grabber_area_highlight", fill_hi)


func _build_dust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107
	for i in range(46):
		_dust.append({
			"pos": Vector2(rng.randf_range(0, VIEW.x), rng.randf_range(0, VIEW.y)),
			"speed": rng.randf_range(4.0, 16.0),
			"size": rng.randf_range(0.6, 1.8),
			"alpha": rng.randf_range(0.06, 0.22),
		})


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
	_dust_layer.queue_redraw()


func _on_start() -> void:
	GameConfig.session_iteration = 1
	GameConfig.cinematic_id = "intro"
	if music != null:
		var tween := create_tween()
		tween.tween_property(music, "volume_db", -60.0, 0.5)
	get_tree().change_scene_to_file("res://scenes/cinematic.tscn")


func _on_quit() -> void:
	get_tree().quit()
