extends Node2D
class_name GunBullet

const HIT_MASK := 6 # 过去的你(2) + 世界/墙体(4)
var _direction := Vector2.RIGHT
var _speed := 900.0
var _left := 900.0
var _exclude: Array[RID] = []

func setup(direction: Vector2, speed: float, max_distance: float, shooter_rid: RID, shot_id: int = 0) -> void:
	_direction = direction.normalized()
	_speed = speed
	_left = max_distance
	_exclude.clear()
	if shooter_rid.is_valid():
		_exclude.append(shooter_rid)
	add_to_group("gun_bullets")
	name = "GunBullet%d" % shot_id
	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	var step := minf(_speed * delta, _left)
	if step <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + _direction * step
	var query := PhysicsRayQueryParameters2D.create(from, to, HIT_MASK, _exclude)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_left -= step
		return
	global_position = hit.get("position")
	var collider = hit.get("collider")
	if collider is Node and collider.is_in_group("ghosts") and collider.has_method("on_bullet_hit"):
		collider.on_bullet_hit()
	queue_free()
