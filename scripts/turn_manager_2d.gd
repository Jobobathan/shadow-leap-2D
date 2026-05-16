extends Node
## 2D Turn Manager — Player Phase / Enemy Phase cycle.
## Small demons act sequentially (camera follows each). Boss charges in parallel.

signal player_phase_started
signal enemy_phase_started

enum Phase { PLAYER, ENEMY }

var current_phase: Phase = Phase.PLAYER
var camera_focus_target: Node2D = null

var boss_enemies: Array = []
var minion_enemies: Array = []
var current_minion_index: int = 0
var total_enemies: int = 0
var done_count: int = 0
var phase_transitioning: bool = false

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("[TurnManager] Initialized")
	_start_player_phase()

func _start_player_phase() -> void:
	current_phase = Phase.PLAYER
	camera_focus_target = null
	phase_transitioning = false
	print("[TurnManager] ========== PLAYER PHASE ==========")
	player_phase_started.emit()

func _start_enemy_phase() -> void:
	current_phase = Phase.ENEMY
	boss_enemies.clear()
	minion_enemies.clear()

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_in_group("boss_enemy"):
			boss_enemies.append(enemy)
		else:
			minion_enemies.append(enemy)

	total_enemies = boss_enemies.size() + minion_enemies.size()
	done_count = 0
	current_minion_index = 0
	phase_transitioning = false

	print("[TurnManager] ========== ENEMY PHASE (%d enemies) ==========" % total_enemies)

	if total_enemies == 0:
		await get_tree().create_timer(1.0).timeout
		_start_player_phase()
		return

	enemy_phase_started.emit()

	# Boss charges in parallel (background)
	for boss in boss_enemies:
		if boss.has_method("start_turn"):
			boss.start_turn()

	# Minions go sequentially
	_start_next_minion()

func _start_next_minion() -> void:
	if current_minion_index >= minion_enemies.size():
		_check_enemy_phase_done()
		return
	var minion: Node = minion_enemies[current_minion_index]
	camera_focus_target = minion as Node2D
	if minion.has_method("start_turn"):
		minion.start_turn()

func report_enemy_done(enemy: Node = null) -> void:
	done_count += 1
	print("[TurnManager] Enemy %d/%d done (%s)" % [done_count, total_enemies, enemy.name if enemy else "?"])
	if enemy and not enemy.is_in_group("boss_enemy"):
		current_minion_index += 1
		if current_minion_index < minion_enemies.size():
			await get_tree().create_timer(0.5).timeout
			_start_next_minion()
			return
	_check_enemy_phase_done()

func _check_enemy_phase_done() -> void:
	if phase_transitioning:
		return
	if done_count >= total_enemies:
		phase_transitioning = true
		print("[TurnManager] All enemies done — returning to player phase")
		await get_tree().create_timer(1.0).timeout
		_start_player_phase()

func is_player_phase() -> bool:
	return current_phase == Phase.PLAYER

func end_player_phase() -> void:
	if current_phase != Phase.PLAYER or phase_transitioning:
		return
	phase_transitioning = true
	print("[TurnManager] Player phase ending...")
	await get_tree().create_timer(0.5).timeout
	_start_enemy_phase()
