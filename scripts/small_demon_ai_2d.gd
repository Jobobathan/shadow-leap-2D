class_name SmallDemon2D
extends CharacterBody2D
## 2D small demon — three zone system + ARPG combo AI.
## Engagement (cyan, 100px) — zoom-in trigger
## Aggro (orange, 240px) — reactive chase, player phase only
## Movement (green, 600px) — D&D budget, enemy phase only

@export var chase_speed: float = 100.0
@export var max_move_distance: float = 600.0
@export var aggro_radius: float = 240.0
@export var engagement_radius: float = 100.0
@export var stop_distance: float = 40.0
@export var max_hp: int = 150
@export var arpg_approach_speed: float = 120.0
@export var arpg_attack_damage: int = 10
@export var arpg_attack_range: float = 80.0

## Turn state
var is_my_turn: bool = false
var is_engaged: bool = false
var engagement_target: Node2D = null
var start_position: Vector2 = Vector2.ZERO
var turn_manager: Node = null

## ARPG AI combat state — combo pattern system
enum ArpgAI { APPROACH, CIRCLING, COMBO_TELEGRAPH, COMBO_SWING, COMBO_RECOVERY, STAGGERED }
var arpg_ai_state: ArpgAI = ArpgAI.APPROACH
var arpg_ai_timer: float = 0.0

var attack_patterns: Array = [
	[{"telegraph": 0.3, "swing": 0.15, "recovery": 0.4, "damage": 8, "parryable": false, "lunge": 40.0}],
	[{"telegraph": 0.55, "swing": 0.2, "recovery": 0.8, "damage": 18, "parryable": true, "lunge": 60.0}],
	[
		{"telegraph": 0.25, "swing": 0.12, "recovery": 0.18, "damage": 7, "parryable": false, "lunge": 32.0},
		{"telegraph": 0.2, "swing": 0.12, "recovery": 0.45, "damage": 7, "parryable": false, "lunge": 20.0},
	],
	[
		{"telegraph": 0.25, "swing": 0.15, "recovery": 0.2, "damage": 7, "parryable": false, "lunge": 32.0},
		{"telegraph": 0.4, "swing": 0.2, "recovery": 0.7, "damage": 18, "parryable": true, "lunge": 60.0},
	],
	[
		{"telegraph": 0.22, "swing": 0.12, "recovery": 0.15, "damage": 6, "parryable": false, "lunge": 24.0},
		{"telegraph": 0.18, "swing": 0.12, "recovery": 0.15, "damage": 6, "parryable": false, "lunge": 20.0},
		{"telegraph": 0.45, "swing": 0.2, "recovery": 1.0, "damage": 22, "parryable": true, "lunge": 80.0},
	],
]
var current_pattern: Array = []
var current_attack_step: int = 0
var current_attack_data: Dictionary = {}
var circle_timer: float = 0.0
var circle_direction: float = 1.0
var stagger_timer: float = 0.0
var stagger_knockback_dir: Vector2 = Vector2.ZERO

## Retreat state
var is_retreating: bool = false
var retreat_target: Vector2 = Vector2.ZERO

## Reactive aggro
var aggro_target: Node2D = null
var is_aggro: bool = false
var members_inside_at_phase_start: Array = []

## HP & death
var current_hp: int = 150
var is_dead: bool = false

## Visual
var damage_tween: Tween = null
var hitstop_timer: float = 0.0
var intended_move_dir: Vector2 = Vector2.ZERO

## Sprite
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing_dir: int = 2
var base_sprite_scale: Vector2 = Vector2(2.0, 2.0)


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")
	if sprite:
		base_sprite_scale = sprite.scale
	_play_anim("idle")
	await get_tree().process_frame
	turn_manager = get_node_or_null("../TurnManager")
	if turn_manager:
		turn_manager.player_phase_started.connect(_on_player_phase)
		turn_manager.enemy_phase_started.connect(_on_enemy_phase)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if is_dead:
		return
	# Zone circles
	draw_arc(Vector2.ZERO, max_move_distance, 0, TAU, 48, Color(0.2, 0.85, 0.2, 0.08), 2.0)
	draw_arc(Vector2.ZERO, aggro_radius, 0, TAU, 48, Color(1.0, 0.6, 0.0, 0.12), 2.0)
	draw_arc(Vector2.ZERO, engagement_radius, 0, TAU, 32, Color(0.0, 0.8, 0.8, 0.25), 2.0)
	# HP bar
	if current_hp < max_hp:
		var bar_w := 40.0
		var bar_h := 5.0
		var bar_y := -70.0
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.8))
		var ratio := float(current_hp) / float(max_hp)
		var fill_w := bar_w * ratio
		var color: Color
		if ratio > 0.6:
			color = Color(0.9, 0.15, 0.1)
		elif ratio > 0.3:
			color = Color(0.9, 0.8, 0.1)
		else:
			color = Color(0.7, 0.1, 0.1)
		draw_rect(Rect2(-bar_w / 2.0, bar_y, fill_w, bar_h), color)


## ─── Phase Transitions ────────────────────────────────────

func _on_player_phase() -> void:
	is_aggro = false
	aggro_target = null
	is_my_turn = false
	members_inside_at_phase_start.clear()
	for member in get_tree().get_nodes_in_group("party_member"):
		if global_position.distance_to(member.global_position) <= aggro_radius:
			members_inside_at_phase_start.append(member)

func _on_enemy_phase() -> void:
	is_aggro = false
	aggro_target = null

func start_turn() -> void:
	var nearest := _find_nearest_party_member()
	if nearest:
		is_my_turn = true
		start_position = global_position
	else:
		_end_turn()


## ─── Physics ──────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	if hitstop_timer > 0.0:
		hitstop_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_engaged:
		_process_arpg_engaged()
		return

	if is_retreating:
		_process_retreat()
		return

	if not turn_manager:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if turn_manager.is_player_phase():
		_process_reactive_aggro()
	elif is_my_turn:
		_process_enemy_turn()
	else:
		velocity = Vector2.ZERO
		_play_anim("idle")
		move_and_slide()


## ─── ARPG AI: Combo Pattern System ────────────────────────

func _process_arpg_engaged() -> void:
	if not engagement_target:
		velocity = Vector2.ZERO
		_play_anim("idle")
		move_and_slide()
		return

	var direction := engagement_target.global_position - global_position

	match arpg_ai_state:
		ArpgAI.APPROACH:
			_arpg_approach(direction)
		ArpgAI.CIRCLING:
			_arpg_circle(direction)
		ArpgAI.COMBO_TELEGRAPH:
			_arpg_combo_telegraph()
		ArpgAI.COMBO_SWING:
			_arpg_combo_swing()
		ArpgAI.COMBO_RECOVERY:
			_arpg_combo_recovery()
		ArpgAI.STAGGERED:
			_arpg_staggered()

	move_and_slide()

	# Enforce engagement boundary
	var eng_mgr := get_node_or_null("../EngagementManager")
	if eng_mgr:
		var center: Vector2 = eng_mgr.get("engagement_center")
		var boundary: float = eng_mgr.get("engagement_boundary")
		if center != null and center != Vector2.ZERO and boundary > 0.0:
			var dist := global_position.distance_to(center)
			if dist > boundary:
				var push := (center - global_position).normalized()
				global_position += push * (dist - boundary)


func _arpg_approach(direction: Vector2) -> void:
	if direction.length() <= arpg_attack_range + 20.0:
		arpg_ai_state = ArpgAI.CIRCLING
		circle_timer = randf_range(0.3, 0.8)
		circle_direction = [-1.0, 1.0].pick_random()
		velocity = Vector2.ZERO
		return
	var move_dir := direction.normalized()
	velocity = move_dir * arpg_approach_speed
	intended_move_dir = move_dir
	_update_facing(move_dir)
	_play_anim("walk")


func _arpg_circle(direction: Vector2) -> void:
	circle_timer -= get_physics_process_delta_time()
	var perp := Vector2(-direction.y, direction.x).normalized() * circle_direction
	velocity = perp * arpg_approach_speed * 0.6
	intended_move_dir = perp
	_update_facing(perp)
	_play_anim("walk")

	if direction.length() > arpg_attack_range + 100.0:
		arpg_ai_state = ArpgAI.APPROACH
		return

	if circle_timer <= 0.0:
		_start_combo()


func _start_combo() -> void:
	current_pattern = attack_patterns.pick_random().duplicate(true)
	current_attack_step = 0
	_start_combo_step()


func _start_combo_step() -> void:
	if current_attack_step >= current_pattern.size():
		arpg_ai_state = ArpgAI.APPROACH
		return
	current_attack_data = current_pattern[current_attack_step]
	arpg_ai_state = ArpgAI.COMBO_TELEGRAPH
	arpg_ai_timer = current_attack_data.telegraph
	velocity = Vector2.ZERO
	_play_anim("idle")
	# Visual: GOLD = parryable, RED = dodge only
	if current_attack_data.parryable:
		if sprite:
			sprite.modulate = Color(1.0, 0.85, 0.2, 1.0)
	else:
		if sprite:
			sprite.modulate = Color(1.0, 0.35, 0.2, 1.0)


func _arpg_combo_telegraph() -> void:
	arpg_ai_timer -= get_physics_process_delta_time()
	velocity = Vector2.ZERO
	# Pulsing glow
	if sprite:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		if current_attack_data.parryable:
			sprite.modulate = Color(1.0, 0.7 + 0.3 * pulse, 0.1, 1.0)
		else:
			sprite.modulate = Color(1.0, 0.25 + 0.2 * pulse, 0.15, 1.0)
	if arpg_ai_timer <= 0.0:
		arpg_ai_state = ArpgAI.COMBO_SWING
		arpg_ai_timer = current_attack_data.get("swing", 0.2)
		if sprite:
			sprite.modulate = Color.WHITE
		_play_anim("slash")
		_arpg_do_combo_swing()


func _arpg_do_combo_swing() -> void:
	if not engagement_target:
		return
	var lunge_dir := (engagement_target.global_position - global_position).normalized()
	var lunge_dist: float = current_attack_data.get("lunge", 40.0)
	velocity = lunge_dir * lunge_dist * 8.0
	intended_move_dir = lunge_dir
	_update_facing(lunge_dir)

	var dist := global_position.distance_to(engagement_target.global_position)
	if dist <= arpg_attack_range + lunge_dist:
		var dmg: int = current_attack_data.get("damage", 10)
		var is_parryable: bool = current_attack_data.get("parryable", false)
		if engagement_target.has_method("take_arpg_damage"):
			engagement_target.take_arpg_damage(dmg, self, is_parryable)
		elif engagement_target.has_method("take_damage"):
			engagement_target.take_damage(dmg)


func _arpg_combo_swing() -> void:
	arpg_ai_timer -= get_physics_process_delta_time()
	velocity = velocity.lerp(Vector2.ZERO, 10.0 * get_physics_process_delta_time())
	if arpg_ai_timer <= 0.0:
		arpg_ai_state = ArpgAI.COMBO_RECOVERY
		arpg_ai_timer = current_attack_data.get("recovery", 0.5)
		_play_anim("idle")


func _arpg_combo_recovery() -> void:
	arpg_ai_timer -= get_physics_process_delta_time()
	velocity = Vector2.ZERO
	if arpg_ai_timer <= 0.0:
		current_attack_step += 1
		if current_attack_step < current_pattern.size():
			_start_combo_step()
		else:
			arpg_ai_state = ArpgAI.APPROACH


func _arpg_staggered() -> void:
	var dt := get_physics_process_delta_time()
	stagger_timer -= dt
	if stagger_knockback_dir.length() > 0.1:
		velocity = stagger_knockback_dir * 60.0 * (stagger_timer / 1.5)
	else:
		velocity = Vector2.ZERO
	# Wobble + scale pulse
	if sprite:
		var t := Time.get_ticks_msec()
		var wobble := sin(t * 0.02) * 5.0
		sprite.offset.x = wobble
		var scale_pulse := 1.0 + sin(t * 0.015) * 0.1
		sprite.scale = Vector2(base_sprite_scale.x, base_sprite_scale.y * scale_pulse)
		sprite.modulate = Color(0.6, 0.6, 1.0, 1.0)
	if stagger_timer <= 0.0:
		_end_stagger()


func _end_stagger() -> void:
	if sprite:
		sprite.offset.x = 0.0
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(base_sprite_scale.x, base_sprite_scale.y * 0.92)
		var snap_tween := create_tween()
		snap_tween.tween_property(sprite, "scale", base_sprite_scale, 0.12).set_ease(Tween.EASE_OUT)
	arpg_ai_state = ArpgAI.APPROACH


func get_parried() -> void:
	print("[%s] GOT PARRIED — STAGGERED!" % name)
	arpg_ai_state = ArpgAI.STAGGERED
	stagger_timer = 1.5
	current_pattern = []
	current_attack_step = 0
	velocity = Vector2.ZERO
	if engagement_target:
		stagger_knockback_dir = (global_position - engagement_target.global_position).normalized()
		global_position += stagger_knockback_dir * 60.0
	else:
		stagger_knockback_dir = Vector2.ZERO
	_play_anim("hurt")


## ─── Reactive Aggro (player phase) ───────────────────────

func _process_reactive_aggro() -> void:
	var nearest_in_aggro := _find_nearest_in_aggro()
	if nearest_in_aggro:
		if not is_aggro:
			is_aggro = true
		aggro_target = nearest_in_aggro
		var distance := global_position.distance_to(aggro_target.global_position)
		if distance > stop_distance:
			var direction := aggro_target.global_position - global_position
			var move_dir := direction.normalized()
			velocity = move_dir * chase_speed
			intended_move_dir = move_dir
			_update_facing(move_dir)
			_play_anim("walk")
		else:
			velocity = Vector2.ZERO
			_play_anim("idle")
	else:
		is_aggro = false
		aggro_target = null
		velocity = Vector2.ZERO
		_play_anim("idle")
	move_and_slide()


## ─── Enemy Turn (D&D movement budget) ────────────────────

func _process_enemy_turn() -> void:
	var distance_moved := start_position.distance_to(global_position)
	if distance_moved >= max_move_distance:
		_end_turn()
		return
	var nearest := _find_nearest_party_member()
	if nearest:
		var distance := global_position.distance_to(nearest.global_position)
		if distance > stop_distance:
			var direction := nearest.global_position - global_position
			var move_dir := direction.normalized()
			velocity = move_dir * chase_speed
			intended_move_dir = move_dir
			_update_facing(move_dir)
			_play_anim("walk")
		else:
			_end_turn()
			return
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _end_turn() -> void:
	is_my_turn = false
	velocity = Vector2.ZERO
	_play_anim("idle")
	if turn_manager:
		turn_manager.report_enemy_done(self)


## ─── Retreat ──────────────────────────────────────────────

func retreat_from(threat_pos: Vector2) -> void:
	var away_dir := global_position - threat_pos
	if away_dir.length() < 4.0:
		away_dir = Vector2(1, 0)
	away_dir = away_dir.normalized()
	retreat_target = threat_pos + away_dir * (aggro_radius + 240.0)
	retreat_target.x = clampf(retreat_target.x, -1360.0, 1360.0)
	retreat_target.y = clampf(retreat_target.y, -1360.0, 1360.0)
	is_retreating = true
	is_aggro = false
	aggro_target = null


func _process_retreat() -> void:
	var direction := retreat_target - global_position
	if direction.length() < 20.0:
		is_retreating = false
		velocity = Vector2.ZERO
		_play_anim("idle")
		if is_my_turn:
			_end_turn()
		return
	var move_dir := direction.normalized()
	velocity = move_dir * chase_speed * 1.5
	intended_move_dir = move_dir
	_update_facing(move_dir)
	_play_anim("walk")
	move_and_slide()


## ─── HP, Damage & Death ──────────────────────────────────

func take_damage(amount: int) -> void:
	if is_dead:
		return
	current_hp = clampi(current_hp - amount, 0, max_hp)
	print("[%s] took %d damage -> %d/%d HP" % [name, amount, current_hp, max_hp])
	_flash_damage()
	if current_hp <= 0:
		_die()


func apply_hitstop(duration: float) -> void:
	hitstop_timer = duration


func _flash_damage() -> void:
	if not sprite:
		return
	if damage_tween and damage_tween.is_valid():
		damage_tween.kill()
	damage_tween = create_tween()
	damage_tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3), 0.08)
	damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.35)


func _die() -> void:
	is_dead = true
	is_engaged = false
	var was_my_turn := is_my_turn
	is_my_turn = false
	is_aggro = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	remove_from_group("enemy")
	_play_anim("hurt")
	print("[%s] Defeated" % name)
	if was_my_turn and turn_manager:
		turn_manager.report_enemy_done(self)
	await get_tree().create_timer(0.75).timeout
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)


func is_alive() -> bool:
	return current_hp > 0


## ─── Target Finding ──────────────────────────────────────

func _find_nearest_in_aggro() -> Node2D:
	var members := get_tree().get_nodes_in_group("party_member")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for member in members:
		if member in members_inside_at_phase_start:
			continue
		var dist := global_position.distance_to(member.global_position)
		if dist <= aggro_radius and dist < nearest_dist:
			nearest_dist = dist
			nearest = member
	return nearest


func _find_nearest_party_member() -> Node2D:
	var members := get_tree().get_nodes_in_group("party_member")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for member in members:
		var dist := global_position.distance_to(member.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = member
	return nearest


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
