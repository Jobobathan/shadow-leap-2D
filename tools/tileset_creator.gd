@tool
extends Node2D
## ═══════════════════════════════════════════════════════════════
## TileSet Creator for Shadow Leap 2D
## ═══════════════════════════════════════════════════════════════
## Phase 1 ONLY: Scans tileset PNGs → creates TileSet resource.
## YOU do the painting in the TileMap editor.
##
## Usage:
##   1. Add this as a child Node2D of Main
##   2. Click "Create TileSet" in the inspector
##   3. Delete this node after TileSet is created
##   4. Add TileMapLayers manually, assign the TileSet
##   5. Paint!
## ═══════════════════════════════════════════════════════════════

const TILE := 32
const TILESET_PATH := "res://resources/town_tileset.tres"

## Atlas sources to register (path → source ID)
## Add more here as needed — just increment the ID
var ATLASES := {
	0:  "res://sprites/colonial.png",         # walls, windows, doors
	1:  "res://sprites/roofs.png",            # roof tiles, chimneys
	2:  "res://sprites/terrain_v7.png",       # ground/terrain
	3:  "res://sprites/tilesets/walls.png",   # LPC wall variants
	4:  "res://sprites/tilesets/bricks.png",  # brick patterns
	5:  "res://sprites/tilesets/victorian-mansion.png",
	6:  "res://sprites/tilesets/victorian-tenement.png",
	7:  "res://sprites/tilesets/victorian-windows-doors.png",
	8:  "res://sprites/tilesets/victorian-accessories.png",
	9:  "res://sprites/tilesets/decorations-medieval.png",
	10: "res://sprites/tilesets/fence_medieval.png",
	11: "res://sprites/tilesets/base_out_atlas.png",
	12: "res://sprites/tilesets/terrain_atlas.png",
	13: "res://sprites/tilesets/blacksmith-smelter.png",
	14: "res://sprites/tilesets/flowers.png",
	15: "res://sprites/tilesets/planters.png",
}

@export_tool_button("Create TileSet") var _btn = _create_tileset


func _create_tileset() -> void:
	print("\n[TileSetCreator] ═══ Creating TileSet ═══")

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)

	# Physics layer 0: solid walls/obstacles
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	# Navigation layer 0: walkable areas
	ts.add_navigation_layer()
	ts.set_navigation_layer_layers(0, 1)

	# Register each atlas source
	var total_tiles := 0
	for src_id in ATLASES:
		var path: String = ATLASES[src_id]
		var tex = load(path)
		if not tex:
			push_warning("  ⚠ Could not load: %s" % path)
			continue

		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(TILE, TILE)

		var n := _register_tiles(src, path)
		ts.add_source(src, src_id)
		total_tiles += n
		print("  [%2d] %s → %d tiles" % [src_id, path.get_file(), n])

	# Save
	var err := ResourceSaver.save(ts, TILESET_PATH)
	if err == OK:
		print("\n  ✓ Saved %s (%d total tiles across %d sources)" % [
			TILESET_PATH, total_tiles, ATLASES.size()])
		print("  → Now add TileMapLayers and start painting!")
	else:
		push_error("  ✗ Save failed: %s" % error_string(err))


func _register_tiles(src: TileSetAtlasSource, path: String) -> int:
	"""Scan texture for non-empty 32×32 tiles."""
	var tex := src.texture
	if not tex:
		push_error("  ✗ Null texture: %s" % path)
		return 0

	var img := tex.get_image()
	if not img:
		push_error("  ✗ get_image() null: %s — may need reimport" % path)
		return 0

	# Decompress for get_pixel() access
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var cols := img.get_width() / TILE
	var rows := img.get_height() / TILE
	var count := 0

	for y in range(rows):
		for x in range(cols):
			if _has_pixels(img, x, y):
				src.create_tile(Vector2i(x, y))
				count += 1
	return count


func _has_pixels(img: Image, gx: int, gy: int) -> bool:
	"""Quick check: does this tile have any visible pixels?"""
	var x0 := gx * TILE
	var y0 := gy * TILE
	# Sample center + corners first (fast reject)
	for s in [Vector2i(16, 16), Vector2i(0, 0), Vector2i(31, 31),
	          Vector2i(0, 31), Vector2i(31, 0)]:
		if img.get_pixel(x0 + s.x, y0 + s.y).a > 0.01:
			return true
	# Full scan only for edge-case tiles
	for py in range(TILE):
		for px in range(TILE):
			if img.get_pixel(x0 + px, y0 + py).a > 0.01:
				return true
	return false
