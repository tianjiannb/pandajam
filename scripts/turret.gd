extends StaticBody2D
class_name MachineGunTurret

## 机关枪（白模）：激光检测器沿自身 +X 方向射出（长度可调）。
## 检测到玩家或玩家的副本 -> 朝该方向打一发子弹；发射后进入冷却（默认 1s，可调），冷却结束重新检测。
## 子弹命中第一个玩家/副本个体：命中玩家则按"倒计时结束"流程归位（本轮录制变成副本），
## 命中副本则该副本消失。墙体（不属于玩家/副本）会挡住激光与子弹。

## 每次开火时广播发射方向，供测试与上层逻辑监听。
signal fired(direction: Vector2)

## 检测层：1 = 玩家，2 = 副本，4 = 场景实体（会挡住激光）。
const DETECT_MASK := 7

## 激光检测长度（像素）。
@export var laser_length := 240.0
## 开火冷却（秒）。
@export var fire_cooldown := 1.0
## 子弹速度（像素/秒）。
@export var bullet_speed := 720.0
## 子弹最大飞行距离（像素），超出即销毁。
@export var bullet_max_distance := 900.0
## 子弹场景。
@export var bullet_scene: PackedScene

@export var idle_color := Color(1.0, 0.35, 0.35, 0.35)
@export var alert_color := Color(1.0, 0.9, 0.3, 0.95)
@export var cooldown_color := Color(1.0, 0.35, 0.35, 0.12)

var _cooldown_left := 0.0
var _bullet_count := 0

@onready var _laser: Line2D = $Laser


func _ready() -> void:
	add_to_group("turrets")
	_update_laser_shape()
	_laser.default_color = idle_color


## 是否正在冷却（冷却期间不检测、不开火）。
func is_cooling() -> bool:
	return _cooldown_left > 0.0


func _update_laser_shape() -> void:
	_laser.points = PackedVector2Array([Vector2.ZERO, Vector2(laser_length, 0.0)])


func _physics_process(delta: float) -> void:
	# 允许运行时改 laser_length（编辑器里调也能立刻看到）。
	_update_laser_shape()

	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
		_laser.default_color = cooldown_color
		return

	if _detect_target() != null:
		_laser.default_color = alert_color
		_fire()
	else:
		_laser.default_color = idle_color


## 激光朝向：沿节点的本地 +X 轴，随节点旋转。
func _direction() -> Vector2:
	return global_transform.x.normalized()


## 沿激光做一次射线检测，返回命中的玩家/副本；被墙体挡住或没有目标则返回 null。
func _detect_target() -> Node2D:
	var space := get_world_2d().direct_space_state
	var from := global_position
	var to := from + _direction() * laser_length
	var query := PhysicsRayQueryParameters2D.create(from, to, DETECT_MASK, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider = hit.get("collider")
	if collider is Node2D and collider.is_in_group("bullet_target"):
		return collider
	return null


func _fire() -> void:
	_cooldown_left = fire_cooldown
	_bullet_count += 1
	var dir := _direction()
	fired.emit(dir)

	if bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position + dir * 22.0
	bullet.setup(dir, bullet_speed, bullet_max_distance, get_rid(), _bullet_count)
