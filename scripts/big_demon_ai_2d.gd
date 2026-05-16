class_name BigDemon2D
extends CharacterBody2D
## 2D big demon boss — charges, casts laser telegraph, melee swipes.
## Enemy phase: charges (gray→green). Player phase: casts (green→red).

enum State { IDLE, CHARGING, CHARGED, CASTING, CAST_COMPLETE, APPROACHING, MELEE_TELEGRAPH, MELEE_SWIPE, MELEE_RECOVERY }

@export var blast_radius: float = 600.0
@export var charge_time: float = 3.0
@export var cast_time: float = 8.0
@export var telegraph_width: float = 140.0
@export var telegraph_length: float = 600.0
@export var blast_damage: int = 30
@export var engagement_radius: float = 100.0
@export var approach_speed: float = 80.0
@export var swipe_damage: int = 25
@export var swipe_range: float = 140.0
@export var melee_telegraph_time: float = 0.6
@export var melee_recovery_time: float = 1.0
@export var melee_chance: float = 0.45

var state: State = State.IDLE
var state_timer: float = 0.0
var is_engaged: bool = false
var charge_progress: float = 0.0
var cast_progress: float = 0.0
var turn_manager: Node = null
var has_reported_done: bool = false
var melee_target: Node2D = null

## Telegraph direction (unit vector)
var telegraph_direction: Vector2 = Vector2(0, 1)

## HP
var boss_max_hp: int = 200
var boss_current_hp: int = 200
var hitstop_timer: float = 0.0

## Sprite
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
var facing_dir: int = 2
var damage_tween: Tween = null
var base_sprite_scale: Vector2 = Vector2(3.5, 3.5)


func _ready() -> void:
	boss_current_hp = boss_max_hp
	add_to_group("enemy")
	add_to_group("boss_enemy")
	if sprite:
		base_sprite_scale = sprite.scale
	_play_anim("idle")
	await get_tree().process_frame
	turn_manager = get_node_or_null("../TurnManager")
	if turn_manager:
		turn_manager.player_phase_started.connect(_on_player_phase)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Blast radius circle
	draw_arc(Vector2.ZERO, blast_radius, 0, TAU, 48, Color(0.6, 0.2, 0.8, 0.12), 2.0)
	# Engagement zone
	draw_arc(Vector2.ZERO, engagement_radius, 0, TAU, 32, Color(0.0, 0.8, 0.8, 0.2), 2.0)
	# Laser telegraph (when charging/casting)
	if state in [State.CHARGING, State.CHARGED, State.CASTING]:
		_draw_telegraph()
	# HP bar
	if boss_current_hp < boss_max_hp:
		var bar_w := 70.0
		var bar_h := 8.0
		var bar_y := -100.0
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.8))
		var ratio := float(boss_current_hp) / float(boss_max_hp)
		var fill_w := bar_w * ratio
		var color: Color
		if ratio > 0.6:
			color = Color(0.8, 0.1, 0.5)
		elif ratio > 0.3:
			color = Color(0.9, 0.4, 0.1)
		else:
			color = Color(0.9, 0.1, 0.1)
		draw_rect(Rect2(-bar_w / 2.0, bar_y, fill_w, bar_h), color)


func _draw_telegraph() -> void:
	var telegraph_color: Color
	var alpha: float
	match state:
		State.CHARGING:
			telegraph_color = Color(0.3, 0.3, 0.3).lerp(Color(0.1, 0.85, 0.1), charge_progress)
			alpha = lerpf(0.1, 0.3, charge_progress)
		State.CHARGED:
			telegraph_color = Color(0.1, 0.85, 0.1)
			alpha = 0.3
		State.CASTING:
			telegraph_color = Color(0.1, 0.85, 0.1).lerp(Color(0.95, 0.1, 0.05), cast_progress)
			alpha = lerpf(0.3, 0.5, cast_progress)
		_:
			return

	var dir := telegraph_direction.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var half_w := telegraph_width / 2.0
	var points := PackedVector2Array([
		perp * half_w,
		perp * half_w + dir * telegraph_length,
		-perp * half_w + dir * telegraph_length,
		-perp * half_w,
	])
	draw_colored_polygon(points, Color(telegraph_color.r, telegraph_color.g, telegraph_color.b, alpha))


## ─── Turn System ──────────────────────────────────────────

func _on_player_phase() -> void:
	if state == State.CHARGED:
		_enter_casting()

func start_turn() -> void:
	has_reported_done = false
	if not _any_party_member_in_range():
		_report_done()
		return

	_face_closest_party_member()

	var closest := _find_closest_party_member()
	var dist := global_position.distance_to(closest.global_position) if closest else 999.0
	var dist_bonus := clampf((320.0 - dist) / 320.0 * 0.3, 0.0, 0.3)
	var roll := randf()
	var effective_melee_chance := clampf(melee_chance + dist_bonus, 0.0, 0.85)

	if roll < effective_melee_chance:
		_enter_approaching()
	else:
		_enter_charging()


## ─── Physics ──────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if hitstop_timer > 0.0:
		hitstop_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if state in [State.IDLE, State.CHARGED, State.CAST_COMPLETE]:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	state_timer -= delta

	match state:
		State.CHARGING:
			_process_charging()
		State.CASTING:
			_process_casting()
		State.APPROACHING:
			_process_approaching(delta)
		State.MELEE_TELEGRAPH:
			_process_melee_telegraph()
		State.MELEE_SWIPE:
			_process_melee_swipe()
		State.MELEE_RECOVERY:
			_process_melee_recovery()

	move_and_slide()


func _process_charging() -> void:
	charge_progress = clampf(1.0 - (state_timer / charge_time), 0.0, 1.0)
	if sprite:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		sprite.modulate = Color(1.0, 0.5 + 0.3 * pulse, 0.2, 1.0)
	if state_timer <= 0.0:
		state = State.CHARGED
		if sprite:
			sprite.modulate = Color.WHITE  # Restore native sprite color
		print("[BigDemon] Fully charged — waiting for player phase")
		_report_done()


func _process_casting() -> void:
	cast_progress = clampf(1.0 - (state_timer / cast_time), 0.0, 1.0)
	if sprite:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
		var lerped := Color(0.1, 0.85, 0.1).lerp(Color(0.95, 0.1, 0.05), cast_progress)
		sprite.modulate = Color(lerped.r + 0.2 * pulse, lerped.g, lerped.b, 1.0)
	if state_timer <= 0.0:
		_resolve_blast()
		state = State.CAST_COMPLETE
		if sprite:
			sprite.modulate = Color.WHITE
		_play_anim("idle")


## ─── Melee States ─────────────────────────────────────────

func _get_nav_direction_to(target_pos: Vector2) -> Vector2:
	if nav_agent:
		nav_agent.target_position = target_pos
		if not nav_agent.is_navigation_finished():
			var next_pos := nav_agent.get_next_path_position()
			return (next_pos - global_position).normalized()
	return (target_pos - global_position).normalized()


func _enter_approaching() -> void:
	state = State.APPROACHING
	state_timer = 0.0
	melee_target = _find_closest_party_member()
	_play_anim("walk")

func _process_approaching(delta: float) -> void:
	if not melee_target:
		state = State.IDLE
		_report_done()
		return
	var direction := melee_target.global_position - global_position
	var dist := direction.length()
	if dist <= swipe_range:
		velocity = Vector2.ZERO
		_enter_melee_telegraph()
		return
	var move_dir := _get_nav_direction_to(melee_target.global_position)
	velocity = move_dir * approach_speed
	_update_facing(move_dir)
	state_timer -= delta
	if state_timer < -5.0:
		state = State.IDLE
		velocity = Vector2.ZERO
		_report_done()

func _enter_melee_telegraph() -> void:
	state = State.MELEE_TELEGRAPH
	state_timer = melee_telegraph_time
	_play_anim("idle")

func _process_melee_telegraph() -> void:
	velocity = Vector2.ZERO
	if sprite:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		sprite.modulate = Color(1.0, 0.4 + 0.3 * pulse, 0.15, 1.0)
	if state_timer <= 0.0:
		if sprite:
			sprite.modulate = Color.WHITE
		_enter_melee_swipe()

func _enter_melee_swipe() -> void:
	state = State.MELEE_SWIPE
	state_timer = 0.4
	_play_anim("slash")
	_do_melee_damage()

func _do_melee_damage() -> void:
	var members := get_tree().get_nodes_in_group("party_member")
	for member in members:
		var m: Node2D = member as Node2D
		var dist := global_position.distance_to(m.global_position)
		if dist <= swipe_range + 40.0:
			var to_member := (m.global_position - global_position).normalized()
			var forward := telegraph_direction.normalized()
			if to_member.dot(forward) > 0.0:
				if member.has_method("take_arpg_damage"):
					member.take_arpg_damage(swipe_damage, self)
				elif member.has_method("take_damage"):
					member.take_damage(swipe_damage)
				print("[BigDemon] Swipe HIT %s for %d!" % [member.name, swipe_damage])

func _process_melee_swipe() -> void:
	velocity = Vector2.ZERO
	if state_timer <= 0.0:
		_enter_melee_recovery()

func _enter_melee_recovery() -> void:
	state = State.MELEE_RECOVERY
	state_timer = melee_recovery_time
	_play_anim("idle")

func _process_melee_recovery() -> void:
	velocity = Vector2.ZERO
	if state_timer <= 0.0:
		state = State.IDLE
		_report_done()


## ─── State Transitions ────────────────────────────────────

func _enter_charging() -> void:
	state = State.CHARGING
	state_timer = charge_time
	charge_progress = 0.0
	_play_anim("idle")

func _enter_casting() -> void:
	state = State.CASTING
	state_timer = cast_time
	cast_progress = 0.0

func _report_done() -> void:
	if has_reported_done:
		return
	has_reported_done = true
	if turn_manager:
		turn_manager.report_enemy_done(self)

func _face_closest_party_member() -> void:
	var closest := _find_closest_party_member()
	if closest:
		telegraph_direction = (closest.global_position - global_position).normalized()
		_update_facing(telegraph_direction)


## ─── Blast Resolution (2D raycast for cover LOS) ─────────

func _resolve_blast() -> void:
	print("[BigDemon] === BLAST FIRES ===")
	var members := get_tree().get_nodes_in_group("party_member")
	var space_state := get_world_2d().direct_space_state

	var exclude_rids: Array[RID] = []
	exclude_rids.append(get_rid())
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is CollisionObject2D:
			exclude_rids.append((enemy as CollisionObject2D).get_rid())
	for member in members:
		if member is CollisionObject2D:
			exclude_rids.append((member as CollisionObject2D).get_rid())

	for member in members:
		if not is_point_in_telegraph(member.global_position):
			print("[BigDemon]   %s — SAFE (outside telegraph)" % member.name)
			continue
		var query := PhysicsRayQueryParameters2D.create(global_position, member.global_position)
		query.exclude = exclude_rids
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			if member.has_method("take_damage"):
				member.take_damage(blast_damage)
			print("[BigDemon]   %s — HIT! (%d damage)" % [member.name, blast_damage])
		else:
			var blocker: String = result.collider.name if result.collider else "unknown"
			print("[BigDemon]   %s — BLOCKED by %s" % [member.name, blocker])


func is_telegraph_active() -> bool:
	return state in [State.CHARGING, State.CHARGED, State.CASTING]

func is_point_in_telegraph(pos: Vector2) -> bool:
	if not is_telegraph_active():
		return false
	var local := pos - global_position
	var dir := telegraph_direction.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var along := local.dot(dir)
	var across := local.dot(perp)
	return along >= 0.0 and along <= telegraph_length and absf(across) <= telegraph_width / 2.0


## ─── Helpers ──────────────────────────────────────────────

func _find_closest_party_member() -> Node2D:
	var members := get_tree().get_nodes_in_group("party_member")
	var closest: Node2D = null
	var closest_dist: float = INF
	for member in members:
		var dist := global_position.distance_to(member.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = member
	return closest

func _any_party_member_in_range() -> bool:
	for member in get_tree().get_nodes_in_group("party_member"):
		if global_position.distance_to(member.global_position) <= blast_radius:
			return true
	return false


## ─── HP & Damage ──────────────────────────────────────────

func take_damage(amount: int) -> void:
	boss_current_hp = clampi(boss_current_hp - amount, 0, boss_max_hp)
	print("[BigDemon] took %d damage -> %d/%d HP" % [amount, boss_current_hp, boss_max_hp])
	_flash_damage()

func _flash_damage() -> void:
	if not sprite:
		return
	if damage_tween and damage_tween.is_valid():
		damage_tween.kill()
	damage_tween = create_tween()
	damage_tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3), 0.08)
	damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.35)

func apply_hitstop(duration: float) -> void:
	hitstop_timer = duration

func is_alive() -> bool:
	return boss_current_hp > 0


## ─── Facing & Animation ──────────────────────────────────

func _update_facing(dir: Vector2) -> void:
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	var new_dir := facing_dir
	if ax > ay * 1.3:
		new_dir = 3 if dir.x > 0 else 1
	elif ay > ax * 1.3:
		new_dir = 2 if dir.y > 0 else 0
	if new_dir != facing_dir:
		facing_dir = new_dir

func _play_anim(anim_name: String) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var full_name: String = anim_name + "_" + _dir_suffix()
	if sprite.sprite_frames.has_animation(full_name):
		if sprite.animation != full_name:
			sprite.play(full_name)
	elif sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)

func _dir_suffix() -> String:
	match facing_dir:
		0: return "up"
		1: return "left"
		2: return "down"
		3: return "right"
	return "down"
