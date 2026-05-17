@tool
extends Node2D
## ═══════════════════════════════════════════════════════════════
## TileSet Creator v2 — Auto-scanning, Auto-upscaling
## ═══════════════════════════════════════════════════════════════
## Scans tileset directories for PNGs, auto-detects 16px sheets
## and upscales them to 32px with nearest-neighbor. Creates a
## single TileSet resource with all sources registered.
##
## Usage:
##   1. Drop your tileset PNGs into the scan directories below
##   2. Add this as a child Node2D in your scene
##   3. Click "Create TileSet" in the inspector
##   4. Delete this node after TileSet is created
##   5. Add TileMapLayers, assign the TileSet, paint!
##
## Supports:
##   - 32×32 native tilesets (used as-is)
##   - 16×16 tilesets (auto-upscaled 2× nearest-neighbor)
##   - Mixed directories (each PNG detected individually)
## ═══════════════════════════════════════════════════════════════

const TILE := 32
const TILESET_PATH := "res://resources/city_tileset.tres"
const UPSCALE_DIR := "res://sprites/tilesets/limezu/upscaled_32px/"

## ─── SCAN DIRECTORIES ───────────────────────────────────────
## Every PNG found in these dirs gets registered as an atlas source.
## Add more directories as you buy more packs.
var SCAN_DIRS: Array[String] = [
	"res://sprites/tilesets/limezu/",
	"res://sprites/tilesets/sakura/",
	# Add more pack directories here:
	# "res://sprites/tilesets/japanese_shrine/",
	# "res://sprites/tilesets/desert/",
]

## ─── EXPLICIT SOURCES (optional) ────────────────────────────
## Pin specific files to specific source IDs if you want stable IDs.
## These are registered FIRST, then scanned files fill remaining slots.
## Set to {} to skip and let everything auto-assign.
var PINNED: Dictionary = {
	# Example: 0: "res://sprites/tilesets/limezu/modern_exteriors.png",
}

## ─── FORCE 16px MODE ────────────────────────────────────────
## Directories listed here are ALWAYS treated as 16px (skip detection).
## Useful if a sheet happens to have dimensions divisible by 32 but is
## actually 16px art.
var FORCE_16PX_DIRS: Array[String] = [
	# "res://sprites/tilesets/limezu/",  # Commented out — LimeZu ships native 32px
]

@export_tool_button("Create TileSet") var _btn = _create_tileset
@export_tool_button("Dry Run (scan only)") var _btn2 = _dry_run


func _create_tileset() -> void:
	_run(false)


func _dry_run() -> void:
	_run(true)


func _run(dry: bool) -> void:
	var label := "DRY RUN" if dry else "Creating TileSet"
	print("\n[TileSetCreator v2] ═══ %s ═══" % label)

	# Ensure upscale output dir exists
	if not dry:
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(UPSCALE_DIR))

	# ── Collect all PNGs ──
	var all_files: Array[Dictionary] = []  # [{path, is_16px, source_path}]

	# Pinned sources first
	for src_id in PINNED:
		var path: String = PINNED[src_id]
		var info := _analyze_png(path)
		if info.size() > 0:
			info["pinned_id"] = src_id
			all_files.append(info)

	# Scan directories
	for dir_path in SCAN_DIRS:
		var pngs := _scan_dir_for_pngs(dir_path)
		for png_path in pngs:
			# Skip if already pinned
			var dominated := false
			for pinned in all_files:
				if pinned["original"] == png_path:
					dominated = true
					break
			if dominated:
				continue
			# Skip upscaled outputs (don't re-process our own output)
			if png_path.contains("upscaled_32px"):
				continue
			var info := _analyze_png(png_path)
			if info.size() > 0:
				all_files.append(info)

	if all_files.is_empty():
		push_warning("[TileSetCreator v2] No PNGs found in scan directories!")
		print("  Scanned: %s" % str(SCAN_DIRS))
		print("  Drop your tileset PNGs into one of those folders.")
		return

	# ── Report ──
	print("\n  Found %d tileset(s):" % all_files.size())
	for info in all_files:
		var scale_tag := " [16px → 32px]" if info["is_16px"] else " [32px native]"
		print("    %s%s (%dx%d)" % [
			info["original"].get_file(), scale_tag,
			info["width"], info["height"]])

	if dry:
		print("\n  [DRY RUN] No files written. Run 'Create TileSet' to build.")
		return

	# ── Upscale 16px sheets ──
	for info in all_files:
		if info["is_16px"]:
			var out_path := _upscale_png(info["original"])
			if out_path != "":
				info["use_path"] = out_path
			else:
				push_warning("  ⚠ Upscale failed for %s, using original" % info["original"])
				info["use_path"] = info["original"]
		else:
			info["use_path"] = info["original"]

	# ── Build TileSet ──
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)

	# Physics layer 0: solid walls/obstacles
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	# Navigation layer 0: walkable areas
	ts.add_navigation_layer()
	ts.set_navigation_layer_layers(0, 1)

	# Register sources
	var next_id := 0
	var total_tiles := 0

	for info in all_files:
		# Determine source ID
		var src_id: int
		if info.has("pinned_id"):
			src_id = info["pinned_id"]
		else:
			# Find next unused ID
			while ts.has_source(next_id):
				next_id += 1
			src_id = next_id
			next_id += 1

		var use_path: String = info["use_path"]

		# Force reimport if we just created the upscaled file
		var tex = load(use_path)
		if not tex:
			# If upscaled file isn't imported yet, try the original
			push_warning("  ⚠ Can't load %s — Godot may need to reimport. Trying original..." % use_path)
			tex = load(info["original"])
			if not tex:
				push_warning("  ⚠ Skipping %s — can't load texture" % info["original"])
				continue
			# If using original 16px, set region size to 16
			var src16 := TileSetAtlasSource.new()
			src16.texture = tex
			src16.texture_region_size = Vector2i(16, 16)
			# Note: tiles will paint at 32px grid but texture region is 16px
			# Godot will scale them up automatically in the TileMap
			var n := _register_tiles_sized(src16, info["original"], 16)
			ts.add_source(src16, src_id)
			total_tiles += n
			var tag := " [16px — upscaled file needs reimport, using original]"
			print("  [%2d] %s → %d tiles%s" % [src_id, info["original"].get_file(), n, tag])
			continue

		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(TILE, TILE)

		var n := _register_tiles_sized(src, use_path, TILE)
		ts.add_source(src, src_id)
		total_tiles += n

		var scale_tag := " [upscaled]" if info["is_16px"] else ""
		print("  [%2d] %s → %d tiles%s" % [src_id, use_path.get_file(), n, scale_tag])

	# Save
	var err := ResourceSaver.save(ts, TILESET_PATH)
	if err == OK:
		print("\n  ✓ Saved %s (%d total tiles across %d sources)" % [
			TILESET_PATH, total_tiles, all_files.size()])
		print("  → Add TileMapLayers, assign this TileSet, and paint!")
	else:
		push_error("  ✗ Save failed: %s" % error_string(err))


## ─── HELPERS ────────────────────────────────────────────────

func _scan_dir_for_pngs(dir_path: String) -> Array[String]:
	"""Recursively find all .png files in a directory."""
	var results: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		print("  ⚠ Can't open directory: %s" % dir_path)
		return results

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recurse into subdirectories
			results.append_array(_scan_dir_for_pngs(full_path))
		elif file_name.to_lower().ends_with(".png"):
			results.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


func _analyze_png(path: String) -> Dictionary:
	"""Load a PNG and determine if it's 16px or 32px."""
	var tex = load(path) as Texture2D
	if not tex:
		push_warning("  ⚠ Could not load: %s" % path)
		return {}

	var img: Image = tex.get_image()
	if not img:
		push_warning("  ⚠ get_image() null: %s" % path)
		return {}

	var w := img.get_width()
	var h := img.get_height()

	# Determine if 16px
	var is_16px := false

	# Check if directory is in FORCE_16PX list
	for force_dir in FORCE_16PX_DIRS:
		if path.begins_with(force_dir):
			is_16px = true
			break

	# Auto-detect: if dimensions work cleanly with 16 but NOT 32,
	# it's likely 16px. If both work, check for force list or default 32.
	if not is_16px:
		var fits_32 := (w % 32 == 0) and (h % 32 == 0)
		var fits_16 := (w % 16 == 0) and (h % 16 == 0)
		if fits_16 and not fits_32:
			is_16px = true

	return {
		"original": path,
		"width": w,
		"height": h,
		"is_16px": is_16px,
	}


func _upscale_png(source_path: String) -> String:
	"""Upscale a 16px PNG to 32px with nearest-neighbor. Returns output path."""
	var tex = load(source_path) as Texture2D
	if not tex:
		return ""

	var img: Image = tex.get_image()
	if not img:
		return ""

	if img.is_compressed():
		img.decompress()

	# Nearest-neighbor 2× upscale
	var new_w := img.get_width() * 2
	var new_h := img.get_height() * 2
	img.resize(new_w, new_h, Image.INTERPOLATE_NEAREST)

	# Save to upscale directory
	var out_name := source_path.get_file().get_basename() + "_32px.png"
	var out_path := UPSCALE_DIR.path_join(out_name)
	var global_path := ProjectSettings.globalize_path(out_path)

	var err := img.save_png(global_path)
	if err == OK:
		print("    ↑ Upscaled %s → %s (%dx%d)" % [
			source_path.get_file(), out_name, new_w, new_h])
		return out_path
	else:
		push_error("    ✗ Failed to save upscaled: %s" % error_string(err))
		return ""


func _register_tiles_sized(src: TileSetAtlasSource, path: String, tile_size: int) -> int:
	"""Scan texture for non-empty tiles at given tile size."""
	var tex := src.texture
	if not tex:
		return 0

	var img := tex.get_image()
	if not img:
		return 0

	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var cols := img.get_width() / tile_size
	var rows := img.get_height() / tile_size
	var count := 0

	for y in range(rows):
		for x in range(cols):
			if _has_pixels(img, x, y, tile_size):
				src.create_tile(Vector2i(x, y))
				count += 1
	return count


func _has_pixels(img: Image, gx: int, gy: int, tile_size: int) -> bool:
	"""Quick check: does this tile have any visible pixels?"""
	var x0 := gx * tile_size
	var y0 := gy * tile_size
	var half := tile_size / 2
	var edge := tile_size - 1

	# Sample center + corners first (fast reject)
	for s in [Vector2i(half, half), Vector2i(0, 0), Vector2i(edge, edge),
	          Vector2i(0, edge), Vector2i(edge, 0)]:
		var px := x0 + s.x
		var py := y0 + s.y
		if px < img.get_width() and py < img.get_height():
			if img.get_pixel(px, py).a > 0.01:
				return true

	# Full scan for edge-case tiles
	for py in range(tile_size):
		for px in range(tile_size):
			var ax := x0 + px
			var ay := y0 + py
			if ax < img.get_width() and ay < img.get_height():
				if img.get_pixel(ax, ay).a > 0.01:
					return true
	return false
