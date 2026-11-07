extends Node
# 全局设置：音量、全屏。存档 user://settings.cfg

const PATH := "user://settings.cfg"

var master := 0.85
var music := 0.70
var sfx := 0.90
var fullscreen := false
var vision := false
var session_iteration := 1


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master = float(cfg.get_value("audio", "master", master))
	music = float(cfg.get_value("audio", "music", music))
	sfx = float(cfg.get_value("audio", "sfx", sfx))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	vision = bool(cfg.get_value("video", "vision", vision))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vision", vision)
	cfg.save(PATH)


func apply() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	for entry in [["Music", music], ["SFX", sfx]]:
		var index := AudioServer.get_bus_index(entry[0])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(entry[1], .0001)))
		AudioServer.set_bus_mute(index, entry[1] <= .001)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func set_value(key: String, value) -> void:
	match key:
		"master":
			master = value
		"music":
			music = value
		"sfx":
			sfx = value
		"fullscreen":
			fullscreen = value
		"vision":
			vision = value
	apply()
	save_settings()
