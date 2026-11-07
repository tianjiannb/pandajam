extends Node2D

## 跳跃刀光：一次性特效，播放完自动销毁。
## 由 player.gd 在起跳瞬间实例化，旋转到跳跃方向，并通过 fit_to_distance()
## 把视觉长度对齐到本次跳跃实际位移的像素距离。

@export var duration := 0.3
## 位移白线沿跳跃方向旋转，并在播放中轻微扫动。
@export var start_angle_offset := -0.10
@export var end_angle_offset := 0.10

## 贴图本身 8px 宽；quad_base_size 必须与 slash_quad.png 实际尺寸一致，
## 用来把 "世界像素长度" 换算成 Sprite2D.scale。
const QUAD_BASE_SIZE := 8.0

## 线条粗细（世界像素），与长度无关，始终保持这个视觉宽度。
@export var line_thickness_px := 10.0
## 着色器里线段实际点亮的比例（UV 0..1，留一点边距给柔化）。
const LINE_LENGTH_UV := 0.9

@onready var _visual: Sprite2D = $Visual
@onready var _sparks: GPUParticles2D = $Sparks

var _material: ShaderMaterial
## fit_to_distance() 可能在 add_child()/_ready() 之前调用（调用方希望首帧就是
## 正确长度），此时 _visual 还未就绪，先缓存距离，_ready() 里统一应用。
var _pending_distance_px := -1.0


func _ready() -> void:
	_material = _visual.material as ShaderMaterial
	if _material == null:
		queue_free()
		return
	_material.set_shader_parameter("progress", 0.0)
	_apply_thickness()
	if _pending_distance_px >= 0.0:
		_apply_distance(_pending_distance_px)
	_sparks.restart()
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, duration)
	tween.parallel().tween_method(_set_swing, 0.0, 1.0, duration)
	tween.tween_callback(_finish)


## 让刀光的可见长度等于本次跳跃的实际位移（像素）。
## 可在 add_child 之前调用；节点尚未 ready 时会缓存到 _ready() 再应用。
func fit_to_distance(distance_px: float) -> void:
	if _visual == null:
		_pending_distance_px = distance_px
		return
	_apply_distance(distance_px)


func _apply_distance(distance_px: float) -> void:
	var target_width_px: float = max(distance_px / LINE_LENGTH_UV, 1.0)
	_visual.scale.x = target_width_px / QUAD_BASE_SIZE


func _apply_thickness() -> void:
	_visual.scale.y = line_thickness_px / QUAD_BASE_SIZE


## 等火花粒子播完再销毁整个特效。
func _finish() -> void:
	await get_tree().create_timer(0.18).timeout
	queue_free()


func _set_progress(value: float) -> void:
	_material.set_shader_parameter("progress", value)


func _set_swing(value: float) -> void:
	_visual.rotation = lerpf(start_angle_offset, end_angle_offset, value)
