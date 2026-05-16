class_name Player2D
extends CharacterBody2D
## Full 2D party member — tactical movement + ARPG combat + ranged.
## Melee: 3-hit combo, dodge+i-frames, parry. Ranged: auto-kite, arrows.

signal arrived

## ─── Movement & Combat Exports ────────────────────────────
@export var speed: float = 200.0
@export var arrival_threshold: float = 12.0
@export var max_hp: int = 100
@export var engagement_radius: float = 100.0
@export var arpg_speed: float = 200.0
@export var attack_damage: Array[int] = [15, 15, 25]
@export var attack_range: float = 100.0
@export var dodge_speed: float = 320.0
@export var dodge_duration: float = 0.15
@export var dodge_cooldown: float = 0.5
@export var combo_window: float = 0.6
@export var parry_window: float = 0.25
@export var parry_recovery: float = 0.25

## ─── Ranged Combat Exports (Akari) ───────────────────────
@export var is_ranged: bool = false
@export var ranged_damage: int = 13
@export var ranged_range: float = 360.0
@export var ranged_cooldown: float = 0.85
@export var preferred_range: float = 320.0
@export var kite_threshold: float = 200.0
@export var kite_speed: float = 160.0

## ─── Tactical State ───────────────────────────────────────
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var is_engaged: bool = false
var saved_tactical_target: Vector2 = Vector2.ZERO
var had_tactical_walk: bool = false

## ─── ARPG Combat State ────────────────────────────────────
enum ArpgState { MOVE, ATTACKING, DODGING, HIT, PARRYING }
var arpg_state: ArpgState = ArpgState.MOVE
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_direction: Vector2 = Vector2.ZERO
var is_invincible: bool = false
var parry_timer: float = 0.0
var parry_active: bool = false
var afterimage_timer: float = 0.0
var combo_step: int = 0
var attack_timer: float = 0.0
var combo_reset_timer: float = 0.0
var attack_hit_checked: bool = false
var last_move_dir: Vector2 = Vector2(0, 1)
var intended_move_dir: Vector2 = Vector2.ZERO
var current_hp: int = 100

## ─── Ranged State ─────────────────────────────────────────
var ranged_cooldown_timer: float = 0.0
var shoot_frame_triggered: bool = false
var ranged_target: Node2D = null

## ─── Hit-Stop ─────────────────────────────────────────────
var hitstop_timer: float = 0.0
var hitstop_duration: float = 0.08

## ─── Sprite ───────────────────────────────────────────────
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing_dir: int = 2  # 0=up, 1=left, 2=down, 3=right
var base_sprite_scale: Vector2 = Vector2(2.0, 2.0)

## ─── Visual ───────────────────────────────────────────────
var damage_tween: Tween = null


func _ready() -> void:
	target_position = global_position
	current_hp = max_hp
	if sprite:
		base_sprite_scale = sprite.scale
	_play_anim("idle")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Engagement zone indicator (always visible)
	draw_arc(Vector2.ZERO, engagement_radius, 0, TAU, 32, Color(0.0, 0.8, 0.8, 0.2), 2.0)
	# HP bar (only during engagement when damaged)
	if is_engaged and current_hp < max_hp:
		var bar_w := 50.0
		var bar_h := 6.0
		var bar_y := -80.0
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.8))
		var ratio := float(current_hp) / float(max_hp)
		var fill_w := bar_w * ratio
		var fill_color: Color
		if ratio > 0.6:
			fill_color = Color(0.2, 0.9, 0.2)
		elif ratio > 0.3:
			fill_color = Color(0.9, 0.8, 0.1)
		else:
			fill_color = Color(0.9, 0.15, 0.1)
		draw_rect(Rect2(-bar_w / 2.0, bar_y, fill_w, bar_h), fill_color)


## ─── Physics & Combat ─────────────────────────────────────

func _physics_process(delta: float) -> void:
	if hitstop_timer > 0.0:
		hitstop_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_engaged:
		_process_arpg_movement(delta)
		return

	if not is_moving:
		velocity = Vector2.ZERO
		intended_move_dir = Vector2.ZERO
		_play_anim("idle")
		move_and_slide()
		return

	var direction := target_position - global_position
	if direction.length() < arrival_threshold:
		is_moving = false
		velocity = Vector2.ZERO
		intended_move_dir = Vector2.ZERO
		_play_anim("idle")
		arrived.emit()
		move_and_slide()
		return

	var move_dir := direction.normalized()
	velocity = move_dir * speed
	intended_move_dir = move_dir
	last_move_dir = move_dir
	_update_facing(move_dir)
	_play_anim("run")
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not is_engaged:
		return

	if event.is_action_pressed("parry"):
		if arpg_state in [ArpgState.MOVE, ArpgState.ATTACKING]:
			_start_parry()
			return

	if event.is_action_pressed("dodge") and arpg_state == ArpgState.MOVE:
		if dodge_cooldown_timer <= 0.0:
			_start_dodge()

	if event.is_action_pressed("attack"):
		if is_ranged:
			if arpg_state == ArpgState.MOVE and ranged_cooldown_timer <= 0.0:
				_start_ranged_attack()
		else:
			if arpg_state == ArpgState.MOVE:
				_start_attack(1)
			elif arpg_state == ArpgState.ATTACKING and combo_step < 3 and attack_timer <= 0.0:
				_start_attack(combo_step + 1)


func _process_arpg_movement(delta: float) -> void:
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta
	if ranged_cooldown_timer > 0.0:
		ranged_cooldown_timer -= delta

	match arpg_state:
		ArpgState.MOVE:
			_arpg_move(delta)
		ArpgState.DODGING:
			_arpg_dodge(delta)
		ArpgState.ATTACKING:
			_arpg_attack(delta)
		ArpgState.HIT:
			_arpg_hit(delta)
		ArpgState.PARRYING:
			_arpg_parry(delta)

	move_and_slide()
	_enforce_boundary()


func _arpg_move(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir.length() > 0.1:
		if input_dir.length() > 1.0:
			input_dir = input_dir.normalized()
		velocity = input_dir * arpg_speed
		intended_move_dir = input_dir
		last_move_dir = input_dir.normalized()
		_update_facing(input_dir)
		_play_anim("run")
	else:
		if is_ranged:
			var enemy := _find_engagement_enemy()
			if enemy:
				var to_enemy := enemy.global_position - global_position
				var dist := to_enemy.length()
				if dist < kite_threshold and dist > 4.0:
					var away := -to_enemy.normalized()
					velocity = away * kite_speed
					intended_move_dir = away
					last_move_dir = away
					_update_facing(away)
					_play_anim("run")
				else:
					velocity = Vector2.ZERO
					if dist > 4.0:
						intended_move_dir = to_enemy.normalized()
						_update_facing(to_enemy.normalized())
					_play_anim("idle")
			else:
				velocity = Vector2.ZERO
				intended_move_dir = Vector2.ZERO
				_play_anim("idle")
		else:
			velocity = Vector2.ZERO
			intended_move_dir = Vector2.ZERO
			_play_anim("idle")

	if combo_step > 0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_step = 0


## ─── Dodge ────────────────────────────────────────────────

func _start_dodge() -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir.length() > 0.1:
		dodge_direction = input_dir.normalized()
	else:
		dodge_direction = last_move_dir

	arpg_state = ArpgState.DODGING
	dodge_timer = dodge_duration
	is_invincible = true
	intended_move_dir = dodge_direction
	afterimage_timer = 0.0
	_play_anim("run")
	_spawn_afterimage()
	# Visual i-frame indicator
	if sprite:
		sprite.modulate.a = 0.5
	# Squash/stretch
	if sprite:
		var squash_tween := create_tween()
		sprite.scale = Vector2(base_sprite_scale.x * 0.7, base_sprite_scale.y * 1.3)
		squash_tween.tween_property(sprite, "scale", base_sprite_scale, dodge_duration * 0.8)
	print("[%s] DODGE" % name)


func _arpg_dodge(delta: float) -> void:
	dodge_timer -= delta
	velocity = dodge_direction * dodge_speed

	afterimage_timer -= delta
	if afterimage_timer <= 0.0:
		_spawn_afterimage()
		afterimage_timer = 0.06

	if dodge_timer <= 0.0:
		is_invincible = false
		dodge_cooldown_timer = dodge_cooldown
		arpg_state = ArpgState.MOVE
		velocity = Vector2.ZERO
		if sprite:
			sprite.modulate.a = 1.0


## ─── Melee Attack ─────────────────────────────────────────

func _start_attack(step: int) -> void:
	combo_step = step
	arpg_state = ArpgState.ATTACKING
	attack_hit_checked = false

	match step:
		1: attack_timer = 0.4
		2: attack_timer = 0.4
		3: attack_timer = 0.6

	velocity = last_move_dir * 120.0
	intended_move_dir = last_move_dir
	_play_anim("slash")
	print("[%s] ATTACK %d" % [name, step])


func _arpg_attack(delta: float) -> void:
	attack_timer -= delta
	if is_ranged:
		velocity = Vector2.ZERO
		if ranged_target and is_instance_valid(ranged_target):
			var to_target := ranged_target.global_position - global_position
			if to_target.length() > 4.0:
				intended_move_dir = to_target.normalized()
				_update_facing(to_target.normalized())
		if not shoot_frame_triggered and attack_timer < 0.45:
			shoot_frame_triggered = true
			_spawn_arrow()
		if attack_timer <= 0.0:
			arpg_state = ArpgState.MOVE
			ranged_cooldown_timer = ranged_cooldown
			velocity = Vector2.ZERO
	else:
		velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
		if not attack_hit_checked and attack_timer < 0.2:
			attack_hit_checked = true
			_check_attack_hit()
		if attack_timer <= 0.0:
			arpg_state = ArpgState.MOVE
			combo_reset_timer = combo_window
			velocity = Vector2.ZERO


func _check_attack_hit() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var dmg: int = attack_damage[mini(combo_step - 1, attack_damage.size() - 1)]
	var did_hit: bool = false

	for e in enemies:
		var enemy: Node2D = e as Node2D
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= attack_range:
			var to_enemy := (enemy.global_position - global_position).normalized()
			var facing := last_move_dir.normalized()
			if to_enemy.dot(facing) > 0.3:
				if enemy.has_method("take_damage"):
					enemy.take_damage(dmg)
					did_hit = true
					print("[%s] HIT %s for %d (combo %d)" % [name, enemy.name, dmg, combo_step])
				if enemy.has_method("apply_hitstop"):
					enemy.apply_hitstop(hitstop_duration)
				var eng_mgr := get_node_or_null("../EngagementManager")
				if eng_mgr and eng_mgr.has_method("report_damage"):
					eng_mgr.report_damage(true, dmg)

	if did_hit:
		hitstop_timer = hitstop_duration
		if combo_step == 3:
			hitstop_timer = 0.12
			var cam := get_node_or_null("../Camera2D")
			if cam and cam.has_method("screen_shake"):
				cam.screen_shake(0.2, 0.3)


## ─── Ranged Attack (Akari) ────────────────────────────────

func _start_ranged_attack() -> void:
	ranged_target = _find_engagement_enemy()
	if not ranged_target:
		return
	arpg_state = ArpgState.ATTACKING
	shoot_frame_triggered = false
	attack_hit_checked = false
	attack_timer = 1.1
	velocity = Vector2.ZERO
	combo_step = 0
	var to_target := ranged_target.global_position - global_position
	if to_target.length() > 4.0:
		intended_move_dir = to_target.normalized()
		last_move_dir = intended_move_dir
		_update_facing(intended_move_dir)
	_play_anim("slash")
	print("[%s] SHOOT at %s" % [name, ranged_target.name])


func _spawn_arrow() -> void:
	if not ranged_target or not is_instance_valid(ranged_target):
		return
	var arrow := Node2D.new()
	arrow.set_script(load("res://scripts/arrow_projectile_2d.gd"))
	arrow.global_position = global_position
	var dir := (ranged_target.global_position - global_position).normalized()
	arrow.set("direction", dir)
	arrow.set("speed", 880.0)
	arrow.set("damage", ranged_damage)
	arrow.set("max_distance", ranged_range + 120.0)
	arrow.set("target", ranged_target)
	arrow.set("shooter", self)
	get_tree().root.get_child(0).add_child(arrow)
	print("[%s] Arrow spawned toward %s" % [name, ranged_target.name])


func _find_engagement_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for e in enemies:
		var enemy := e as Node2D
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest


## ─── Hit State ────────────────────────────────────────────

func _arpg_hit(delta: float) -> void:
	attack_timer -= delta
	velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)
	if attack_timer <= 0.0:
		arpg_state = ArpgState.MOVE


func take_arpg_damage(amount: int, from_enemy: Node2D, parryable: bool = false) -> void:
	if is_invincible:
		print("[%s] DODGED! (i-frames)" % name)
		return
	if arpg_state == ArpgState.PARRYING and parry_active and parryable:
		_parry_success(from_enemy)
		return
	take_damage(amount)
	arpg_state = ArpgState.HIT
	attack_timer = 0.3
	combo_step = 0
	_play_anim("hurt")
	if from_enemy:
		var knockback := (global_position - from_enemy.global_position).normalized()
		velocity = knockback * 200.0
	var eng_mgr := get_node_or_null("../EngagementManager")
	if eng_mgr and eng_mgr.has_method("report_damage"):
		eng_mgr.report_damage(false, amount)


func _enforce_boundary() -> void:
	var eng_mgr := get_node_or_null("../EngagementManager")
	if eng_mgr:
		var center: Vector2 = eng_mgr.get("engagement_center")
		var boundary: float = eng_mgr.get("engagement_boundary")
		if center != null and center != Vector2.ZERO and boundary > 0.0:
			var dist := global_position.distance_to(center)
			if dist > boundary:
				var push := (center - global_position).normalized()
				global_position += push * (dist - boundary)


## ─── Parry System ─────────────────────────────────────────

func _start_parry() -> void:
	arpg_state = ArpgState.PARRYING
	parry_timer = parry_window
	parry_active = true
	velocity = Vector2.ZERO
	combo_step = 0
	_play_anim("idle")
	if sprite:
		sprite.modulate = Color(0.5, 0.7, 1.0, 1.0)
	print("[%s] PARRY STANCE" % name)


func _arpg_parry(delta: float) -> void:
	velocity = Vector2.ZERO
	parry_timer -= delta
	if parry_active and parry_timer <= 0.0:
		parry_active = false
		parry_timer = parry_recovery
		if sprite:
			sprite.modulate = Color.WHITE
	elif not parry_active and parry_timer <= 0.0:
		arpg_state = ArpgState.MOVE
		_play_anim("idle")


func _parry_success(from_enemy: Node2D) -> void:
	print("[%s] PERFECT PARRY!" % name)
	parry_active = false
	arpg_state = ArpgState.MOVE
	_play_anim("idle")
	if sprite:
		sprite.modulate = Color.WHITE
		var pop_tween := create_tween()
		sprite.scale = base_sprite_scale * 1.3
		pop_tween.tween_property(sprite, "scale", base_sprite_scale, 0.15).set_ease(Tween.EASE_OUT)
	if from_enemy and from_enemy.has_method("get_parried"):
		from_enemy.get_parried()
	var cam := get_node_or_null("../Camera2D")
	if cam and cam.has_method("screen_shake"):
		cam.screen_shake(0.25, 0.3)
	hitstop_timer = 0.12
	var eng_mgr := get_node_or_null("../EngagementManager")
	if eng_mgr and eng_mgr.has_method("report_damage"):
		eng_mgr.report_damage(true, 15)


## ─── Afterimage System ────────────────────────────────────

func _spawn_afterimage() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.global_position = global_position
	ghost.scale = sprite.scale
	ghost.modulate = Color(0.3, 0.5, 1.0, 0.5)
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)


## ─── Tactical Commands & HP ───────────────────────────────

func move_to(pos: Vector2) -> void:
	target_position = pos
	is_moving = true


func take_damage(amount: int) -> void:
	current_hp = clampi(current_hp - amount, 0, max_hp)
	print("[%s] took %d damage -> %d/%d HP" % [name, amount, current_hp, max_hp])
	_flash_damage()


func _flash_damage() -> void:
	if damage_tween and damage_tween.is_valid():
		damage_tween.kill()
	damage_tween = create_tween()
	if sprite:
		damage_tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3), 0.08)
		damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.35)


func is_alive() -> bool:
	return current_hp > 0


func apply_hitstop(duration: float) -> void:
	hitstop_timer = duration


func cancel_movement() -> void:
	if is_moving:
		saved_tactical_target = target_position
		had_tactical_walk = true
	else:
		had_tactical_walk = false
	is_moving = false
	target_position = global_position
	velocity = Vector2.ZERO


func resume_tactical_walk() -> void:
	if had_tactical_walk:
		had_tactical_walk = false
		move_to(saved_tactical_target)


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
