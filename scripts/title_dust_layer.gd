extends Control
## 标题页背景漂浮粒子的绘制层。数据由 title_screen.gd 持有并驱动，这里只负责 _draw。

var dust_ref: Array[Dictionary] = []


func _draw() -> void:
	for d in dust_ref:
		draw_rect(Rect2(d["pos"], Vector2(d["size"], d["size"])),
			Color(0.62, 0.92, 0.85, d["alpha"]))
