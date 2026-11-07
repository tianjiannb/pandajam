extends PanelContainer

## 操作提示（UI-07/08）：WASD / 方向键 / Space / E / Q 五组键帽 + 中文说明。
## Q 行明确「结束本轮（自杀）」并带 ui_state_self_end 图标；左下角常驻（HUD 中）。
## set_collapsed(true) 折叠成单行；F1 可切换（HUD 处理）。

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
const EMOJI_SELF_END := preload("res://assets/ui/ui_state_self_end.png")

const COMPACT_TEXT := "移动 WASD  跳跃 Space  交互 E  回环 Q/R"
const EXPANDED_MIN := Vector2(436, 250)
const COLLAPSED_MIN := Vector2(436, 56)

@export var collapsed := false:
	set(value):
		collapsed = value
		if is_node_ready():
			_apply_collapsed()

@onready var _rows: VBoxContainer = $Pad/Content/Rows
@onready var _compact: Label = $Pad/Content/Compact
@onready var _header: HBoxContainer = $Pad/Content/Header


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compact.text = COMPACT_TEXT
	_compact.autowrap_mode = TextServer.AUTOWRAP_OFF
	_compact.clip_text = true
	get_node("Pad/Content/Header/CollapseHint").text = "F1 收起"
	get_node("Pad/Content/Rows/HammerRow/HammerLabel").text = "交互"
	get_node("Pad/Content/Rows/HammerRow/HammerDesc").text = "使用扳手、搬运、切换机关"
	get_node("Pad/Content/Rows/EndRow/EndDesc").text = "结束本轮，留下回声"
	_apply_collapsed()


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
	# 独立放置（不在容器内）时跟随折叠高度；HUD 里用锚点，交给 ui_hud 调 offset。
	if get_parent() != null and not (get_parent() is Container):
		size = custom_minimum_size
		set_deferred("size", custom_minimum_size)
