extends SceneTree

## 恢复被误删的标题页背景图：从 .godot/imported 的 .ctex 缓存解码回 PNG。

const CTEX := "res://.godot/imported/56dbfd46d2a0837aaf2a11cb2af67808.png-a0a50d983757534f71d013112f2f34be.ctex"
const OUT := "res://assets/cinematic/56dbfd46d2a0837aaf2a11cb2af67808.png"

func _initialize() -> void:
	var tex := load(CTEX) as Texture2D
	if tex == null:
		print("ctex 加载失败")
		quit()
		return
	var img := tex.get_image()
	if img == null:
		print("get_image 失败")
		quit()
		return
	var err := img.save_png(OUT)
	print("恢复 ", OUT, " size=", img.get_size(), " err=", err)
	quit()
