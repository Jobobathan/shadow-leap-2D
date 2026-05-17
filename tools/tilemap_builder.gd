@tool
extends Node2D
## ═══════════════════════════════════════════════════════════════
## TileMap Builder for Shadow Leap 2D
## ═══════════════════════════════════════════════════════════════
## Converts flat PNG building system to Godot TileMap system.
##
## WORKFLOW (run each step in order via inspector checkboxes):
##   1. build_tileset  → Scans colonial.png + roofs.png, creates TileSet
##   2. build_level    → Creates TileMapLayers, paints 4 buildings
##   3. cleanup_legacy → Removes old building sprites/nav/grid nodes
##   4. Save scene, delete this Builder node, re-save
##   5. Polish ground/decorations in Godot's TileMap editor
##
## See TILEMAP_BUILD_GUIDE.md for full instructions.
## ═══════════════════════════════════════════════════════════════

const TILE := 32
const TILESET_PATH := "res://resources/town_tileset.tres"

# ─── Source IDs in TileSet ─────────────────────────────────
const SRC_COLONIAL := 0
const SRC_ROOFS := 1

# ─── Colonial terrain autotile origins (3×3 blocks) ───────
# Pattern: TL(+0,+0) Top(+1,+0) TR(+2,+0)
#          L (+0,+1) Fill(+1,+1) R (+2,+1)
#          BL(+0,+2) Bot(+1,+2) BR(+2,+2)
const TERRAINS = {
	"brick_red":   Vector2i(0, 0),
	"brick_white": Vector2i(0, 5),
	"wood_blue":   Vector2i(25, 1),
	"wood_green":  Vector2i(25, 8),
}

const WINDOWS = {
	"brick_dark":  Vector2i(8, 14),
	"brick_light": Vector2i(0, 14),
	"wood_dark":   Vector2i(21, 18),
}

const DOORS = {
	"red_brick": Vector2i(4, 11),
	"dark":      Vector2i(24, 15),
	"darkest":   Vector2i(30, 17),
}

const DOOR_FRAMES = {
	"red_brick": Vector2i(4, 10),
	"dark":      Vector2i(24, 14),
	"darkest":   Vector2i(30, 16),
}

# Roof variant column offsets in roofs.png (32px grid)
const V_DARK  = 0   # purple-gray
const V_DARK2 = 35  # blue-gray


# ─── Inspector triggers ───────────────────────────────────

@export var build_tileset: bool = false:
	set(v):
		if v and Engine.is_editor_hint():
			_build_tileset()
		build_tileset = false

@export var build_level: bool = false:
	set(v):
		if v and Engine.is_editor_hint():
			_build_level()
		build_level = false

@export var cleanup_legacy: bool = false:
	set(v):
		if v and Engine.is_editor_hint():
			_cleanup_legacy()
		cleanup_legacy = false


# ═══════════════════════════════════════════════════════════
# PHASE 1: BUILD TILESET
# ═══════════════════════════════════════════════════════════

func _build_tileset() -> void:
	print("\n[TileMapBuilder] ═══ Phase 1: Building TileSet ═══")

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)

	# Physics layer 0: solid walls (collision layer 1, no mask)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	# Navigation layer 0: walkable areas
	ts.add_navigation_layer()
	ts.set_navigation_layer_layers(0, 1)

	# Source 0: colonial.png (walls, windows, doors)
	var col_src := TileSetAtlasSource.new()
	col_src.texture = load("res://sprites/colonial.png")
	col_src.texture_region_size = Vector2i(TILE, TILE)
	var col_n := _register_tiles(col_src)
	ts.add_source(col_src, SRC_COLONIAL)
	print("  colonial.png: %d tiles" % col_n)

	# Source 1: roofs.png (roof tiles, chimneys)
	var roof_src := TileSetAtlasSource.new()
	roof_src.texture = load("res://sprites/roofs.png")
	roof_src.texture_region_size = Vector2i(TILE, TILE)
	var roof_n := _register_tiles(roof_src)
	ts.add_source(roof_src, SRC_ROOFS)
	print("  roofs.png: %d tiles" % roof_n)

	# Add collision to wall tiles
	_add_wall_physics(col_src)

	# Save
	var err := ResourceSaver.save(ts, TILESET_PATH)
	if err == OK:
		print("  ✓ Saved %s" % TILESET_PATH)
	else:
		push_error("  ✗ Save failed: " + error_string(err))


func _register_tiles(src: TileSetAtlasSource) -> int:
	"""Scan texture for non-empty 32×32 tiles and register them."""
	var img := src.texture.get_image()
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
	"""Check if a tile region has any non-transparent pixels."""
	var x0 := gx * TILE
	var y0 := gy * TILE
	# Quick center/corner sample first
	for s in [Vector2i(16, 16), Vector2i(0, 0), Vector2i(31, 31),
	          Vector2i(0, 31), Vector2i(31, 0)]:
		if img.get_pixel(x0 + s.x, y0 + s.y).a > 0.01:
			return true
	# Full scan for edge-only content
	for py in range(TILE):
		for px in range(TILE):
			if img.get_pixel(x0 + px, y0 + py).a > 0.01:
				return true
	return false


func _add_wall_physics(src: TileSetAtlasSource) -> void:
	"""Add full-tile collision rectangles to all wall/window/door tiles."""
	var h := float(TILE) / 2.0
	var rect := PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)
	])

	var coords: Array[Vector2i] = []

	# All 3×3 terrain blocks
	for origin in TERRAINS.values():
		for dy in range(3):
			for dx in range(3):
				coords.append(origin + Vector2i(dx, dy))

	# Windows, doors, door frames
	for v in WINDOWS.values():
		coords.append(v)
	for v in DOORS.values():
		coords.append(v)
	for v in DOOR_FRAMES.values():
		coords.append(v)

	var n := 0
	for coord in coords:
		if src.has_tile(coord):
			var td := src.get_tile_data(coord, 0)
			td.set_collision_polygons_count(0, 1)
			td.set_collision_polygon_points(0, 0, rect)
			n += 1

	print("  Physics: %d wall tiles with collision" % n)


# ═══════════════════════════════════════════════════════════
# PHASE 2: BUILD LEVEL
# ═══════════════════════════════════════════════════════════

func _build_level() -> void:
	print("\n[TileMapBuilder] ═══ Phase 2: Building Level ═══")

	var ts: TileSet = load(TILESET_PATH)
	if not ts:
		push_error("  TileSet not found! Run build_tileset first.")
		return

	var root := get_parent()
	if not root:
		push_error("  Builder must be a child of the scene root!")
		return

	# Remove any existing TileMapLayers (for re-runs)
	for child in root.get_children():
		if child is TileMapLayer:
			child.free()

	# Create 4 layers:
	#   WallLayer      (z=-3) — wall tiles with collision
	#   WallOverlay    (z=-2) — door frames (alpha overlay, no collision)
	#   RoofLayer      (z=-1) — roof tiles
	#   RoofOverlay    (z= 0) — chimneys (alpha overlay on roof)
	var wall_layer    := _make_layer(root, "WallLayer", ts, -3)
	var wall_overlay  := _make_layer(root, "WallOverlay", ts, -2, false)
	var roof_layer    := _make_layer(root, "RoofLayer", ts, -1)
	var roof_overlay  := _make_layer(root, "RoofOverlay", ts, 0, false)

	# Paint all 4 buildings
	_paint_bld1(wall_layer, wall_overlay, roof_layer, roof_overlay)
	_paint_bld2(wall_layer, wall_overlay, roof_layer, roof_overlay)
	_paint_bld3(wall_layer, wall_overlay, roof_layer, roof_overlay)
	_paint_bld4(wall_layer, wall_overlay, roof_layer, roof_overlay)

	print("  ✓ 4 buildings painted on TileMapLayers")
	print("  NOTE: Ground is empty — paint it in Godot's TileMap editor (Phase 4)")
	print("  NOTE: Add terrain_v7.png as TileSet source for ground tiles")


func _make_layer(parent: Node, lname: String, ts: TileSet,
                 z: int, collision: bool = true) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = lname
	layer.tile_set = ts
	layer.z_index = z
	if not collision:
		layer.collision_enabled = false
	parent.add_child(layer)
	layer.owner = get_tree().edited_scene_root
	return layer


# ─── Wall painter ──────────────────────────────────────────

func _paint_walls(layer: TileMapLayer, org: Vector2i,
                  terrain: String, w: int, wins: Array,
                  door_col: int, win_key: String, door_key: String,
                  extra_rows: int = 0) -> int:
	"""Paint wall tile grid. Returns number of rows painted."""
	var wc: Vector2i = TERRAINS[terrain]
	var wn: Vector2i = WINDOWS[win_key]
	var dr: Vector2i = DOORS[door_key]
	var row := 0

	# Row 0: top edge
	for c in range(w):
		var t: Vector2i
		if c == 0:       t = wc + Vector2i(0, 0)  # TL
		elif c == w - 1: t = wc + Vector2i(2, 0)  # TR
		else:            t = wc + Vector2i(1, 0)  # Top
		layer.set_cell(org + Vector2i(c, row), SRC_COLONIAL, t)
	row += 1

	# Fill rows (with optional windows)
	for fi in range(2 + extra_rows):
		for c in range(w):
			var is_win := false
			for wp in wins:
				if c == int(wp.x) and fi == int(wp.y):
					is_win = true
					break
			var t: Vector2i
			if is_win:       t = wn
			elif c == 0:     t = wc + Vector2i(0, 1)  # L
			elif c == w - 1: t = wc + Vector2i(2, 1)  # R
			else:            t = wc + Vector2i(1, 1)  # Fill
			layer.set_cell(org + Vector2i(c, row), SRC_COLONIAL, t)
		row += 1

	# Bottom row (with door)
	for c in range(w):
		var t: Vector2i
		if c == door_col:  t = dr
		elif c == 0:       t = wc + Vector2i(0, 2)  # BL
		elif c == w - 1:   t = wc + Vector2i(2, 2)  # BR
		else:              t = wc + Vector2i(1, 2)  # Bot
		layer.set_cell(org + Vector2i(c, row), SRC_COLONIAL, t)
	row += 1

	return row


# ─── Roof painter ──────────────────────────────────────────

func _paint_roof(layer: TileMapLayer, org: Vector2i, layout: Array) -> void:
	"""Paint roof tiles from a 2D layout array (null = skip)."""
	for ri in range(layout.size()):
		var row_data: Array = layout[ri]
		for ci in range(row_data.size()):
			if row_data[ci] != null:
				layer.set_cell(org + Vector2i(ci, ri), SRC_ROOFS, row_data[ci])


# ═══════════════════════════════════════════════════════════
# BUILDING RECIPES (from compose_buildings_v3.py)
# ═══════════════════════════════════════════════════════════
# Building positions in tile grid coordinates (top-left corner).
# Viewport = 1280×720 = 40×22.5 tiles.
# Buildings placed in 4 quadrants like the original layout.
# ═══════════════════════════════════════════════════════════

func _paint_bld1(wl: TileMapLayer, wo_l: TileMapLayer,
                 rl: TileMapLayer, ro_l: TileMapLayer) -> void:
	## Building 1: 3-wide Gable, brick_red — lower-left quadrant
	## Original: pixel (180, 640), 3×8 tiles
	var pos := Vector2i(4, 14)
	var V := V_DARK

	# Roof (5 rows)
	_paint_roof(rl, pos, [
		[null,              Vector2i(V+2, 0),  null],
		[Vector2i(V+0, 2), Vector2i(V+2, 1),  Vector2i(V+4, 2)],
		[Vector2i(V+0, 3), Vector2i(V+2, 2),  Vector2i(V+4, 3)],
		[Vector2i(V+0, 4), Vector2i(V+2, 3),  Vector2i(V+4, 4)],
		[Vector2i(V+0, 5), Vector2i(V+2, 4),  Vector2i(V+4, 5)],
	])

	# Wall (overlap=1 → starts at roof row 4)
	var wall_org := pos + Vector2i(0, 4)
	_paint_walls(wl, wall_org, "brick_red", 3,
		[Vector2i(1, 0)], 1, "brick_dark", "red_brick")

	# Door frame overlay (on fill row above door)
	wo_l.set_cell(wall_org + Vector2i(1, 2), SRC_COLONIAL, DOOR_FRAMES["red_brick"])

	# Chimney overlay on roof
	ro_l.set_cell(pos + Vector2i(2, 1), SRC_ROOFS, Vector2i(3, 6))

	print("  Bld1: brick_red gable @ %s (3×8)" % str(pos))


func _paint_bld2(wl: TileMapLayer, wo_l: TileMapLayer,
                 rl: TileMapLayer, ro_l: TileMapLayer) -> void:
	## Building 2: 4-wide Gable, wood_blue — upper-left quadrant
	## Original: pixel (180, 120), 4×8 tiles
	var pos := Vector2i(3, 1)
	var V := V_DARK2

	_paint_roof(rl, pos, [
		[null,              Vector2i(V+1, 1), Vector2i(V+3, 1), null],
		[Vector2i(V+0, 2), Vector2i(V+1, 2), Vector2i(V+3, 2), Vector2i(V+4, 2)],
		[Vector2i(V+0, 3), Vector2i(V+1, 3), Vector2i(V+3, 3), Vector2i(V+4, 3)],
		[Vector2i(V+0, 4), Vector2i(V+1, 4), Vector2i(V+3, 4), Vector2i(V+4, 4)],
		[Vector2i(V+0, 5), Vector2i(V+1, 5), Vector2i(V+3, 5), Vector2i(V+4, 5)],
	])

	var wall_org := pos + Vector2i(0, 4)
	_paint_walls(wl, wall_org, "wood_blue", 4,
		[Vector2i(1, 0), Vector2i(2, 0)], 1, "wood_dark", "dark")

	wo_l.set_cell(wall_org + Vector2i(1, 2), SRC_COLONIAL, DOOR_FRAMES["dark"])
	ro_l.set_cell(pos + Vector2i(0, 1), SRC_ROOFS, Vector2i(38, 6))

	print("  Bld2: wood_blue gable @ %s (4×8)" % str(pos))


func _paint_bld3(wl: TileMapLayer, wo_l: TileMapLayer,
                 rl: TileMapLayer, ro_l: TileMapLayer) -> void:
	## Building 3: 5-wide Hipped, brick_white — upper-right quadrant
	## Original: pixel (1020, 120), 5×8 tiles (with extra fill row)
	var pos := Vector2i(28, 1)
	var V := V_DARK

	_paint_roof(rl, pos, [
		[Vector2i(V+1, 9),  Vector2i(V+1, 15), Vector2i(V+2, 15), Vector2i(V+3, 15), Vector2i(V+3, 9)],
		[Vector2i(V+1, 10), Vector2i(V+1, 17), Vector2i(V+2, 17), Vector2i(V+3, 17), Vector2i(V+3, 10)],
		[Vector2i(V+1, 11), Vector2i(V+2, 11), Vector2i(V+2, 11), Vector2i(V+2, 11), Vector2i(V+3, 11)],
	])

	# No overlap for hipped roof
	var wall_org := pos + Vector2i(0, 3)
	_paint_walls(wl, wall_org, "brick_white", 5,
		[Vector2i(1, 0), Vector2i(3, 0)], 2, "brick_light", "dark", 1)

	wo_l.set_cell(wall_org + Vector2i(2, 3), SRC_COLONIAL, DOOR_FRAMES["dark"])
	ro_l.set_cell(pos + Vector2i(4, 0), SRC_ROOFS, Vector2i(2, 12))

	print("  Bld3: brick_white hipped @ %s (5×8)" % str(pos))


func _paint_bld4(wl: TileMapLayer, wo_l: TileMapLayer,
                 rl: TileMapLayer, ro_l: TileMapLayer) -> void:
	## Building 4: 5-wide Steep Hipped, wood_green — lower-right quadrant
	## Original: pixel (1020, 640), 5×9 tiles (with extra fill row)
	var pos := Vector2i(28, 13)
	var V := V_DARK2

	_paint_roof(rl, pos, [
		[Vector2i(V+0, 13), Vector2i(V+1, 15), Vector2i(V+2, 15), Vector2i(V+3, 15), Vector2i(V+4, 13)],
		[Vector2i(V+0, 14), Vector2i(V+1, 17), Vector2i(V+2, 17), Vector2i(V+3, 17), Vector2i(V+4, 14)],
		[Vector2i(V+0, 15), Vector2i(V+2, 11), Vector2i(V+2, 11), Vector2i(V+2, 11), Vector2i(V+4, 15)],
		[Vector2i(V+0, 16), Vector2i(V+2, 11), Vector2i(V+2, 11), Vector2i(V+2, 11), Vector2i(V+4, 16)],
	])

	var wall_org := pos + Vector2i(0, 4)
	_paint_walls(wl, wall_org, "wood_green", 5,
		[Vector2i(1, 0), Vector2i(3, 0)], 2, "wood_dark", "darkest", 1)

	wo_l.set_cell(wall_org + Vector2i(2, 3), SRC_COLONIAL, DOOR_FRAMES["darkest"])
	ro_l.set_cell(pos + Vector2i(0, 0), SRC_ROOFS, Vector2i(37, 12))

	print("  Bld4: wood_green steep hipped @ %s (5×9)" % str(pos))


# ═══════════════════════════════════════════════════════════
# PHASE 3: CLEANUP LEGACY NODES
# ═══════════════════════════════════════════════════════════

func _cleanup_legacy() -> void:
	print("\n[TileMapBuilder] ═══ Phase 3: Cleanup Legacy ═══")

	var root := get_parent()
	if not root:
		return

	var to_remove := [
		# Old environment nodes (replaced by TileMapLayers)
		"Ground",              # Sprite2D with tiled ground_tile.png
		"GridOverlay",         # grid_drawer.gd (TileMap IS the grid now)
		"House1",              # StaticBody2D + building_1.png
		"House2",              # StaticBody2D + building_2.png
		"House3",              # StaticBody2D + building_3.png
		"House4",              # StaticBody2D + building_4.png
		"NavigationRegion2D",  # nav_builder.gd (TileSet nav layer replaces)
	]

	for node_name in to_remove:
		var node := root.get_node_or_null(node_name)
		if node:
			node.free()
			print("  ✓ Removed: %s" % node_name)
		else:
			print("  – Skip (not found): %s" % node_name)

	print("")
	print("  KEPT: Cover objects (Rock1, Barrel, Rock2) — individual gameplay props")
	print("  KEPT: Trees, Fountain, Foodogs, ParkedCar — individual decorative sprites")
	print("  KEPT: All entities (Kage, Akari, demons) — no changes needed")
	print("  KEPT: All managers, Camera, UI, atmosphere")
	print("")
	print("  MANUAL CLEANUP (after verifying in editor):")
	print("    • Delete sprites/building_1-4.png (no longer needed)")
	print("    • Delete scripts/nav_builder.gd")
	print("    • Delete scripts/grid_drawer.gd")
	print("    • Delete tools/compose_buildings*.py")
	print("    • Delete this Builder node")
