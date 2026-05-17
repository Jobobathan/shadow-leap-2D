extends CanvasLayer
## Updates UI labels with game state (phase, HP, engagement).
## Runs a 100ms timer to keep labels current.

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(_update_labels)
	add_child(timer)


func _update_labels() -> void:
	var tm := get_node_or_null("../TurnManager")
	var em := get_node_or_null("../EngagementManager")

	var phase_label := $PhaseLabel as Label
	var hp_label := $HPLabel as Label
	var eng_label := $EngLabel as Label

	if tm:
		phase_label.text = "PLAYER PHASE" if tm.is_player_phase() else "ENEMY PHASE"

	var members := get_tree().get_nodes_in_group("party_member")
	var hp_text := ""
	for m in members:
		hp_text += "%s: %d/%d HP   " % [m.name, m.get("current_hp"), m.get("max_hp")]
	hp_label.text = hp_text

	if em and em.has_active_engagement():
		var eng = em.get_active_engagement()
		eng_label.text = "ENGAGEMENT: %s vs %s (%.1fs)" % [
			eng.member.name, eng.enemy.name, em.engagement_timer]
	else:
		eng_label.text = ""
