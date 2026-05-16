extends SceneTree

## Automated test: loads main scene, auto-ends player turns, captures periodic screenshots.
## Used for headless verification of enemy AI, pathfinding, and combat animations.

var _frame_count := 0
var _screenshot_count := 0
var _max_screenshots := 20
var _screenshot_interval := 30  # frames between screenshots
var _scene_loaded := false
var _auto_end_delay := 0  # frames to wait before auto-ending player phase
var _turn_manager: Node = null
var _party_manager: Node = null

func _init() -> void:
	pass

func _process(delta: float) -> bool:
	_frame_count += 1

	# Phase 1: Load the scene
	if _frame_count == 2:
		change_scene_to_file("res://scenes/main.tscn")
		return false

	# Phase 2: Wait for scene to stabilize, then find managers
	if _frame_count == 15 and not _scene_loaded:
		_scene_loaded = true
		var root_node = get_root().get_child(get_root().get_child_count() - 1)
		# Find TurnManager and PartyManager
		_turn_manager = _find_node_by_class(root_node, "TurnManager")
		_party_manager = _find_node_by_class(root_node, "PartyManager")
		if not _turn_manager:
			_turn_manager = _find_node_by_name(root_node, "TurnManager")
		if not _party_manager:
			_party_manager = _find_node_by_name(root_node, "PartyManager")
		print("[AutoPlay] TurnManager: %s, PartyManager: %s" % [
			"found" if _turn_manager else "NOT FOUND",
			"found" if _party_manager else "NOT FOUND"
		])
		# Take initial screenshot
		_take_screenshot("initial")
		return false

	if not _scene_loaded:
		return false

	# Phase 3: Auto-end player phases and capture screenshots
	# Try to auto-end player phase every 60 frames (about 1 second)
	if _frame_count % 60 == 0 and _turn_manager:
		if _turn_manager.has_method("is_player_phase") and _turn_manager.is_player_phase():
			print("[AutoPlay] Frame %d — Auto-ending player phase" % _frame_count)
			if _turn_manager.has_method("end_player_phase"):
				_turn_manager.end_player_phase()

	# Capture screenshots at intervals
	if _frame_count >= 30 and (_frame_count - 30) % _screenshot_interval == 0:
		_screenshot_count += 1
		_take_screenshot("frame_%03d" % _screenshot_count)
		if _screenshot_count >= _max_screenshots:
			print("[AutoPlay] All %d screenshots captured. Done." % _max_screenshots)
			quit()
			return true

	return false


func _take_screenshot(label: String) -> void:
	var viewport := get_root().get_viewport()
	var img := viewport.get_texture().get_image()
	var filename := "screenshot_%s.png" % label
	img.save_png("res://%s" % filename)
	print("[AutoPlay] Screenshot: %s (%dx%d)" % [filename, img.get_width(), img.get_height()])


func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var result = _find_node_by_name(child, target_name)
		if result:
			return result
	return null


func _find_node_by_class(root: Node, class_hint: String) -> Node:
	# Try matching script class name or node name containing the hint
	if class_hint.to_lower() in root.name.to_lower():
		return root
	if root.get_script() and class_hint.to_lower() in str(root.get_script().resource_path).to_lower():
		return root
	for child in root.get_children():
		var result = _find_node_by_class(child, class_hint)
		if result:
			return result
	return null
