extends Node2D

## 终点线：玩家进入检测范围时发出 win 信号。
## 目前作为预留接口，暂无实际效果，仅用于调试打印。

signal win

@onready var _area: Area2D = $Area2D


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	print("win")
	win.emit()
