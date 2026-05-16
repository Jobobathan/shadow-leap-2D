extends SceneTree

## Headless screenshot: loads the main scene, waits a few frames, saves PNG, quits.

var _frame_count := 0

func _init() -> void:
	pass

func _process(_delta: float) -> bool:
	_frame_count += 1
	# Wait 10 frames for everything to render and settle
	if _frame_count == 2:
		# Load and switch to the main scene
		change_scene_to_file("res://scenes/main.tscn")
	elif _frame_count >= 12:
		# Capture screenshot
		var viewport := get_root().get_viewport()
		var img := viewport.get_texture().get_image()
		var path := "user://screenshot.png"
		img.save_png(path)
		# Also save to project dir
		img.save_png("res://screenshot.png")
		print("Screenshot saved! Size: %dx%d" % [img.get_width(), img.get_height()])
		quit()
		return true
	return false
