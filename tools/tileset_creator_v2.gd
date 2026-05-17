@tool
extends Node2D
## ===============================================================
## TileSet Creator v2 -- Auto-scanning, FAST mode
## ===============================================================
## Scans tileset directories for PNGs and registers them.
## Skips pixel scanning -- registers ALL tile slots (fast).
## Skips tiny PNGs (individual tiles) -- only processes sheets.
##
## Usage:
##   1. Drop your SPRITE SHEET PNGs into the scan directories
##      (NOT individual tile PNGs -- only the big combined sheets)
##   2. Add this as a child Node2D in your scene
##   3. Click "Create TileSet" in the inspector
##   4. Delete this node after TileSet is created
##   5. Add TileMapLayers, assign the TileSet, paint!
## ===============================================================

const TILE := 48
const TILESET_PATH := "res://resources/city_tileset.tres"

## Minimum PNG dimensions to process (skip individual tiles)
## A sprite sheet should be at least 128x128 (4x4 tiles)
const MIN_SHEET_WIDTH := 128
const MIN_SHEET_HEIGHT := 128

## Max number of PNGs to process (safety valve)
const MAX_FILES := 50

## --- SCAN DIRECTORIES ---------------------------------------
var SCAN_DIRS: Array[String] = [
	"res://sprites/tilesets/limezu/",
	"res://sprites/tilesets/sakura/",
]

@export_tool_button("Create TileSet") var _btn = _create_tileset
@export_tool_button("Dry Run (scan only)") var _btn2 = _dry_run


func _create_tileset() -> void:
	_run(false)


func _dry_run() -> void:
	_run(true)


func _run(dry: bool) -> void:
	var label := "DRY RUN" if dry else "Creating TileSet"
	print("\n[TileSetCreator v2] === %s ===" % label)

	# -- Collect PNGs --
	var all_files: Array[Dictionary] = []

	for dir_path in SCAN_DIRS:
		var pngs := _scan_dir_for_pngs(dir_path)
		for png_path in pngs:
			if png_path.contains("upscaled_32px"):
				continue
			var info := _check_png(png_path)
			if info.size() > 0:
				all_files.append(info)

	if all_files.is_empty():
		print("  No sprite sheets found in scan directories!")
		print("  Scanned: %s" % str(SCAN_DIRS))
		print("  Make sure you have the COMBINED SHEET PNGs, not individual tiles.")
		return

	if all_files.size() > MAX_FILES:
		print("  WARNING: Found %d PNGs -- that's too many!" % all_files.size())
		print("  You probably dumped individual tile PNGs in there.")
		print("  Only put the big SPRITE SHEET PNGs in the folder.")
		print("  Processing first %d only." % MAX_FILES)
		all_files.resize(MAX_FILES)

	# -- Report --
	print("\n  Found %d sprite sheet(s):" % all_files.size())
	for info in all_files:
		var tiles_est: int = (info["width"] / TILE) * (info["height"] / TILE)
		print("    %s (%dx%d) ~%d tiles" % [
			info["path"].get_file(),
			info["width"], info["height"], tiles_est])

	if dry:
		print("\n  [DRY RUN] No files written. Run 'Create TileSet' to build.")
		return

	# -- Build TileSet --
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)

	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	ts.add_navigation_layer()
	ts.set_navigation_layer_layers(0, 1)

	var src_id := 0
	var total_tiles := 0

	for info in all_files:
		var tex = load(info["path"]) as Texture2D
		if not tex:
			print("  !! Skipping %s -- can't load" % info["path"].get_file())
			continue

		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(TILE, TILE)

		# FAST: register ALL tile slots, no pixel scanning
		var cols: int = info["width"] / TILE
		var rows: int = info["height"] / TILE
		var count := 0
		for y in range(rows):
			for x in range(cols):
				src.create_tile(Vector2i(x, y))
				count += 1

		ts.add_source(src, src_id)
		total_tiles += count
		print("  [%2d] %s -> %d tiles" % [src_id, info["path"].get_file(), count])
		src_id += 1

	# Save
	var err := ResourceSaver.save(ts, TILESET_PATH)
	if err == OK:
		print("\n  OK Saved %s (%d total tiles across %d sources)" % [
			TILESET_PATH, total_tiles, all_files.size()])
		print("  -> Add TileMapLayers, assign this TileSet, and paint!")
	else:
		print("  FAIL Save failed: %s" % error_string(err))


## --- HELPERS ------------------------------------------------

func _scan_dir_for_pngs(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		print("  !! Can't open directory: %s" % dir_path)
		return results

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			results.append_array(_scan_dir_for_pngs(full_path))
		elif file_name.to_lower().ends_with(".png"):
			results.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


func _check_png(path: String) -> Dictionary:
	var tex = load(path) as Texture2D
	if not tex:
		return {}

	var img: Image = tex.get_image()
	if not img:
		return {}

	var w := img.get_width()
	var h := img.get_height()

	# Skip tiny PNGs (individual tiles, not sheets)
	if w < MIN_SHEET_WIDTH or h < MIN_SHEET_HEIGHT:
		return {}

	# Skip PNGs that don't align to 32px grid
	if w % TILE != 0 or h % TILE != 0:
		print("  !! Skipping %s -- dimensions %dx%d don't align to %dpx grid" % [
			path.get_file(), w, h, TILE])
		return {}

	return {
		"path": path,
		"width": w,
		"height": h,
	}
