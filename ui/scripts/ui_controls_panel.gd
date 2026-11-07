extends PanelContainer

## 操作提示（UI-07/08）：WASD / 方向键 / Space / E / F / Q 六组键帽 + 中文说明。
## F 行对应 fire_gun（拾到枪后发射子弹）；Q 行明确「结束本轮」并带 ui_state_self_end 图标；
## 左下角常驻。
## F1（toggle_controls_hint）在展开 / 折叠之间切换：折叠后只留一行键位摘要，
## 行尾提示「F1 展开」，标题行一起收起，避免内容撑破短面板。
## 面板在 main.tscn 里用左下角锚点 + 固定偏移定位，所以改高度时必须保持底边不动。

const KEY_W := preload("res://assets/ui/ui_key_w.png")
const KEY_A := preload("res://assets/ui/ui_key_a.png")
const KEY_S := preload("res://assets/ui/ui_key_s.png")
const KEY_D := preload("res://assets/ui/ui_key_d.png")
const KEY_UP := preload("res://assets/ui/ui_key_up.png")
const KEY_DOWN := preload("res://assets/ui/ui_key_down.png")
const KEY_LEFT := preload("res://assets/ui/ui_key_left.png")
const KEY_RIGHT := preload("res://assets/ui/ui_key_right.png")
const KEY_SPACE := preload("res://assets/ui/ui_key_space.png")
const KEY_E := preload("res://assets/ui/ui_key_e.png")
const KEY_Q := preload("res://assets/ui/ui_key_q.png")
const KEY_F := preload("res://assets/ui/ui_key_f.png")
const EMOJI_SELF_END := preload("res://assets/ui/ui_state_self_end.png")

const COMPACT_TEXT := "移动 WASD 跳跃 Space 交互 E 射击 F 回环 Q/R"
const COLLAPSE_HINT := "F1 收起"
const EXPAND_HINT := "F1 展开"
const EXPANDED_MIN := Vector2(436, 288)
const COLLAPSED_MIN := Vector2(436, 56)

@export var collapsed := false:
	set(value):
		collapsed = value
		if is_node_ready():
			_apply_collapsed()

@onready var _rows: VBoxContainer = $Pad/Content/Rows
@onready var _compact: HBoxContainer = $Pad/Content/Compact
@onready var _compact_text: Label = $Pad/Content/Compact/CompactText
@onready var _compact_hint: Label = $Pad/Content/Compact/CompactHint
@onready var _header: HBoxContainer = $Pad/Content/Header
@onready var _header_hint: Label = $Pad/Content/Header/CollapseHint


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compact_text.text = COMPACT_TEXT
	_compact_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_compact_text.clip_text = true
	_compact_hint.text = EXPAND_HINT
	_header_hint.text = COLLAPSE_HINT
	get_node("Pad/Content/Rows/HammerRow/HammerLabel").text = "交互"
	get_node("Pad/Content/Rows/HammerRow/HammerDesc").text = "使用扳手、搬运、切换机关"
	get_node("Pad/Content/Rows/EndRow/EndDesc").text = "结束本轮，留下回声"
	_apply_collapsed()


func _unhandled_input(event: InputEvent) -> void:
	# F1：随时收起 / 展开操作提示。暂停时忽略，避免在暂停遮罩后面盲改。
	if get_tree().paused:
		return
	if event.is_action_pressed("toggle_controls_hint"):
		get_viewport().set_input_as_handled()
		toggle_collapsed()


func set_collapsed(v: bool) -> void:
	collapsed = v


func toggle_collapsed() -> void:
	collapsed = not collapsed


func is_collapsed() -> bool:
	return collapsed


func _apply_collapsed() -> void:
	_rows.visible = not collapsed
	_compact.visible = collapsed
	# 折叠后只保留单行说明，标题行一起收起，避免内容撑破 56px 的短面板。
	_header.visible = not collapsed
	$Pad.add_theme_constant_override("margin_top", 4 if collapsed else 14)
	$Pad.add_theme_constant_override("margin_bottom", 4 if collapsed else 14)
	custom_minimum_size = COLLAPSED_MIN if collapsed else EXPANDED_MIN
	_refit_height(custom_minimum_size.y)


## custom_minimum_size 只能把面板撑大，不会把固定偏移留下的高度收回去，
## 所以这里手动改顶边：底边（贴屏幕底部）保持不动，高度取展开 / 折叠值。
func _refit_height(target_height: float) -> void:
	if get_parent() is Container:
		return  # 放进容器时交给容器排版
	var bottom_edge := offset_top + size.y
	if is_equal_approx(anchor_top, anchor_bottom):
		bottom_edge = offset_bottom
	offset_top = bottom_edge - target_height
