extends Control

## 头顶倒计时组件（UI-01/02/03/04/10）。
##
## 两种用法（Lead 集成契约）：
##  a) 独立放置：外部每帧调用 set_time_left(t)（或直接设置 time_left 属性）。
##  b) 自动跟随父节点：auto_follow_parent_timer = true（默认）时，
##     每帧读取 get_parent().get_node_or_null("CountdownTimer") 的 time_left，
##     player.gd / ghost.gd 无需任何改动；style 指定 &"player" / &"ghost"。
##
## 数字来自 assets/ui/ui_countdown_digits.png（768×80，12 格 64×80：0-9、冒号、减号）。
## 每位数字一份独立 ShaderMaterial 副本，写入 atlas_cell_uv + 不同 time_seed，
## 保证每位独立抖动、不串格（对应 ui/shaders/ui_countdown_handdrawn.gdshader 图集模式）。
##
## 状态：
##  * player 普通态：GOLD 数字 + ui_countdown_panel.png，正常抖动。
##  * 警告态：剩余 ≤ warning_threshold 时自动切 warning 材质 + warning 底板 + 数字脉冲/抖动加强。
##  * ghost 副本态：GHOST 紫数字 + ghost 底板，始终使用 ghost 身份（不切警告底）。

const DIGITS_TEXTURE := preload("res://assets/ui/ui_countdown_digits.png")
const MAT_PLAYER := preload("res://ui/materials/ui_countdown_player.tres")
const MAT_WARNING := preload("res://ui/materials/ui_countdown_warning.tres")
const MAT_GHOST := preload("res://ui/materials/ui_countdown_ghost.tres")
const PANEL_PLAYER := preload("res://assets/ui/ui_countdown_panel.png")
const PANEL_WARNING := preload("res://assets/ui/ui_countdown_panel_warning.png")
const PANEL_GHOST := preload("res://assets/ui/ui_countdown_panel_ghost.png")

const ATLAS_W := 768.0
const ATLAS_H := 80.0
const CELL_W := 64.0
const CELL_H := 80.0

const STYLE_PLAYER := &"player"
const STYLE_GHOST := &"ghost"
const MODE_PLAYER := &"player"
const MODE_WARNING := &"warning"
const MODE_GHOST := &"ghost"

## 剩余时间（秒）。外部可每帧写这个属性，或调用 set_time_left()。
@export var time_left := 12.0:
	set(value):
		time_left = value
		_refresh_digits()
		_refresh_state()

## 剩余 ≤ 该值（秒）时进入警告态（仅 player 身份）。
@export var warning_threshold := 3.0:
	set(value):
		warning_threshold = value
		_refresh_state()

## &"player"（金色）或 &"ghost"（紫色副本）。
@export var style: StringName = STYLE_PLAYER:
	set(value):
		style = STYLE_GHOST if value == STYLE_GHOST else STYLE_PLAYER
		_refresh_state()

## 是否显示手绘底板。
@export var show_panel := true:
	set(value):
		show_panel = value
		if is_node_ready():
			_panel.visible = value

## 自动从父节点的 CountdownTimer 读剩余时间（集成时不用改 player.gd / ghost.gd）。
@export var auto_follow_parent_timer := true

## 只显示数字、隐藏数字（保留底板）的开关。
@export var digits_visible := true:
	set(value):
		digits_visible = value
		if is_node_ready():
			_digits.visible = value

var _timer: Timer = null
var _mats: Array = []          # 每位：{mode: ShaderMaterial}
var _cell_index := [-1, -1]
# 初值留空，保证 _refresh_state() 第一次一定把材质赋给数字（否则会渲染图集白墨原色）。
var _mode: StringName = &""
var _anim_time := 0.0
var _digits_home := Vector2.ZERO
var _digit_rects: Array[TextureRect] = []

@onready var _panel: NinePatchRect = $Panel
@onready var _digits: HBoxContainer = $Digits


func _ready() -> void:
	_panel.visible = show_panel
	_digits.visible = digits_visible
	_digits_home = _digits.position
	_digit_rects = [$Digits/DigitTens, $Digits/DigitUnits]
	for i in _digit_rects.size():
		_mats.append(_build_materials(i))
	_refresh_digits()
	_refresh_state()
	if auto_follow_parent_timer:
		_bind_parent_timer()
	set_process(true)


func _bind_parent_timer() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_timer = parent.get_node_or_null("CountdownTimer") as Timer


func _process(delta: float) -> void:
	if auto_follow_parent_timer and is_instance_valid(_timer):
		set_time_left(_timer.time_left)
	_update_warning_animation(delta)


## Lead 集成契约：每帧写入剩余时间。
func set_time_left(t: float) -> void:
	if not is_equal_approx(t, time_left):
		time_left = t


## 兼容旧接口：set_time(t)。
func set_time(t: float) -> void:
	set_time_left(t)


## Lead 集成契约：&"player" / &"ghost"。
func set_style(new_style: StringName) -> void:
	style = new_style


## 只显示数字 / 全部隐藏。
func set_digits_visible(v: bool) -> void:
	digits_visible = v


## 当前是否处于警告态。
func is_warning() -> bool:
	return _mode == MODE_WARNING


# ---------------------------------------------------------------- internals

func _current_mode() -> StringName:
	if style == STYLE_GHOST:
		return MODE_GHOST
	if time_left <= warning_threshold and time_left > 0.0:
		return MODE_WARNING
	return MODE_PLAYER


func _build_materials(position_index: int) -> Dictionary:
	var out := {}
	var seeds := {
		MODE_PLAYER: 0.41 * float(position_index) + 0.13,
		MODE_WARNING: 0.41 * float(position_index) + 0.55,
		MODE_GHOST: 0.41 * float(position_index) + 0.79,
	}
	for mode in [MODE_PLAYER, MODE_WARNING, MODE_GHOST]:
		var base: ShaderMaterial = {MODE_PLAYER: MAT_PLAYER, MODE_WARNING: MAT_WARNING, MODE_GHOST: MAT_GHOST}[mode]
		var mat: ShaderMaterial = base.duplicate()
		mat.set_shader_parameter("time_seed", float(seeds[mode]))
		out[mode] = mat
	return out


func _apply_cell_uv(position_index: int, cell: int) -> void:
	var uv := Vector4(
		float(cell) * CELL_W / ATLAS_W,
		0.0,
		CELL_W / ATLAS_W,
		CELL_H / ATLAS_H
	)
	for mode in _mats[position_index].keys():
		(_mats[position_index][mode] as ShaderMaterial).set_shader_parameter("atlas_cell_uv", uv)


func _refresh_digits() -> void:
	if not is_node_ready():
		return
	var n := int(clampf(ceilf(time_left), 0.0, 99.0))
	var cells := [n / 10, n % 10]
	# 个位数不显示前导 0：十位直接隐藏，HBox 居中后单位仍居中。
	if _digit_rects.size() == 2:
		_digit_rects[0].visible = n >= 10
	for i in _digit_rects.size():
		if _cell_index[i] == cells[i]:
			continue
		_cell_index[i] = cells[i]
		var atlas := AtlasTexture.new()
		atlas.atlas = DIGITS_TEXTURE
		atlas.region = Rect2(float(cells[i]) * CELL_W, 0.0, CELL_W, CELL_H)
		_digit_rects[i].texture = atlas
		_apply_cell_uv(i, cells[i])


func _refresh_state() -> void:
	if not is_node_ready():
		return
	var new_mode := _current_mode()
	if new_mode != _mode:
		_mode = new_mode
		for i in _mats.size():
			_digit_rects[i].material = _mats[i][_mode]
	_panel.texture = _panel_texture_for(_mode)


func _panel_texture_for(mode: StringName) -> Texture2D:
	match mode:
		MODE_WARNING:
			return PANEL_WARNING
		MODE_GHOST:
			return PANEL_GHOST
		_:
			return PANEL_PLAYER


func _update_warning_animation(delta: float) -> void:
	_anim_time += delta
	var warning_now := _mode == MODE_WARNING
	var pulse := 0.0
	if warning_now:
		pulse = 0.2 + 0.8 * absf(sin(_anim_time * 6.4))
	for i in _mats.size():
		(_mats[i][MODE_WARNING] as ShaderMaterial).set_shader_parameter("pulse", pulse)
	if warning_now:
		# 警告时手抖加强：数字小幅位移 + 底板轻微呼吸。
		_digits.position = _digits_home + Vector2(
			sin(_anim_time * 47.0) * 1.6,
			cos(_anim_time * 39.0) * 1.2
		)
		_panel.modulate = Color(1, 1, 1, 0.86 + 0.14 * absf(sin(_anim_time * 6.4)))
	else:
		_digits.position = _digits.position.lerp(_digits_home, minf(1.0, delta * 16.0))
		_panel.modulate = Color(1, 1, 1, 1)
