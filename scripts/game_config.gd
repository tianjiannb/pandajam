extends Node
## 标题页专用的极简设置单例（GameConfig）。
## 仅服务于 title_screen.gd 自带的设置面板（主音量/音乐/音效滑条 + 全屏开关），
## 不写入真实的 AudioServer SFX/Music 总线，也不与 06 设置菜单（ui_settings_menu.gd）互通。
## 两套设置是有意分离的最小化实现，参见任务说明。

var master: float = 1.0
var music: float = 1.0
var sfx: float = 1.0
var fullscreen: bool = false
var session_iteration: int = 0

## 过场流程标记：要播放的剧情段（"intro" / "ending"）。
## 由标题页「开始游戏」或关卡出口触发器设置，cinematic 场景读取并播完后清空。
var cinematic_id: String = ""


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
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
			)
