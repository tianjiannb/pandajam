extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://scenes/title_screen.tscn")
	await create_timer(1.5).timeout
	await process_frame
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("res://.title_restored.png")
		print("saved")
	quit()
