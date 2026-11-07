extends Control

## 暂停菜单（UI-11）：继续 / 重新开始 / 设置 / 退出。
##  * 键盘 + 鼠标：按钮可聚焦，上下键循环移动，Enter/Space 触发；Esc 关闭（handle_escape）。
##  * process_mode = ALWAYS，暂停时仍可操作。
##  * pause_tree = true 时自己负责 get_tree().paused；HUD 集成时由 HUD 统一管理（HUD 置 false）。
##  * 「退出」在无外部监听时直接 get_tree().quit()；「重新开始」在无监听时 reload_current_scene。

signal resumed
signal restart_requested
signal settings_requested
signal quit_requested

@export var handle_escape := true
@export var pause_tree := true

var _buttons: Array[Button] = []

@onready var _dim: ColorRect = $Dim
@onready var _menu_panel: PanelContainer = $Center/MenuPanel
@onready var _buttons_root: VBoxContainer = $Center/MenuPanel/Content/Buttons
@onready var _title: Label = $Center/MenuPanel/Content/Title


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.text = "暂停"
	for child in _buttons_root.get_children():
		if child is Button:
			_buttons.append(child)
	for i in _buttons.size():
		var b := _buttons[i]
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_button_pressed.bind(b))
	for i in _buttons.size():
		var b := _buttons[i]
		var prev := _buttons[(i - 1 + _buttons.size()) % _buttons.size()]
		var next := _buttons[(i + 1) % _buttons.size()]
		b.focus_neighbor_top = b.get_path_to(prev)
		b.focus_neighbor_bottom = b.get_path_to(next)
		b.focus_neighbor_left = b.get_path_to(prev)
		b.focus_neighbor_right = b.get_path_to(next)


# ---------------------------------------------------------------- public API

func open() -> void:
	visible = true
	if pause_tree:
		get_tree().paused = true
	if _buttons.size() > 0:
		_buttons[0].grab_focus()


func close(keep_paused := false) -> void:
	visible = false
	if pause_tree and not keep_paused:
		get_tree().paused = false


func toggle() -> void:
	if visible:
		resume()
	else:
		open()


func is_open() -> bool:
	return visible


func resume() -> void:
	close()
	resumed.emit()


func request_restart() -> void:
	close()
	restart_requested.emit()
	if restart_requested.get_connections().is_empty():
		get_tree().paused = false
		get_tree().reload_current_scene()


func request_quit() -> void:
	quit_requested.emit()
	if quit_requested.get_connections().is_empty():
		get_tree().quit()


# ---------------------------------------------------------------- internals

func _on_button_pressed(button: Button) -> void:
	match button.name:
		"BtnResume":
			resume()
		"BtnRestart":
			request_restart()
		"BtnSettings":
			settings_requested.emit()
		"BtnQuit":
			request_quit()


func _unhandled_input(event: InputEvent) -> void:
	if not handle_escape or not visible:
		return
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume()
