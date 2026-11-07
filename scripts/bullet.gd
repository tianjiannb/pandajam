extends Node2D
class_name TurretBullet

## 机关枪子弹：沿固定方向逐物理帧做射线推进（避免高速穿透薄墙）。
## 命中第一个"子弹目标"（玩家或副本）则让该个体生效，且只击杀这一个个体后销毁；
## 命中墙体或超出射程也销毁。

const HIT_MASK := 7

var _direction := Vector2.RIGHT
var _speed := 720.0
var _left := 900.0
var _exclude: Array[RID] = []


func setup(direction: Vector2, speed: float, max_distance: float, shooter_rid: RID, shot_id: int = 0) -> void:
	_direction = direction.normalized()
	_speed = speed
	_left = max_distance
	_exclude.clear()
	if shooter_rid.is_valid():
		_exclude.append(shooter_rid)
	add_to_group("turret_bullets")
	name = "Bullet%d" % shot_id
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	var step := minf(_speed * delta, _left)
	if step <= 0.0:
		queue_free()
		return

	var from := global_position
	var to := from + _direction * step
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, HIT_MASK, _exclude)
	var hit := space.intersect_ray(query)

	if hit.is_empty():
		global_position = to
		_left -= step
		return

	# 命中：先贴到命中点，再结算。
	global_position = hit.get("position")
	_resolve_hit(hit.get("collider"))


func _resolve_hit(collider) -> void:
	if collider is Node and collider.is_in_group("bullet_target") and collider.has_method("on_bullet_hit"):
		collider.on_bullet_hit()
	queue_free()
