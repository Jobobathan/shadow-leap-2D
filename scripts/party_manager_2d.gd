extends Node
## 2D Party Manager — turn-based ordering, ability aiming, engagement handling.
## Space = move to cursor. Q = aim ability -> confirm. Tab = switch member. E = end turn.

enum InputMode { SELECTING, AIMING }

var party: Array = []
var cursor: Node2D = null
var turn_manager: Node = null
var engagement_manager: Node = null
var active_member: Node2D = null
var input_mode: InputMode = InputMode.SELECTING

var pending_members: Array = []
var members_in_transit: int = 0
var end_turn_requested: bool = false
var phase_ending: bool = false
var phase_generation: int = 0

var members_ability_queued: Dictionary = {}
var members_aim_angle: Dictionary = {}

## Telegraph visual state
var aim_angle: float = 0.0
var aim_telegraph_visible: bool = false
var aim_telegraph_pos: Vector2 = Vector2.ZERO
var flash_telegraph_visible: bool = false
var flash_telegraph_pos: Vector2 = Vector2.ZERO
var flash_telegraph_angle: float = 0.0

## Telegraph draw node
var telegraph_drawer: Node2D = null


func _ready() -> void:
	await get_tree().process_frame

	cursor = get_node_or_null("../TacticalCursor")
	turn_manager = get_node_or_null("../TurnManager")
	engagement_manager = get_node_or_null("../EngagementManager")
	party = get_tree().get_nodes_in_group("party_member")
	party.sort_custom(func(a: Node, b: Node) -> bool: return a.name > b.name)

	for member in party:
		if member.has_signal("arrived"):
			member.arrived.connect(_on_member_arrived.bind(member))
		members_ability_queued[member] = false
		members_aim_angle[member] = 0.0

	if turn_manager:
		turn_manager.player_phase_started.connect(_on_player_phase_started)
	if engagement_manager:
		engagement_manager.engagement_started.connect(_on_engagement_started)
		engagement_manager.engagement_resolved.connect(_on_engagement_resolved)

	# Create telegraph drawer after tree is ready
	telegraph_drawer = TelegraphDrawer.new()
	telegraph_drawer.party_manager = self
	telegraph_drawer.z_index = 5
	get_parent().add_child(telegraph_drawer)

	pending_members = party.duplicate()
	_activate_next()
	print("[Party] Ready — %d members. Space=move, Tab=switch, Q=aim, E=end turn." % party.size())


func _on_player_phase_started() -> void:
	phase_ending = false
	phase_generation += 1
	input_mode = InputMode.SELECTING
	members_in_transit = 0
	end_turn_requested = false
	for member in party:
		members_ability_queued[member] = false
		members_aim_angle[member] = 0.0
	aim_telegraph_visible = false
	flash_telegraph_visible = false
	if cursor:
		cursor.set("aiming_mode", false)
	_reorder_by_endangered()
	pending_members = party.duplicate()
	_activate_next()
	print("[Party] Player phase ready — %d members." % party.size())


func _on_engagement_started() -> void:
	if not engagement_manager:
		return
	var eng: Dictionary = engagement_manager.get_active_engagement()
	if eng.is_empty():
		return
	var member: Node2D = eng.member
	if member not in pending_members:
		members_in_transit = maxi(members_in_transit - 1, 0)
		pending_members.push_front(member)
	active_member = member
	if cursor:
		cursor.global_position = member.global_position


func _on_engagement_resolved() -> void:
	if active_member:
		pending_members.erase(active_member)
		_activate_next()
		_try_end_phase()


func _reorder_by_endangered() -> void:
	var big_demons := get_tree().get_nodes_in_group("boss_enemy")
	var endangered: Array = []
	var safe: Array = []
	for member in party:
		var in_danger := false
		for demon in big_demons:
			if demon.has_method("is_point_in_telegraph") and demon.is_point_in_telegraph(member.global_position):
				in_danger = true
				break
		if in_danger:
			endangered.append(member)
		else:
			safe.append(member)
	if endangered.size() > 0:
		party = endangered + safe


func _activate_next() -> void:
	if pending_members.is_empty():
		active_member = null
		return
	active_member = pending_members[0] as Node2D
	if cursor:
		cursor.global_position = active_member.global_position
	print("[Party] Active: %s (%d pending)" % [active_member.name, pending_members.size()])


func _process(_delta: float) -> void:
	if input_mode == InputMode.AIMING and aim_telegraph_visible:
		var aim_input := Vector2.ZERO
		aim_input.x = Input.get_axis("move_left", "move_right")
		aim_input.y = Input.get_axis("move_up", "move_down")
		if aim_input.length() > 0.1:
			aim_angle = aim_input.angle()
	if telegraph_drawer:
		telegraph_drawer.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if turn_manager and not turn_manager.is_player_phase():
		return
	if phase_ending:
		return
	if engagement_manager and engagement_manager.has_active_engagement():
		return

	if event.is_action_pressed("end_turn"):
		_request_end_turn()
		return

	if not active_member or not cursor:
		return

	match input_mode:
		InputMode.SELECTING:
			if event.is_action_pressed("confirm"):
				_order_move(active_member)
			elif event.is_action_pressed("ability_1"):
				_enter_aiming(active_member)
			elif event.is_action_pressed("switch_character"):
				_try_tab_switch()
		InputMode.AIMING:
			if event.is_action_pressed("ability_1"):
				_confirm_ability(active_member)
			elif event.is_action_pressed("confirm"):
				_exit_aiming()


func _order_move(active: Node2D) -> void:
	if active not in pending_members:
		return
	if active.has_method("move_to"):
		active.move_to(cursor.global_position)
		pending_members.erase(active)
		members_ability_queued[active] = false
		members_in_transit += 1
		print("[Party] %s ordered to move (%d pending, %d transit)" % [active.name, pending_members.size(), members_in_transit])
	_activate_next()


func _enter_aiming(active: Node2D) -> void:
	if active not in pending_members:
		return
	input_mode = InputMode.AIMING
	aim_angle = 0.0
	aim_telegraph_visible = true
	aim_telegraph_pos = cursor.global_position
	if cursor:
		cursor.set("aiming_mode", true)
	print("[Party] %s — aiming ability (WASD aim, Q confirm, Space cancel)" % active.name)


func _confirm_ability(active: Node2D) -> void:
	if active not in pending_members:
		return
	var ability_pos := aim_telegraph_pos
	if active.has_method("move_to"):
		active.move_to(ability_pos)
		pending_members.erase(active)
		members_ability_queued[active] = true
		members_aim_angle[active] = aim_angle
		members_in_transit += 1
	_exit_aiming()
	_activate_next()


func _exit_aiming() -> void:
	input_mode = InputMode.SELECTING
	aim_telegraph_visible = false
	if cursor:
		cursor.set("aiming_mode", false)


func _try_tab_switch() -> void:
	if pending_members.size() <= 1:
		return
	var current_idx := pending_members.find(active_member)
	if current_idx < 0:
		current_idx = 0
	var next_idx := (current_idx + 1) % pending_members.size()
	active_member = pending_members[next_idx] as Node2D
	if cursor:
		cursor.global_position = active_member.global_position
	print("[Party] Switched to %s" % active_member.name)


func _request_end_turn() -> void:
	if phase_ending or end_turn_requested:
		return
	end_turn_requested = true
	print("[Party] End turn requested (in transit: %d)" % members_in_transit)
	_try_end_phase()


func _try_end_phase() -> void:
	if not end_turn_requested or phase_ending:
		return
	if members_in_transit > 0:
		return
	phase_ending = true
	if turn_manager:
		print("[Party] All members resolved — ending player phase")
		turn_manager.end_player_phase()


func _on_member_arrived(member: Node) -> void:
	var gen := phase_generation
	print("[Party] %s arrived" % member.name)

	if members_ability_queued.get(member, false):
		flash_telegraph_visible = true
		flash_telegraph_pos = (member as Node2D).global_position
		flash_telegraph_angle = members_aim_angle.get(member, 0.0)
		await get_tree().create_timer(1.5).timeout
		if gen != phase_generation:
			return
		flash_telegraph_visible = false

	await get_tree().create_timer(1.0).timeout
	if gen != phase_generation:
		return

	members_in_transit -= 1
	print("[Party] %s turn resolved (in transit: %d)" % [member.name, members_in_transit])
	_try_end_phase()


## ─── Telegraph Drawer (inner class) ──────────────────────
class TelegraphDrawer extends Node2D:
	var party_manager: Node = null

	func _draw() -> void:
		if not party_manager:
			return
		if party_manager.aim_telegraph_visible:
			_draw_telegraph(party_manager.aim_telegraph_pos, party_manager.aim_angle, Color(0.3, 0.6, 1.0, 0.4))
		if party_manager.flash_telegraph_visible:
			_draw_telegraph(party_manager.flash_telegraph_pos, party_manager.flash_telegraph_angle, Color(0.9, 0.7, 0.2, 0.6))

	func _draw_telegraph(pos: Vector2, angle: float, color: Color) -> void:
		# Convert global pos to local
		var local_pos := pos - global_position
		var dir := Vector2.from_angle(angle)
		var perp := Vector2(-dir.y, dir.x)
		var half_w := 60.0
		var length := 160.0
		var points := PackedVector2Array([
			local_pos + perp * half_w,
			local_pos + perp * half_w + dir * length,
			local_pos - perp * half_w + dir * length,
			local_pos - perp * half_w,
		])
		draw_colored_polygon(points, color)
