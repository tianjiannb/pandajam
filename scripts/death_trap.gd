extends Area2D
class_name DeathTrap

## 血肉能量垃圾桶：通过吞噬生命来激活。
## 视觉三态：idle 血肉呼吸脉动 → devour 张口咬合 + 能量爆发 → active 激活提亮。
## 玩家被吞噬（on_devoured，播放吸入动画、不留尸体）；副本仍走默认死亡。
## 信号机制与原白模一致：active 本轮内 0->1 边沿广播一次，restore() 延迟到新一轮清零。

signal state_changed(signal_id: int, active: int)

@export var signal_id := 1

const TEX_IDLE := preload("res://assets/traps/trap_idle.png")
const TEX_DEVOUR := preload("res://assets/traps/trap_devour.png")
const HEIGHT := 66.0                              # 桶的显示高度（像素）
const CORE_TINT := Color(0.45, 0.95, 0.8)         # 薄荷绿能量

var active := 0

var _time := 0.0
var _devouring := false
var _base_scale := Vector2.ONE
var _motes: CPUParticles2D
var _devour_tween: Tween

@onready var _visual: Sprite2D = $Body


func _ready() -> void:
	add_to_group("death_traps")
	body_entered.connect(_on_body_entered)
	# 贴图缩放到目标高度，桶底对齐碰撞箱底部（碰撞 40x40，底部 y=20）。
	_base_scale = Vector2.ONE * (HEIGHT / TEX_IDLE.get_height())
	_visual.scale = _base_scale
	_visual.position = Vector2(0, 20.0 - HEIGHT * 0.5)
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_setup_motes()


## 血肉能量微粒：从桶口上方逸出，向上飘离，不遮挡中央核心。
func _setup_motes() -> void:
	_motes = CPUParticles2D.new()
	_motes.amount = 8
	_motes.lifetime = 1.2
	_motes.emitting = true
	_motes.direction = Vector2(0, -1)
	_motes.spread = 30.0
	_motes.gravity = Vector2(0, -14)
	_motes.initial_velocity_min = 10.0
	_motes.initial_velocity_max = 24.0
	_motes.scale_amount_min = 0.8
	_motes.scale_amount_max = 1.6
	_motes.color = CORE_TINT
	_motes.position = Vector2(0, -46.0)  # 桶口上方
	_motes.texture = _make_dot_texture()
	add_child(_motes)


## 生成一个小圆点纹理，作为能量微粒的精灵（CPUParticles2D 需要纹理才渲染）。
func _make_dot_texture() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for x in range(8):
		for y in range(8):
			var d := Vector2(x - 3.5, y - 3.5).length()
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d <= 3.5 else 0.0))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_time += delta
	var speed := 4.2 if active else 2.2
	var amp := 0.09 if active else 0.045
	# 血肉呼吸：激活后更快更剧烈。
	if not _devouring:
		_visual.scale = _base_scale * (1.0 + amp * sin(_time * speed))
	# 明暗呼吸（乘法，保持血肉色相），激活时略微提亮偏能量绿。
	var base := 1.06 if active else 0.96
	var span := 0.14 if active else 0.06
	var b := base + span * sin(_time * speed + 1.0)
	_visual.modulate = Color(b * (0.95 if active else 1.0), b, b * 0.98, 1.0)


# ---------------------------------------------------------------- 吞噬

## 张口咬合 + 能量爆发，0.55s 后回到 idle 贴图（保持激活提亮）。
func devour() -> void:
	_visual.texture = TEX_DEVOUR
	_devouring = true
	if _devour_tween != null and _devour_tween.is_valid():
		_devour_tween.kill()
	# 先张大，再猛合，最后回弹——模拟咬合。
	_visual.scale = _base_scale * 1.18
	_devour_tween = create_tween()
	_devour_tween.tween_property(_visual, "scale", _base_scale * 0.86, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_devour_tween.tween_property(_visual, "scale", _base_scale, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 一次性血肉能量爆发。
	_motes.amount = 30
	_motes.color = Color(1.0, 0.45, 0.45)
	_motes.restart()
	# 用信号而非 await，避免场景切换后协程被唤醒。
	get_tree().create_timer(0.55).timeout.connect(_on_devour_finished)


func _on_devour_finished() -> void:
	_devouring = false
	_visual.texture = TEX_IDLE
	_motes.amount = 12
	_motes.color = CORE_TINT


# ---------------------------------------------------------------- 击杀

func _on_body_entered(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("ghosts")):
		return
	if not body.has_method("on_devoured") and not body.has_method("on_bullet_hit"):
		return
	devour()
	# 信号只在本轮 0->1 边沿广播一次；但吞噬对每个进入者都生效。
	if active == 0:
		active = 1
		state_changed.emit(signal_id, active)
		SfxManager.play("switch")
	if body.has_method("on_devoured"):
		body.on_devoured(self)
	elif body.has_method("on_bullet_hit"):
		body.on_bullet_hit()


## 新一轮起始帧统一调用：恢复未触发状态，允许本轮再次广播与吞噬。
func restore() -> void:
	if active == 0:
		return
	active = 0
	_devouring = false
	_visual.texture = TEX_IDLE
	_motes.amount = 12
	_motes.color = CORE_TINT
	state_changed.emit(signal_id, active)
