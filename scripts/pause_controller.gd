extends CanvasLayer

## 按 Esc（pause_menu 动作）打开暂停菜单。
## 菜单打开后的关闭由 ui_pause_menu.gd / ui_settings_menu.gd 自己处理。
## 子节点先于本节点收到 _unhandled_input，所以菜单已打开时 Esc 会被它们消费，不会重复触发。

@export var pause_menu_path: NodePath = ^"PauseMenu"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_menu"):
		return
	var menu := get_node_or_null(pause_menu_path)
	if menu == null or menu.is_open():
		return
	get_viewport().set_input_as_handled()
	menu.open()
