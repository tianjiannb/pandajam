extends Node2D

## 跳跃刀光：一次性特效，播放完自动销毁。
## 由 player.gd 在起跳瞬间实例化，旋转到跳跃方向。

@export var duration := 0.3
## 位移白线沿跳跃方向旋转，并在播放中轻微扫动。
@export var start_angle_offset := -0.10
@export var end_angle_offset := 0.10

@onready var _visual: Sprite2D = $Visual
@onready var _sparks: GPUParticles2D = $Sparks

var _material: ShaderMaterial


func _ready() -> void:
	_material = _visual.material as ShaderMaterial
	if _material == null:
		queue_free()
		return
	_material.set_shader_parameter("progress", 0.0)
	_sparks.restart()
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, duration)
	tween.parallel().tween_method(_set_swing, 0.0, 1.0, duration)
	tween.tween_callback(_finish)


## 等火花粒子播完再销毁整个特效。
func _finish() -> void:
	await get_tree().create_timer(0.18).timeout
	queue_free()


func _set_progress(value: float) -> void:
	_material.set_shader_parameter("progress", value)


func _set_swing(value: float) -> void:
	_visual.rotation = lerpf(start_angle_offset, end_angle_offset, value)
