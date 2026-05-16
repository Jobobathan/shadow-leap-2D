extends Node2D
## Tactical cursor for macro mode (2D).
## WASD moves. Frozen during enemy phase, engagement, and ability aiming.

@export var speed: float = 320.0
@export var arena_bounds: float = 1360.0

var turn_manager: Node = null
var engagement_manager: Node = null
var aiming_mode: bool = false

func _ready() -> void:
	await get_tree().process_frame
	turn_manager = get_node_or_null("../TurnManager")
	engagement_manager = get_node_or_null("../EngagementManager")

func _process(delta: float) -> void:
	if turn_manager and not turn_manager.is_player_phase():
		return
	if engagement_manager and engagement_manager.has_active_engagement():
		return
	if aiming_mode:
		return

	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	global_position.x += input_dir.x * speed * delta
	global_position.y += input_dir.y * speed * delta
	global_position.x = clampf(global_position.x, -arena_bounds, arena_bounds)
	global_position.y = clampf(global_position.y, -arena_bounds, arena_bounds)
	queue_redraw()

func _draw() -> void:
	var c := Color(1.0, 1.0, 0.0, 0.6)
	draw_line(Vector2(-10, 0), Vector2(10, 0), c, 2.0)
	draw_line(Vector2(0, -10), Vector2(0, 10), c, 2.0)
	draw_arc(Vector2.ZERO, 14, 0, TAU, 24, c, 1.5)
