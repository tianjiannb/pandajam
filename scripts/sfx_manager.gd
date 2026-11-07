extends Node

## 全局音效管理器（autoload 单例，名字 SfxManager）。
## 维护一个小型 AudioStreamPlayer 池，按名字播放一次性音效，避免互相打断。
## 使用: SfxManager.play("door")

const SOUND_PATHS := {
	"switch": "res://assets/audio/sfx/switch.wav",
	"door": "res://assets/audio/sfx/door.wav",
	"pickup": "res://assets/audio/sfx/pickup.wav",
	"rewind": "res://assets/audio/sfx/rewind.wav",
	"tick": "res://assets/audio/sfx/tick.wav",
	"tool": "res://assets/audio/sfx/tool.wav",
	"ending": "res://assets/audio/sfx/ending.wav",
	"gun_fire": "res://assets/audio/sfx/gun_fire.wav",
	"death": "res://assets/audio/sfx/death.wav",
}

## 播放器池大小：3-5 个足够覆盖同时触发，避免互相截断。
const POOL_SIZE := 4

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUND_PATHS.keys():
		var path: String = SOUND_PATHS[key]
		var stream := load(path) as AudioStream
		if stream != null:
			_streams[key] = stream
		else:
			push_warning("SfxManager: 无法加载音效 '%s' -> %s" % [key, path])
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)


## 按名字播放音效（名字需在 SOUND_PATHS 中存在）。
## 从池中取下一个播放器循环使用，不等待上一个播放完毕，避免互相打断。
func play(name: String) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		push_warning("SfxManager: 未知音效名 '%s'" % name)
		return
	if _players.is_empty():
		return
	var player := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	player.stream = stream
	player.play()
