extends Camera2D
## 2D smooth-follow camera with engagement zoom and screen shake.

@export var smooth_speed: float = 5.0
@export var macro_zoom: Vector2 = Vector2(1.0, 1.0)
@export var micro_zoom: Vector2 = Vector2(1.8, 1.8)
@export var zoom_in_time: float = 0.5
@export var zoom_out_time: float = 0.4

var cursor_target: Node2D = null
var turn_manager: Node = null
var is_zoomed_in: bool = false
var is_zooming: bool = false
var active_tween: Tween = null
var shake_tween: Tween = null
var shake_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	make_current()
	await get_tree().process_frame
	cursor_target = get_node_or_null("../TacticalCursor")
	turn_manager = get_node_or_null("../TurnManager")
	zoom = macro_zoom
	if cursor_target:
		global_position = cursor_target.global_position

func _physics_process(delta: float) -> void:
	if is_zoomed_in or is_zooming:
		return

	var follow_target: Node2D = null
	if turn_manager and not turn_manager.is_player_phase() and turn_manager.camera_focus_target:
		follow_target = turn_manager.camera_focus_target
	elif cursor_target:
		follow_target = cursor_target

	if follow_target:
		var target_pos: Vector2 = follow_target.global_position + shake_offset
		global_position = global_position.lerp(target_pos, smooth_speed * delta)

func zoom_to_engagement(center: Vector2) -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	is_zooming = true
	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.set_trans(Tween.TRANS_CUBIC)
	active_tween.set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(self, "global_position", center, zoom_in_time)
	active_tween.tween_property(self, "zoom", micro_zoom, zoom_in_time)
	await active_tween.finished
	is_zooming = false
	is_zoomed_in = true
	print("[Camera] Zoomed IN to engagement")

func zoom_to_macro(return_center: Vector2) -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	is_zooming = true
	is_zoomed_in = false
	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.set_trans(Tween.TRANS_CUBIC)
	active_tween.set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(self, "global_position", return_center, zoom_out_time)
	active_tween.tween_property(self, "zoom", macro_zoom, zoom_out_time)
	await active_tween.finished
	is_zooming = false
	print("[Camera] Zoomed OUT to macro")

func screen_shake(intensity: float, duration: float) -> void:
	var px_intensity := intensity * 40.0
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	var rand_x := randf_range(-px_intensity, px_intensity)
	var rand_y := randf_range(-px_intensity, px_intensity)
	shake_offset = Vector2(rand_x, rand_y)
	if is_zoomed_in:
		global_position += shake_offset
	shake_tween = create_tween()
	shake_tween.set_trans(Tween.TRANS_SINE)
	shake_tween.set_ease(Tween.EASE_OUT)
	shake_tween.tween_property(self, "shake_offset",
		Vector2(-rand_x * 0.6, -rand_y * 0.6), duration * 0.25)
	shake_tween.tween_property(self, "shake_offset",
		Vector2(rand_x * 0.3, rand_y * 0.3), duration * 0.25)
	shake_tween.tween_property(self, "shake_offset",
		Vector2.ZERO, duration * 0.5)
