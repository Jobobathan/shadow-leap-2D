extends Node2D
## 2D arrow projectile for Akari's ranged attacks.

var direction: Vector2 = Vector2.ZERO
var speed: float = 880.0
var damage: int = 13
var max_distance: float = 480.0
var distance_traveled: float = 0.0
var target: Node2D = null
var shooter: Node2D = null
var hit_radius: float = 32.0

func _ready() -> void:
	if direction.length() > 0.01:
		rotation = direction.angle()

func _draw() -> void:
	draw_line(Vector2(-12, 0), Vector2(12, 0), Color(1.0, 0.9, 0.3), 3.0)
	draw_line(Vector2(8, -4), Vector2(12, 0), Color(1.0, 0.9, 0.3), 2.0)
	draw_line(Vector2(8, 4), Vector2(12, 0), Color(1.0, 0.9, 0.3), 2.0)

func _physics_process(delta: float) -> void:
	var move := direction * speed * delta
	global_position += move
	distance_traveled += move.length()

	if target and is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		if dist < hit_radius:
			_hit_target()
			return

	if distance_traveled >= max_distance:
		queue_free()

func _hit_target() -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
		print("[Arrow] Hit %s for %d" % [target.name, damage])
	if target.has_method("apply_hitstop"):
		target.apply_hitstop(0.06)
	if shooter:
		var eng_mgr := shooter.get_node_or_null("../EngagementManager")
		if eng_mgr and eng_mgr.has_method("report_damage"):
			eng_mgr.report_damage(true, damage)
	# Hit flash
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.9, 0.3, 0.9)
	flash.size = Vector2(12, 12)
	flash.position = global_position - Vector2(6, 6)
	flash.z_index = 10
	get_tree().root.get_child(0).add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "size", Vector2(24, 24), 0.12)
	tween.parallel().tween_property(flash, "position", global_position - Vector2(12, 12), 0.12)
	tween.parallel().tween_property(flash, "color:a", 0.0, 0.12)
	tween.tween_callback(flash.queue_free)
	queue_free()
