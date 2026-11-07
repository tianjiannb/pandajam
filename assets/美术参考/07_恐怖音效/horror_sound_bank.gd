extends Node
## 自包含音效播放器。放入游戏场景，调用 fire() / impact() / death()。
## 每次随机选一条不同的变体；不依赖本交付包的预览界面。

const ROOT := "res://assets/audio/horror/"
const BANK := {
	"fire": ["01_射击_01_安保气动枪.wav", "01_射击_02_电弧穿刺.wav", "01_射击_03_生化脉冲.wav"],
	"impact": ["02_冲击_01_金属重击.wav", "02_冲击_02_玻璃与肉质.wav", "02_冲击_03_低频爆震.wav"],
	"death": ["03_死亡_01_实验体崩解.wav", "03_死亡_02_窒息回声.wav", "03_死亡_03_循环吞噬.wav"],
}

var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _previous: Dictionary = {}
var _last_ms := -1000
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	for category in BANK:
		for file in BANK[category]:
			_streams[file] = load(ROOT + file)
	for i in range(12):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = -8
		add_child(player)
		_voices.append(player)


func fire() -> void:
	play_variant("fire")


func impact() -> void:
	play_variant("impact")


func death() -> void:
	play_variant("death")


func play_variant(category: String) -> void:
	if not BANK.has(category):
		return
	var list: Array = BANK[category]
	var index := _rng.randi_range(0, list.size() - 1)
	if index == _previous.get(category, -1):
		index = (index + 1) % list.size()
	_previous[category] = index
	play_file(list[index], category == "fire")


func play_file(file: String, rate_limit := false) -> void:
	if not _streams.has(file):
		return
	var now := Time.get_ticks_msec()
	if rate_limit and now - _last_ms < 60:
		return
	_last_ms = now
	var voice: AudioStreamPlayer
	for candidate in _voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		voice = _voices[0]
	voice.stop()
	voice.stream = _streams[file]
	voice.pitch_scale = _rng.randf_range(.97, 1.03) if rate_limit else 1.0
	voice.play()


func stop_all() -> void:
	for voice in _voices:
		voice.stop()
