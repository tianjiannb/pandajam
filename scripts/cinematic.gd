extends CanvasLayer

## 电影式剧情过场（自动播放）。
##  - 每镜：宽画幅高清图 + Ken Burns 缓慢推近 + 上下 letterbox 黑边 + 字幕淡入淡出。
##  - 镜头间黑场过渡；image 为空的镜头是「黑屏主题句」大字卡。
##  - 自动连播，Esc / 空格 / 回车可随时跳过整段。
##  - 播放哪一段由 GameConfig.cinematic_id 决定（"intro" / "ending"），
##    播完自动切到该段的 next_scene。
## 用法：GameConfig.cinematic_id = "intro" 后 change_scene_to_file("res://scenes/cinematic.tscn")。

const VIEW := Vector2(1280, 720)
const BAR := 78.0                 # 上下黑边高度
const FADE := 0.6                 # 镜头/字幕淡入淡出时长
const SUB_COLOR := Color(0.95, 0.93, 0.86, 1.0)

const AUDIO_DIR := "res://assets/audio/"

## 分镜表：image 留空 = 黑屏主题句；sfx 为进入该镜时播放的一次性音效。
const SEQUENCES := {
	"intro": {
		"music": AUDIO_DIR + "bgm/bgm_explore.wav",
		"music_db": -12.0,
		"next_scene": "res://scenes/main.tscn",
		"shots": [
			{"image": "res://assets/cinematic/intro_01.png", "duration": 5.0,
				"text": "它在碎裂的收容箱中醒来，不记得自己的名字。"},
			{"image": "res://assets/cinematic/intro_02.png", "duration": 4.5,
				"text": "视野的角落里，只剩 20 秒的倒计时。"},
			{"image": "res://assets/cinematic/intro_03.png", "duration": 5.5,
				"text": "濒死的超能力失控，把整座建筑折成了一枚莫比乌斯环。"},
			{"image": "res://assets/cinematic/intro_04.png", "duration": 6.0,
				"text": "每一次死亡都会留下残影。它用无数个自己，铺成通往出口的路。"},
			{"image": "res://assets/cinematic/intro_05.png", "duration": 5.5,
				"text": "只要推开那扇门，就能打破循环——它是这么相信的。"},
		],
	},
	"ending": {
		"music": AUDIO_DIR + "cycle_ambient.wav",
		"music_db": -14.0,
		"next_scene": "res://scenes/title_screen.tscn",
		"shots": [
			{"image": "res://assets/cinematic/ending_01.png", "duration": 4.5, "sfx": "ending",
				"text": "历经千辛万苦，它终于推开了大门。"},
			{"image": "res://assets/cinematic/ending_02.png", "duration": 5.5,
				"text": "门外站着的，是「自己」——正机械地做着推门的动作。"},
			{"image": "res://assets/cinematic/ending_03.png", "duration": 5.0,
				"text": "原来它逃出的不是循环，而是成为了循环。"},
			{"image": "res://assets/cinematic/ending_04.png", "duration": 5.5,
				"text": "逃得越远，环就延展得越长，永远套不到尽头。"},
			{"image": "", "duration": 6.5, "sfx": "rewind",
				"text": "出口即入口\n自由即新的囚笼"},
		],
	},
}

var _image: TextureRect
var _subtitle: Label
var _skip_hint: Label
var _music: AudioStreamPlayer

var _skipped := false
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	var id: String = GameConfig.cinematic_id
	if not SEQUENCES.has(id):
		id = "intro"
	_play(id)


# ---------------------------------------------------------------- UI 构建

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	_image = TextureRect.new()
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_image)

	# 上下 letterbox 黑边
	for is_top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if is_top:
			bar.anchor_bottom = 0.0
			bar.offset_bottom = BAR
		else:
			bar.anchor_top = 1.0
			bar.offset_top = -BAR
		root.add_child(bar)

	_subtitle = Label.new()
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", SUB_COLOR)
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_subtitle.add_theme_constant_override("outline_size", 6)
	root.add_child(_subtitle)
	_set_subtitle_card(false)

	_skip_hint = Label.new()
	_skip_hint.text = "Esc 跳过"
	_skip_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_skip_hint.add_theme_font_size_override("font_size", 16)
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.anchor_left = 1.0
	_skip_hint.anchor_top = 1.0
	_skip_hint.anchor_right = 1.0
	_skip_hint.anchor_bottom = 1.0
	_skip_hint.offset_left = -110.0
	_skip_hint.offset_top = -34.0
	_skip_hint.offset_right = -16.0
	_skip_hint.offset_bottom = -8.0
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_skip_hint)


func _set_subtitle_card(card: bool) -> void:
	if card:
		_subtitle.set_anchors_preset(Control.PRESET_FULL_RECT)
		_subtitle.add_theme_font_size_override("font_size", 40)
		_subtitle.add_theme_constant_override("line_spacing", 12)
	else:
		_subtitle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_subtitle.offset_top = -BAR
		_subtitle.offset_bottom = 0.0
		_subtitle.offset_left = 0.0
		_subtitle.offset_right = 0.0
		_subtitle.add_theme_font_size_override("font_size", 26)


# ---------------------------------------------------------------- 播放

func _play(id: String) -> void:
	var seq: Dictionary = SEQUENCES[id]
	_play_music(seq.get("music", ""), seq.get("music_db", -12.0))
	for shot in seq.shots:
		if _skipped:
			break
		await _play_shot(shot)
	_finish(seq.get("next_scene", "res://scenes/title_screen.tscn"))


func _play_shot(shot: Dictionary) -> void:
	var card: bool = String(shot.get("image", "")).is_empty()
	var duration: float = shot.get("duration", 5.0)
	if shot.has("sfx"):
		SfxManager.play(shot["sfx"])

	# 画面与字幕入场
	if card:
		_image.visible = false
	else:
		_image.visible = true
		_image.texture = load(shot["image"])
		_image.modulate.a = 0.0
		_image.pivot_offset = _image.size * 0.5
		_image.scale = Vector2.ONE * 1.02
		var kb := create_tween()
		kb.tween_property(_image, "scale", Vector2.ONE * 1.10, duration + FADE).from(Vector2.ONE * 1.02)
		var fi := create_tween()
		fi.tween_property(_image, "modulate:a", 1.0, FADE)

	_set_subtitle_card(card)
	_subtitle.text = shot.get("text", "")
	_subtitle.modulate.a = 0.0
	var st := create_tween()
	st.tween_property(_subtitle, "modulate:a", 1.0, FADE)

	await _wait(duration)

	# 出场（黑场过渡）
	if not _skipped:
		var fo := create_tween()
		fo.set_parallel(true)
		fo.tween_property(_subtitle, "modulate:a", 0.0, FADE)
		if not card:
			fo.tween_property(_image, "modulate:a", 0.0, FADE)
		await _wait(FADE)


func _finish(next_scene: String) -> void:
	if _done:
		return
	_done = true
	GameConfig.cinematic_id = ""
	if _music != null and is_instance_valid(_music):
		_music.stop()
	get_tree().change_scene_to_file(next_scene)


# ---------------------------------------------------------------- 工具

## 可被跳过打断的等待：逐帧推进，避免协程在场景切换后被唤醒。
func _wait(t: float) -> void:
	var elapsed := 0.0
	while elapsed < t and not _skipped:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _play_music(path: String, db: float) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = db
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / (4 if wav.stereo else 2)
		_music.stream = wav
	else:
		_music.stream = stream
	add_child(_music)
	_music.play()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("pause_menu") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		_skipped = true
