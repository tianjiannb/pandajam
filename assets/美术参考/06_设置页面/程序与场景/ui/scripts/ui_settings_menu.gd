extends Control

## 设置菜单（UI-16）：音效音量 / 音乐音量 / 视野开关。
##  * 两个 HSlider 0–100%，实时写 AudioServer 总线 "SFX"/"Music"（不存在则回退 Master，行内注明）。
##  * CheckButton 驱动 NodePath vision_target_path（默认 ../VisionSystem）的 enabled；
##    找不到节点时禁用该行并给出说明（spec 要求）。
##  * 返回按钮关闭；发出 settings_changed(sfx, music, vision)（0.0–1.0 / bool）。
##  * 焦距：每行获得焦点时显示 MINT 描边（Slider 与 CheckButton 都能键盘调节）。

signal settings_changed(sfx: float, music: float, vision: bool)
signal closed

const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
const COLOR_MINT := Color(0.349, 0.8549, 0.7137, 1.0)
const COLOR_PANEL_BG := Color(0.0627, 0.1373, 0.1725, 1.0)

@export var handle_escape := true
@export var pause_tree := true
## 视野系统节点路径（相对本菜单）。HUD 集成时会改成实际 VisionSystem 路径。
@export var vision_target_path: NodePath = NodePath("../VisionSystem")

var _vision: Node = null
var _setting_up := false

@onready var _title: Label = $Center/MenuPanel/Content/Title
@onready var _rows: VBoxContainer = $Center/MenuPanel/Content/Rows
@onready var _sfx_slider: HSlider = $"Center/MenuPanel/Content/Rows/RowSfx/Row/Controls/SfxSlider"
@onready var _music_slider: HSlider = $"Center/MenuPanel/Content/Rows/RowMusic/Row/Controls/MusicSlider"
@onready var _vision_check: CheckButton = $"Center/MenuPanel/Content/Rows/RowVision/Row/Controls/VisionCheck"
@onready var _sfx_value: Label = $"Center/MenuPanel/Content/Rows/RowSfx/Row/Controls/Value"
@onready var _music_value: Label = $"Center/MenuPanel/Content/Rows/RowMusic/Row/Controls/Value"
@onready var _vision_hint: Label = $"Center/MenuPanel/Content/Rows/RowVision/Row/Controls/Hint"
@onready var _btn_back: Button = $"Center/MenuPanel/Content/Buttons/BtnBack"
@onready var _btn_reset: Button = $"Center/MenuPanel/Content/Buttons/BtnReset"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_setting_up = true
	_title.text = "设置"
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 100.0
	_sfx_slider.step = 1.0
	_music_slider.min_value = 0.0
	_music_slider.max_value = 100.0
	_music_slider.step = 1.0
	_sfx_slider.value = 80.0
	_music_slider.value = 60.0
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_vision_check.toggled.connect(_on_vision_toggled)
	_btn_back.pressed.connect(close)
	_btn_reset.pressed.connect(_on_reset_defaults)
	_setup_focus_ring(_sfx_slider)
	_setup_focus_ring(_music_slider)
	_setup_focus_ring(_vision_check)
	_update_volume_labels()
	_setting_up = false
	_resolve_vision()


func open() -> void:
	visible = true
	if pause_tree:
		get_tree().paused = true
	_resolve_vision()
	_sync_vision_check()
	_sfx_slider.grab_focus()


func close() -> void:
	visible = false
	if pause_tree:
		get_tree().paused = false
	closed.emit()


func is_open() -> bool:
	return visible


## HUD 在找到 VisionSystem 后调用，避免菜单自己靠相对路径猜。
func set_vision_target(node: Node) -> void:
	_vision = node
	_refresh_vision_row()


func get_values() -> Dictionary:
	return {
		"sfx": _sfx_slider.value / 100.0,
		"music": _music_slider.value / 100.0,
		"vision": _vision_check.button_pressed,
	}


func set_values(sfx: float, music: float, vision: bool) -> void:
	_setting_up = true
	_sfx_slider.value = clampf(sfx, 0.0, 1.0) * 100.0
	_music_slider.value = clampf(music, 0.0, 1.0) * 100.0
	_vision_check.set_pressed_no_signal(vision)
	_setting_up = false
	_update_volume_labels()


# ---------------------------------------------------------------- internals

func _resolve_vision() -> void:
	_vision = null
	if not vision_target_path.is_empty():
		_vision = get_node_or_null(vision_target_path)
	if _vision == null and is_inside_tree() and get_tree().current_scene != null:
		_vision = get_tree().current_scene.find_child("VisionSystem", true, false)
	_refresh_vision_row()


func _refresh_vision_row() -> void:
	if _vision == null:
		_vision_check.disabled = true
		_vision_check.set_pressed_no_signal(false)
		_vision_hint.text = "未找到视野系统，当前不可调"
		_vision_hint.add_theme_color_override("font_color", Color(0.9451, 0.5647, 0.5373, 1.0))
	else:
		_vision_check.disabled = false
		_vision_hint.text = "开启后只能看到当前区域与已探索区域"
		_vision_hint.add_theme_color_override("font_color", Color(0.6235, 0.7137, 0.7608, 1.0))
		_sync_vision_check()


func _sync_vision_check() -> void:
	if _vision == null:
		return
	var enabled := true
	var value = _vision.get("enabled")
	if value != null:
		enabled = bool(value)
	_vision_check.set_pressed_no_signal(enabled)


func _on_sfx_changed(value: float) -> void:
	_update_volume_labels()
	if _setting_up:
		return
	_apply_bus_volume(BUS_SFX, value / 100.0)
	_emit_changed()


func _on_music_changed(value: float) -> void:
	_update_volume_labels()
	if _setting_up:
		return
	_apply_bus_volume(BUS_MUSIC, value / 100.0)
	_emit_changed()


func _on_vision_toggled(pressed: bool) -> void:
	if _setting_up:
		return
	if _vision != null and _vision.get("enabled") != null:
		_vision.set("enabled", pressed)
	_emit_changed()


func _on_reset_defaults() -> void:
	set_values(0.8, 0.6, true)
	if _vision != null and _vision.get("enabled") != null:
		_vision.set("enabled", true)
	_apply_bus_volume(BUS_SFX, 0.8)
	_apply_bus_volume(BUS_MUSIC, 0.6)
	_emit_changed()


func _emit_changed() -> void:
	settings_changed.emit(
		_sfx_slider.value / 100.0,
		_music_slider.value / 100.0,
		_vision_check.button_pressed
	)


func _update_volume_labels() -> void:
	_sfx_value.text = "%d%%" % int(round(_sfx_slider.value))
	_music_value.text = "%d%%" % int(round(_music_slider.value))


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		index = AudioServer.get_bus_index("Master")
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)
	var row_name := "RowSfx" if bus_name == BUS_SFX else "RowMusic"
	var bus_label: Label = get_node_or_null("Center/MenuPanel/Content/Rows/%s/Row/BusNote" % row_name)
	if bus_label != null:
		bus_label.text = "" if AudioServer.get_bus_index(bus_name) >= 0 else "（无 %s 总线，已写入 Master）" % bus_name


func _setup_focus_ring(control: Control) -> void:
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color(COLOR_PANEL_BG.r, COLOR_PANEL_BG.g, COLOR_PANEL_BG.b, 0.0)
	idle.border_color = Color(COLOR_MINT.r, COLOR_MINT.g, COLOR_MINT.b, 0.0)
	idle.set_border_width_all(2)
	idle.set_corner_radius_all(3)
	idle.set_content_margin_all(8.0)
	var active := idle.duplicate() as StyleBoxFlat
	active.bg_color = Color(COLOR_PANEL_BG.r, COLOR_PANEL_BG.g, COLOR_PANEL_BG.b, 0.35)
	active.border_color = COLOR_MINT
	var panel := control.get_parent()
	while panel != null and not (panel is PanelContainer):
		panel = panel.get_parent()
	if panel is PanelContainer:
		(panel as PanelContainer).add_theme_stylebox_override("panel", idle)
		control.focus_entered.connect(func() -> void:
			(panel as PanelContainer).add_theme_stylebox_override("panel", active))
		control.focus_exited.connect(func() -> void:
			(panel as PanelContainer).add_theme_stylebox_override("panel", idle))


func _unhandled_input(event: InputEvent) -> void:
	if not handle_escape or not visible:
		return
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
