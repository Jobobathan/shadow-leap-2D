extends Node
## 2D Engagement Manager — zone overlap detection + ARPG mode toggle.
## When party member + enemy engagement zones overlap → ARPG fight.
## Timer-based auto-resolve, damage aggregation, queue system.

signal engagement_triggered(party_member: Node2D, enemy: Node2D)
signal engagement_ended(party_member: Node2D, enemy: Node2D)
signal engagement_started
signal engagement_resolved

var overlapping_pairs: Dictionary = {}
var active_engagement: Dictionary = {}
var engagement_queue: Array = []
var cooldown_pairs: Dictionary = {}
const RESOLVE_COOLDOWN: float = 8.0
var combat_camera: Camera2D = null
var is_resolving: bool = false

var engagement_center: Vector2 = Vector2.ZERO
@export var engagement_boundary: float = 240.0
@export var engagement_duration: float = 12.0
var engagement_timer: float = 0.0
var engagement_active: bool = false

var party_damage_dealt: int = 0
var enemy_damage_dealt: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	combat_camera = get_node_or_null("../Camera2D")
	print("[EngagementMgr] Initialized — ARPG engagement system (%.0fs timer)" % engagement_duration)


func _physics_process(delta: float) -> void:
	# Tick cooldowns
	var expired: Array = []
	for key in cooldown_pairs:
		cooldown_pairs[key] -= delta
		if cooldown_pairs[key] <= 0.0:
			expired.append(key)
	for key in expired:
		cooldown_pairs.erase(key)

	# Tick engagement timer
	if engagement_active and not is_resolving:
		engagement_timer -= delta
		if engagement_timer <= 0.0:
			print("[EngagementMgr] Timer expired!")
			_resolve_current()
			return
		if not active_engagement.is_empty():
			var enemy: Node2D = active_engagement.enemy
			var member: Node2D = active_engagement.member
			if enemy.has_method("is_alive") and not enemy.is_alive():
				print("[EngagementMgr] Enemy eliminated!")
				_resolve_current()
				return
			if member.has_method("is_alive") and not member.is_alive():
				print("[EngagementMgr] Party member down!")
				_resolve_current()
				return

	# Check engagement zone overlaps
	var party := get_tree().get_nodes_in_group("party_member")
	var enemies := get_tree().get_nodes_in_group("enemy")

	for m in party:
		var member := m as Node2D
		var m_radius: float = member.get("engagement_radius") if member.get("engagement_radius") != null else 100.0
		for e in enemies:
			var enemy := e as Node2D
			if enemy.is_in_group("boss_enemy"):
				continue
			var e_radius: float = enemy.get("engagement_radius") if enemy.get("engagement_radius") != null else 100.0
			var dist: float = member.global_position.distance_to(enemy.global_position)
			var trigger_dist: float = m_radius + e_radius
			var pair_key: String = _pair_key(member, enemy)

			if dist < trigger_dist:
				if not overlapping_pairs.has(pair_key):
					overlapping_pairs[pair_key] = {member = member, enemy = enemy}
					var enemy_alive: bool = not enemy.get("is_dead") if enemy.get("is_dead") != null else true
					var enemy_retreating: bool = enemy.get("is_retreating") if enemy.get("is_retreating") != null else false
					if not cooldown_pairs.has(pair_key) and enemy_alive and not enemy_retreating:
						print("[EngagementMgr] ZONES OVERLAP: %s <-> %s (dist %.1f < %.1f)" % [member.name, enemy.name, dist, trigger_dist])
						engagement_triggered.emit(member, enemy)
						_queue_or_start(member, enemy)
			else:
				if overlapping_pairs.has(pair_key):
					overlapping_pairs.erase(pair_key)
					engagement_ended.emit(member, enemy)


func _queue_or_start(member: Node2D, enemy: Node2D) -> void:
	if active_engagement.is_empty():
		_start_engagement(member, enemy)
	else:
		if active_engagement.member == member and active_engagement.enemy == enemy:
			return
		for entry in engagement_queue:
			if entry.member == member and entry.enemy == enemy:
				return
		engagement_queue.append({member = member, enemy = enemy})
		print("[EngagementMgr] Queued: %s <-> %s (%d in queue)" % [member.name, enemy.name, engagement_queue.size()])


func _start_engagement(member: Node2D, enemy: Node2D) -> void:
	active_engagement = {member = member, enemy = enemy}
	member.set("is_engaged", true)
	member.set("arpg_state", 0)  # ArpgState.MOVE
	member.set("combo_step", 0)
	member.set("is_invincible", false)
	enemy.set("is_engaged", true)
	if member.has_method("cancel_movement"):
		member.cancel_movement()
	enemy.set("engagement_target", member)
	enemy.set("arpg_ai_state", 0)  # ArpgAI.APPROACH

	engagement_center = (member.global_position + enemy.global_position) / 2.0
	engagement_timer = engagement_duration
	engagement_active = true
	party_damage_dealt = 0
	enemy_damage_dealt = 0

	engagement_started.emit()

	print("[EngagementMgr] ========================================")
	print("[EngagementMgr]   ARPG ENGAGEMENT: %s <-> %s" % [member.name, enemy.name])
	print("[EngagementMgr]   Duration: %.0fs — FIGHT!" % engagement_duration)
	print("[EngagementMgr] ========================================")

	if combat_camera and combat_camera.has_method("zoom_to_engagement"):
		combat_camera.zoom_to_engagement(engagement_center)


func _resolve_current() -> void:
	if active_engagement.is_empty() or is_resolving:
		return
	is_resolving = true
	engagement_active = false

	var member: Node2D = active_engagement.member
	var enemy: Node2D = active_engagement.enemy

	var enemy_dead: bool = enemy.has_method("is_alive") and not enemy.is_alive()
	var member_dead: bool = member.has_method("is_alive") and not member.is_alive()
	var party_wins: bool = enemy_dead or (not member_dead and party_damage_dealt >= enemy_damage_dealt)

	print("[EngagementMgr] === ENGAGEMENT RESOLVED ===")
	if enemy_dead:
		print("[EngagementMgr] Enemy ELIMINATED!")
	elif member_dead:
		print("[EngagementMgr] Party member DOWN!")
	else:
		print("[EngagementMgr] Timer — Party dealt %d, Enemy dealt %d -> %s wins" % [party_damage_dealt, enemy_damage_dealt, "Party" if party_wins else "Enemy"])

	var pair_key: String = _pair_key(member, enemy)
	cooldown_pairs[pair_key] = RESOLVE_COOLDOWN
	overlapping_pairs.erase(pair_key)

	member.set("is_engaged", false)
	enemy.set("is_engaged", false)
	enemy.set("engagement_target", null)

	if combat_camera and combat_camera.has_method("zoom_to_macro"):
		await combat_camera.zoom_to_macro(member.global_position)

	# Always retreat after engagement (prevents standing on top of party)
	if enemy.has_method("retreat_from") and not enemy_dead:
		enemy.retreat_from(member.global_position)

	engagement_resolved.emit()
	active_engagement = {}
	engagement_center = Vector2.ZERO
	is_resolving = false

	# Process queue
	while not engagement_queue.is_empty():
		var next: Dictionary = engagement_queue.pop_front()
		var next_key := _pair_key(next.member, next.enemy)
		var enemy_alive: bool = not next.enemy.get("is_dead") if next.enemy.get("is_dead") != null else true
		if cooldown_pairs.has(next_key) or not enemy_alive:
			continue
		await get_tree().create_timer(0.5).timeout
		if next.member and next.enemy:
			_start_engagement(next.member, next.enemy)
		break


func report_damage(is_party_damage: bool, amount: int) -> void:
	if is_party_damage:
		party_damage_dealt += amount
	else:
		enemy_damage_dealt += amount


func _pair_key(a: Node, b: Node) -> String:
	return "%d_%d" % [a.get_instance_id(), b.get_instance_id()]


func has_active_engagement() -> bool:
	return not active_engagement.is_empty()


func get_active_engagement() -> Dictionary:
	return active_engagement
