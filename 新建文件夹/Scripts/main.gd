extends Node2D
## 核心循环原型：一扇需要按钮保持按下才能打开的门 + 一个影子。
##
## 第 1 轮（录像）：走到按钮上站住，按 Space 结束录像。
## 第 2 轮（回放）：影子重放第 1 轮的路线并停在终点替你踩按钮，你穿过门走到出口。
## 碰到影子 -> 重来本轮（影子从头重放）。

enum State { RECORDING, REPLAY, CLEARED }

const SPEED := 220.0
const PLAYER_RADIUS := 12.0
const START := Vector2(150, 360)
const BUTTON_POS := Vector2(400, 180)
const BUTTON_RADIUS := 22.0
const CONTACT_DISTANCE := 22.0
## 回放轮开始时影子与玩家同在出生点；这段时间内不判定接触。
const GRACE_TICKS := 30
const DOOR_RECT := Rect2(790, 300, 20, 120)
const EXIT_RECT := Rect2(1000, 300, 120, 120)

## 测试用：为 false 时不读键盘，由外部调用 step()。
var auto_input := true

var state: State = State.RECORDING
var round_no := 1
var tick := 0
var fail_count := 0
var door_open := false
var button_pressed := false
var recording := PackedVector2Array()
var ghost_path := PackedVector2Array()
var ghost_pos := Vector2.ZERO
var player: CharacterBody2D

var _walls: Array[Rect2] = [
	Rect2(0, 0, 1280, 20),
	Rect2(0, 700, 1280, 20),
	Rect2(0, 0, 20, 720),
	Rect2(1260, 0, 20, 720),
	Rect2(790, 20, 20, 280),
	Rect2(790, 420, 20, 280),
]
var _door_shape: CollisionShape2D
var _hud: Label
var _message := ""


func _ready() -> void:
	for rect in _walls:
		add_child(_make_rect_body(rect))

	var door_body := _make_rect_body(DOOR_RECT)
	_door_shape = door_body.get_child(0) as CollisionShape2D
	add_child(door_body)

	player = CharacterBody2D.new()
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var player_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PLAYER_RADIUS
	player_shape.shape = circle
	player.add_child(player_shape)
	add_child(player)

	var layer := CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(32, 28)
	layer.add_child(_hud)
	add_child(layer)

	_start_round(1)


func _make_rect_body(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	body.add_child(shape)
	return body


func _physics_process(_delta: float) -> void:
	if auto_input:
		step(_read_dir())


func _process(_delta: float) -> void:
	_update_hud()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_SPACE:
			finish_recording()
		KEY_R:
			restart_round()
		KEY_Q:
			rerecord()


func _read_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		d.y += 1.0
	return d.normalized()


## 一个固定物理 tick 的全部游戏逻辑。
func step(dir: Vector2) -> void:
	if state == State.CLEARED:
		return

	player.velocity = dir * SPEED
	player.move_and_slide()

	if state == State.RECORDING:
		recording.append(player.position)
	else:
		ghost_pos = ghost_path[mini(tick, ghost_path.size() - 1)]

	button_pressed = player.position.distance_to(BUTTON_POS) < BUTTON_RADIUS
	if state == State.REPLAY and ghost_pos.distance_to(BUTTON_POS) < BUTTON_RADIUS:
		button_pressed = true
	_set_door(button_pressed)

	if state == State.REPLAY:
		if tick >= GRACE_TICKS and player.position.distance_to(ghost_pos) < CONTACT_DISTANCE:
			fail_count += 1
			_start_round(round_no, "碰到影子，重来本轮")
			return
		if EXIT_RECT.has_point(player.position):
			state = State.CLEARED
			_message = "通关！按 R 从头再来"
			return

	tick += 1


## 结束第 1 轮录像，进入第 2 轮回放。
func finish_recording() -> void:
	if state != State.RECORDING or recording.is_empty():
		return
	ghost_path = recording.duplicate()
	round_no += 1
	state = State.REPLAY
	_start_round(round_no, "影子开始重放你的上一轮")


## 重来当前轮；通关后回到第 1 轮。
func restart_round() -> void:
	if state == State.CLEARED:
		rerecord()
	else:
		_start_round(round_no, "重来本轮")


## 丢弃影子，回到第 1 轮重新录像。
func rerecord() -> void:
	ghost_path = PackedVector2Array()
	round_no = 1
	state = State.RECORDING
	_start_round(1, "重新录像")


func _start_round(n: int, msg: String = "") -> void:
	round_no = n
	tick = 0
	recording = PackedVector2Array()
	player.position = START
	player.velocity = Vector2.ZERO
	ghost_pos = ghost_path[0] if state == State.REPLAY and not ghost_path.is_empty() else START
	button_pressed = false
	_set_door(false)
	_message = msg


func _set_door(open: bool) -> void:
	if open == door_open and _door_shape.disabled == open:
		return
	door_open = open
	_door_shape.set_deferred("disabled", open)


func _update_hud() -> void:
	var phase := "录像（站到按钮上，按 Space 结束）" if state == State.RECORDING else "回放（让影子替你开门）"
	if state == State.CLEARED:
		phase = "已通关"
	_hud.text = "第 %d 轮 · %s\n失败 %d 次\nWASD/方向键移动   Space 结束录像   R 重来本轮   Q 重新录像\n%s" % [
		round_no, phase, fail_count, _message
	]


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.09, 0.1, 0.13))
	draw_rect(EXIT_RECT, Color(0.2, 0.55, 0.3, 0.6))
	for rect in _walls:
		draw_rect(rect, Color(0.4, 0.43, 0.5))

	var button_color := Color(1.0, 0.8, 0.2) if button_pressed else Color(0.55, 0.45, 0.15)
	draw_circle(BUTTON_POS, BUTTON_RADIUS, button_color)

	if door_open:
		draw_rect(DOOR_RECT, Color(0.9, 0.7, 0.2), false, 2.0)
	else:
		draw_rect(DOOR_RECT, Color(0.9, 0.7, 0.2))

	if state != State.RECORDING:
		draw_circle(ghost_pos, PLAYER_RADIUS, Color(0.4, 0.85, 1.0, 0.55))
	draw_circle(player.position, PLAYER_RADIUS, Color(1.0, 1.0, 1.0))
