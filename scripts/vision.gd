extends Node2D
class_name VisionSystem

## 战争迷雾第一版：固定半径视野 + 墙体射线截断生成可见多边形。
## 规则：
##  - 当前视野：射线从玩家出发，被 wall 层（碰撞层 4）截断，连成可见多边形，正常亮度显示。
##  - 已探索记忆：当前视野覆盖过的区域持久变灰（半透明遮罩），不随玩家移动恢复为黑色。
##  - 未探索区域：保持全黑。
## 实现方式：
##  - CurrentVision 多边形每帧重算（世界坐标）。
##  - ExploredMemory 用一张持久化的 Image/ImageTexture 作为灰度遮罩，
##    每帧把当前可见多边形“烧录”进去（只增不减）。
##  - FogOverlay 是一个跟随玩家、挂在世界空间（不在 CanvasLayer 下）的 ColorRect，
##    材质 shader 根据世界坐标实时判断三态并着色：
##    当前可见 -> 完全透明；已探索但不可见 -> 半透明灰；未探索 -> 全黑。

## 总开关：关闭时不计算视野、隐藏雾遮罩，场景完全正常显示（不影响碰撞/玩法逻辑）。
@export var enabled := true:
	set(value):
		enabled = value
		_apply_enabled()
@export var target_path: NodePath
@export var ray_count := 96
@export var vision_radius := 420.0
## 场景实体碰撞层（wall/door/obstacle/turret/breakable 等），用于截断视线。
@export_flags_2d_physics var occluder_mask := 4

## 已探索记忆贴图的世界覆盖范围（以 target 初始位置为中心的正方形，像素）。
@export var memory_world_size := 4096.0
## 记忆贴图分辨率（越大越精细，但更新开销更大）。
@export var memory_texture_size := 512

var _memory_image: Image
var _memory_texture: ImageTexture
var _memory_origin := Vector2.ZERO

## 世界空间雾遮罩（跟随玩家移动，始终覆盖摄像机可见范围）。
@onready var _fog_rect: ColorRect = $"../FogOverlay"

var target: Node2D


func _ready() -> void:
	if not target_path.is_empty():
		target = get_node(target_path) as Node2D
	if target == null:
		push_warning("VisionSystem: target 未设置，视野系统不会生效。")
		return
	_memory_origin = target.global_position - Vector2(memory_world_size, memory_world_size) * 0.5
	_memory_image = Image.create(memory_texture_size, memory_texture_size, false, Image.FORMAT_R8)
	_memory_image.fill(Color(0, 0, 0, 0))
	_memory_texture = ImageTexture.create_from_image(_memory_image)
	if _fog_rect != null:
		_fog_rect.material.set_shader_parameter("memory_tex", _memory_texture)
		_fog_rect.material.set_shader_parameter("memory_origin", _memory_origin)
		_fog_rect.material.set_shader_parameter("memory_world_size", memory_world_size)
	_apply_enabled()


## 开关实际生效：只控制雾遮罩是否显示/计算，不改变任何碰撞或玩法逻辑。
## is_node_ready 判断避免 _ready 之前（@onready 变量还未赋值时）就被 setter 调用。
func _apply_enabled() -> void:
	if is_node_ready() and _fog_rect != null:
		_fog_rect.visible = enabled


func _physics_process(_delta: float) -> void:
	if not enabled or target == null or _memory_image == null:
		return
	# 雾遮罩跟随玩家，始终铺满摄像机视口（配合足够大的固定尺寸）。
	_fog_rect.global_position = target.global_position - _fog_rect.size * 0.5
	var polygon := _compute_vision_polygon()
	_burn_into_memory(polygon)
	_memory_texture.update(_memory_image)
	if _fog_rect != null:
		_fog_rect.material.set_shader_parameter("vision_center", target.global_position)
		_fog_rect.material.set_shader_parameter("vision_radius", vision_radius)
		_fog_rect.material.set_shader_parameter("vision_polygon", polygon)
		_fog_rect.material.set_shader_parameter("vision_point_count", polygon.size())


## 以 target 为中心发射 ray_count 条射线，遇到 occluder_mask 层即截断，
## 没有命中则取 vision_radius 处的点；返回按角度排序好的可见多边形（世界坐标）。
func _compute_vision_polygon() -> PackedVector2Array:
	var space := target.get_world_2d().direct_space_state
	var origin := target.global_position
	var points := PackedVector2Array()
	points.resize(ray_count)
	for i in range(ray_count):
		var angle := TAU * float(i) / float(ray_count)
		var dir := Vector2(cos(angle), sin(angle))
		var to := origin + dir * vision_radius
		var query := PhysicsRayQueryParameters2D.create(origin, to, occluder_mask)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			points[i] = to
		else:
			points[i] = hit.get("position")
	return points


## 把当前可见多边形“烧录”进已探索记忆贴图（只变亮不变暗）。
func _burn_into_memory(world_polygon: PackedVector2Array) -> void:
	if world_polygon.size() < 3:
		return
	var local_polygon := PackedVector2Array()
	local_polygon.resize(world_polygon.size())
	var scale_factor := float(memory_texture_size) / memory_world_size
	for i in range(world_polygon.size()):
		var local_pos := (world_polygon[i] - _memory_origin) * scale_factor
		local_polygon[i] = local_pos

	# 用多边形包围盒限定扫描范围，逐像素做点在多边形内测试（分辨率不高，第一版足够快）。
	var min_x := memory_texture_size
	var max_x := 0
	var min_y := memory_texture_size
	var max_y := 0
	for p in local_polygon:
		min_x = mini(min_x, int(floor(p.x)))
		max_x = maxi(max_x, int(ceil(p.x)))
		min_y = mini(min_y, int(floor(p.y)))
		max_y = maxi(max_y, int(ceil(p.y)))
	min_x = clampi(min_x, 0, memory_texture_size - 1)
	max_x = clampi(max_x, 0, memory_texture_size - 1)
	min_y = clampi(min_y, 0, memory_texture_size - 1)
	max_y = clampi(max_y, 0, memory_texture_size - 1)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _memory_image.get_pixel(x, y).r >= 1.0:
				continue
			if Geometry2D.is_point_in_polygon(Vector2(x, y), local_polygon):
				_memory_image.set_pixel(x, y, Color(1, 0, 0, 1))
