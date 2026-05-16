extends Node2D
## Builds the full 2D prototype scene from code.
## Uses proper character sprites (kage_lpc, akari_lpc, skeleton_topdown, big_demon_sheet).
## Feature parity with 3D prototype: turn system, engagement zones,
## ARPG combat, ranged, boss AI, camera zoom, party management.


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.06, 0.1))

	_build_ground()
	_build_managers()
	_build_cursor()
	_build_environment()
	_build_navigation()
	_build_atmosphere()
	_build_party()
	_build_enemies()
	_build_camera()
	_build_ui()
	_build_party_manager()


## ─── Ground ───────────────────────────────────────────────

func _build_ground() -> void:
	# Tiled ground using ground_tile.png
	var ground := Sprite2D.new()
	ground.texture = load("res://sprites/ground_tile.png")
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.region_enabled = true
	ground.region_rect = Rect2(0, 0, 3000, 3000)
	ground.position = Vector2(-1500, -1500)
	ground.centered = false
	ground.z_index = -10
	add_child(ground)

	# Subtle grid overlay
	var grid := Node2D.new()
	grid.z_index = -9
	add_child(grid)
	var grid_drawer := GridDrawer.new()
	grid.add_child(grid_drawer)

	# Grass variation patches
	for i in range(20):
		var patch := ColorRect.new()
		patch.color = Color(0.1, 0.13, 0.08, 0.3)
		var s := randf_range(40, 120)
		patch.size = Vector2(s, s)
		patch.position = Vector2(randf_range(-800, 800), randf_range(-800, 800))
		patch.z_index = -9
		add_child(patch)


## ─── Managers (TurnManager + EngagementManager) ──────────

func _build_managers() -> void:
	var tm := Node.new()
	tm.name = "TurnManager"
	tm.set_script(load("res://scripts/turn_manager_2d.gd"))
	add_child(tm)

	var em := Node.new()
	em.name = "EngagementManager"
	em.set_script(load("res://scripts/engagement_manager_2d.gd"))
	add_child(em)


## ─── Tactical Cursor ──────────────────────────────────────

func _build_cursor() -> void:
	var cursor := Node2D.new()
	cursor.name = "TacticalCursor"
	cursor.set_script(load("res://scripts/tactical_cursor_2d.gd"))
	cursor.position = Vector2(550, 580)
	add_child(cursor)


## ─── Party Members ────────────────────────────────────────

func _build_party() -> void:
	# Kage — melee party member (128px LPC composite sprite)
	# NOTE: Kage=128px cells, Akari=64px cells. Different fill ratios.
	# Tune these scales until characters look the same height in-game.
	# Party spawns well south of fountain/foodogs, clear of all props
	var kage := _create_party_member("Kage", Vector2(550, 580), false,
		_build_kage_sprite_frames(), Vector2(1.15, 1.15))
	add_child(kage)

	# Akari — ranged party member (64px LPC composite sprite)
	var akari := _create_party_member("Akari", Vector2(650, 620), true,
		_build_akari_sprite_frames(), Vector2(1.85, 1.85))
	add_child(akari)


func _create_party_member(member_name: String, pos: Vector2, ranged: bool,
		sprite_frames: SpriteFrames, sprite_scale: Vector2) -> CharacterBody2D:
	var member := CharacterBody2D.new()
	member.set_script(load("res://scripts/player_2d.gd"))
	member.name = member_name
	member.position = pos
	member.add_to_group("party_member")
	if ranged:
		member.set("is_ranged", true)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	member.add_child(col)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = sprite_scale
	sprite.sprite_frames = sprite_frames
	member.add_child(sprite)

	return member


## ─── Enemies ──────────────────────────────────────────────

func _build_enemies() -> void:
	var skeleton_frames := _build_skeleton_sprite_frames()

	var demon_positions := [
		Vector2(600, 80),     # N center, above buildings
		Vector2(100, 380),    # W edge, outside town
		Vector2(1100, 380),   # E edge, outside town
	]
	for i in range(demon_positions.size()):
		var demon := _create_small_demon("SmallDemon_%d" % i, demon_positions[i], skeleton_frames)
		add_child(demon)

	# Big demon (boss) — proper big_demon_sheet sprite
	var boss := _create_big_demon("BigDemon", Vector2(600, -80))
	add_child(boss)


func _create_small_demon(demon_name: String, pos: Vector2, skeleton_frames: SpriteFrames) -> CharacterBody2D:
	var demon := CharacterBody2D.new()
	demon.set_script(load("res://scripts/small_demon_ai_2d.gd"))
	demon.name = demon_name
	demon.position = pos

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	demon.add_child(col)

	var nav_agent := NavigationAgent2D.new()
	nav_agent.name = "NavigationAgent2D"
	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = 8.0
	demon.add_child(nav_agent)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.0, 2.0)
	sprite.sprite_frames = skeleton_frames
	demon.add_child(sprite)

	return demon


func _create_big_demon(demon_name: String, pos: Vector2) -> CharacterBody2D:
	var demon := CharacterBody2D.new()
	demon.set_script(load("res://scripts/big_demon_ai_2d.gd"))
	demon.name = demon_name
	demon.position = pos

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	col.shape = shape
	demon.add_child(col)

	var nav_agent := NavigationAgent2D.new()
	nav_agent.name = "NavigationAgent2D"
	nav_agent.path_desired_distance = 12.0
	nav_agent.target_desired_distance = 12.0
	demon.add_child(nav_agent)

	# Boss: proper big_demon_sheet.png at 2.5x scale
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.5, 2.5)
	sprite.sprite_frames = _build_big_demon_sprite_frames()
	demon.add_child(sprite)

	return demon


## ─── Environment (Town Scene — Modern Japan + Veil) ──────
## Asset regions from ASSET_REGIONS_REPORT.md (±16px, snap to 32px grid in editor)
## All env sprites at 2x scale to match LPC character scale (64px chars at 2.0x = 128px)

func _build_environment() -> void:
	# Buildings at 1.5x (was 2.0x — buildings dwarfed characters)
	var ENV_SCALE := Vector2(1.5, 1.5)
	var light_tex := _make_light_texture()

	# Pre-composed building textures (walls + windows + roofs baked in)
	var bld1_tex := load("res://sprites/building_1.png") as Texture2D
	var bld2_tex := load("res://sprites/building_2.png") as Texture2D
	var bld3_tex := load("res://sprites/building_3.png") as Texture2D
	var bld4_tex := load("res://sprites/building_4.png") as Texture2D
	var rocks_tex := load("res://sprites/rocks.png") as Texture2D
	var barrels_tex := load("res://sprites/barrels.png") as Texture2D
	var fountain_tex := load("res://sprites/fountain_large.png") as Texture2D
	var fountain_shadow_tex := load("res://sprites/fountain_large_shadow.png") as Texture2D
	var foodog_tex := load("res://sprites/foodog.png") as Texture2D
	var foodog_shadow_tex := load("res://sprites/foodog_shadow.png") as Texture2D
	var conifers_tex := load("res://sprites/conifers.png") as Texture2D

	# ─── 4 Buildings (matching 3D prototype layout) ─────────
	# Play area: party ~(500,400), boss ~(700,150), combat ~(350-900, 100-700)
	# Houses at corners, cover in between

	# House 1 — Small gray stone, SW corner
	_create_building("House1", Vector2(180, 640),
		bld1_tex, ENV_SCALE, Color(0.6, 0.65, 0.8), light_tex, 1)

	# House 2 — Small cream/tan, NW corner
	_create_building("House2", Vector2(180, 120),
		bld2_tex, ENV_SCALE, Color(0.7, 0.75, 0.85), light_tex, 1)

	# House 3 — Large tan, NE corner
	_create_building("House3", Vector2(1020, 120),
		bld3_tex, ENV_SCALE, Color(0.5, 0.55, 0.65), light_tex, 2)

	# House 4 — Large dark, SE corner
	_create_building("House4", Vector2(1020, 640),
		bld4_tex, ENV_SCALE, Color(0.55, 0.7, 0.6), light_tex, 2)

	# ─── 3 Cover Objects (tactical gameplay) ────────────────

	# Large gray boulder — west side of play area
	_create_cover("Cover_Rock1", Vector2(350, 450),
		rocks_tex, Rect2(384, 0, 128, 128), ENV_SCALE,
		Vector2(120, 90))

	# Wooden barrel stack — east side of play area
	_create_cover("Cover_Barrel", Vector2(850, 350),
		barrels_tex, Rect2(0, 0, 32, 64), Vector2(2.5, 2.5),
		Vector2(50, 75))

	# Small boulder cluster — north of fountain
	_create_cover("Cover_Rock2", Vector2(450, 180),
		rocks_tex, Rect2(0, 0, 96, 96), ENV_SCALE,
		Vector2(90, 60))

	# ─── Town Center (fountain + foodog guardians) ──────────
	# Fountain at true center of play area, well clear of party spawn
	var town_center := Vector2(600, 330)
	var PROP_SCALE := Vector2(1.5, 1.5)  # Props match building scale

	# Fountain shadow
	_place_sprite("FountainShadow", town_center + Vector2(4, 6),
		fountain_shadow_tex, Rect2(0, 0, 64, 64), PROP_SCALE, Color.WHITE, -2)
	# Fountain
	_place_sprite("Fountain", town_center,
		fountain_tex, Rect2(0, 0, 64, 64), PROP_SCALE, Color.WHITE, 0)
	# Fountain glow
	var f_light := PointLight2D.new()
	f_light.position = town_center
	f_light.color = Color(0.5, 0.7, 1.0)
	f_light.energy = 0.3
	f_light.texture = light_tex
	f_light.texture_scale = 3.0
	add_child(f_light)

	# Foodog guardians — flanking east/west of fountain, wide apart
	for side in [-1, 1]:
		var dog_pos := town_center + Vector2(side * 160, 10)
		_place_sprite("FoodogShadow%d" % [side], dog_pos + Vector2(3, 4),
			foodog_shadow_tex, Rect2(0, 0, 64, 96), PROP_SCALE, Color.WHITE, -2)
		var dog := _place_sprite("Foodog%d" % [side], dog_pos,
			foodog_tex, Rect2(0, 0, 64, 96), PROP_SCALE, Color.WHITE, 0)
		if side == 1:
			dog.flip_h = true  # Face each other

	# ─── Trees (conifers at perimeter) ──────────────────────
	var large_tree := Rect2(896, 0, 128, 192)
	var small_tree := Rect2(256, 0, 64, 128)
	var tree_data := [
		{"pos": Vector2(60, 60), "rect": large_tree},
		{"pos": Vector2(60, 700), "rect": large_tree},
		{"pos": Vector2(1140, 60), "rect": large_tree},
		{"pos": Vector2(1140, 700), "rect": small_tree},
		{"pos": Vector2(600, -20), "rect": small_tree},
	]
	for i in range(tree_data.size()):
		_place_sprite("Tree_%d" % i, tree_data[i]["pos"],
			conifers_tex, tree_data[i]["rect"], ENV_SCALE,
			Color(0.7, 0.8, 0.7), 1)

	# ─── Parked car (modern setting detail, background) ─────
	var car_tex := load("res://sprites/car_parked.png") as Texture2D
	var car := Sprite2D.new()
	car.name = "ParkedCar"
	car.texture = car_tex
	car.position = Vector2(70, 420)
	car.scale = Vector2(1.0, 1.0)
	car.modulate = Color(0.5, 0.55, 0.65, 0.7)  # Faded, Veil-dimmed
	car.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	car.z_index = -3
	add_child(car)


## ─── Building Factory ─────────────────────────────────────

func _create_building(bld_name: String, pos: Vector2,
		tex: Texture2D, bld_scale: Vector2,
		tint: Color, light_tex: Texture2D, win_count: int) -> void:
	var building := StaticBody2D.new()
	building.name = bld_name
	building.position = pos
	add_child(building)

	# Building sprite (pre-composed: walls + windows + roof)
	var wall := Sprite2D.new()
	wall.texture = tex
	wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall.scale = bld_scale
	wall.modulate = tint
	wall.z_index = -2
	building.add_child(wall)

	# Collision — lower 60% of building (roof overhangs above)
	var visual_w := tex.get_width() * bld_scale.x
	var visual_h := tex.get_height() * bld_scale.y
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(visual_w, visual_h * 0.6)
	col.shape = shape
	col.position = Vector2(0, visual_h * 0.2)
	building.add_child(col)

	# Warm glow lights for lit windows (baked into texture)
	for w in range(win_count):
		var x_off := (w - (win_count - 1) / 2.0) * 50.0
		var light := PointLight2D.new()
		light.position = Vector2(x_off, visual_h * 0.1)
		light.color = Color(1.0, 0.69, 0.38)  # Warm orange (#FFB060)
		light.energy = 0.5
		light.texture = light_tex
		light.texture_scale = 2.5
		building.add_child(light)

	# Ground shadow
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.25)
	shadow.size = Vector2(visual_w + 16, 12)
	shadow.position = Vector2(-visual_w / 2.0 - 8, visual_h / 2.0 - 4)
	shadow.z_index = -3
	building.add_child(shadow)


## ─── Cover Object Factory ─────────────────────────────────

func _create_cover(cover_name: String, pos: Vector2,
		tex: Texture2D, region: Rect2, cover_scale: Vector2,
		collision_size: Vector2) -> void:
	var cover := StaticBody2D.new()
	cover.name = cover_name
	cover.position = pos
	add_child(cover)

	var sprite := Sprite2D.new()
	sprite.texture = _atlas_tex(tex, region)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = cover_scale
	cover.add_child(sprite)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = collision_size
	col.shape = shape
	cover.add_child(col)

	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.size = Vector2(collision_size.x + 10, 8)
	shadow.position = Vector2(-collision_size.x / 2.0 - 5, collision_size.y / 2.0 - 2)
	shadow.z_index = -1
	cover.add_child(shadow)


## ─── Sprite & Texture Helpers ─────────────────────────────

func _place_sprite(spr_name: String, pos: Vector2,
		tex: Texture2D, region: Rect2, spr_scale: Vector2,
		tint: Color, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = spr_name
	sprite.texture = _atlas_tex(tex, region)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = pos
	sprite.scale = spr_scale
	sprite.modulate = tint
	sprite.z_index = z
	add_child(sprite)
	return sprite


func _atlas_tex(tex: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	atlas.filter_clip = true
	return atlas


func _make_light_texture() -> Texture2D:
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color.WHITE)
	grad.gradient.set_color(1, Color(1, 1, 1, 0))
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(0.5, 0.0)
	grad.width = 128
	grad.height = 128
	return grad


## ─── Navigation (Pathfinding) ─────────────────────────────

func _build_navigation() -> void:
	var nav_region := NavigationRegion2D.new()
	nav_region.name = "NavigationRegion"
	add_child(nav_region)

	var nav_poly := NavigationPolygon.new()

	# Define walkable area as a set of polygons around obstacles
	# Using direct vertex + polygon approach instead of deprecated outlines
	var walkable_verts := PackedVector2Array()
	var walkable_indices := PackedInt32Array()

	# Simple approach: define outer boundary vertices
	var bounds := Rect2(-200, -250, 1600, 1150)  # Full play area

	# Add outer quad (2 triangles)
	walkable_verts.append(Vector2(bounds.position.x, bounds.position.y))  # 0: top-left
	walkable_verts.append(Vector2(bounds.end.x, bounds.position.y))       # 1: top-right
	walkable_verts.append(Vector2(bounds.end.x, bounds.end.y))            # 2: bottom-right
	walkable_verts.append(Vector2(bounds.position.x, bounds.end.y))       # 3: bottom-left

	nav_poly.vertices = walkable_verts
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2]))
	nav_poly.add_polygon(PackedInt32Array([0, 2, 3]))

	nav_region.navigation_polygon = nav_poly
	print("[Navigation] Nav mesh created: %d verts, %d polygons" % [nav_poly.vertices.size(), nav_poly.get_polygon_count()])


func _add_nav_obstacle(nav_poly: NavigationPolygon, center: Vector2, size: Vector2, margin: float) -> void:
	# Placeholder for future obstacle support
	pass


## ─── Atmosphere (Veil Overlay) ────────────────────────────

func _build_atmosphere() -> void:
	# CanvasModulate — cool dark Veil tone over entire scene
	var veil := CanvasModulate.new()
	veil.name = "VeilModulate"
	veil.color = Color(0.55, 0.6, 0.75, 1.0)
	add_child(veil)

	# Floating ash/embers — sells the Veil distortion
	var particles := CPUParticles2D.new()
	particles.name = "VeilParticles"
	particles.position = Vector2(600, 350)
	particles.amount = 40
	particles.lifetime = 6.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(600, 400)
	particles.direction = Vector2(0.3, -1.0)
	particles.spread = 30.0
	particles.gravity = Vector2(0, 5)
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 20.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	particles.color = Color(0.8, 0.6, 0.4, 0.3)  # Warm embers, low alpha
	particles.z_index = 10
	add_child(particles)


## ─── Camera ───────────────────────────────────────────────

func _build_camera() -> void:
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.set_script(load("res://scripts/camera_follow_2d.gd"))
	cam.position = Vector2(550, 550)
	add_child(cam)


## ─── UI ───────────────────────────────────────────────────

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var label := Label.new()
	label.text = "2D PROTOTYPE — Tactical: WASD cursor, Space move, Tab switch, Q aim, E end turn\nARPG: WASD move, J attack (3-hit combo), K dodge (i-frames), L parry"
	label.position = Vector2(10, 10)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	label.add_theme_font_size_override("font_size", 14)
	canvas.add_child(label)

	var phase_label := Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.position = Vector2(10, 55)
	phase_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	phase_label.add_theme_font_size_override("font_size", 18)
	canvas.add_child(phase_label)

	var hp_label := Label.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector2(10, 80)
	hp_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	hp_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(hp_label)

	var eng_label := Label.new()
	eng_label.name = "EngLabel"
	eng_label.position = Vector2(10, 105)
	eng_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	eng_label.add_theme_font_size_override("font_size", 14)
	canvas.add_child(eng_label)

	# Update labels every 100ms
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(func():
		var tm := get_node_or_null("TurnManager")
		var em := get_node_or_null("EngagementManager")

		if tm:
			phase_label.text = "PLAYER PHASE" if tm.is_player_phase() else "ENEMY PHASE"

		var members := get_tree().get_nodes_in_group("party_member")
		var hp_text := ""
		for m in members:
			hp_text += "%s: %d/%d HP   " % [m.name, m.get("current_hp"), m.get("max_hp")]
		hp_label.text = hp_text

		if em and em.has_active_engagement():
			var eng = em.get_active_engagement()
			eng_label.text = "ENGAGEMENT: %s vs %s (%.1fs)" % [eng.member.name, eng.enemy.name, em.engagement_timer]
		else:
			eng_label.text = ""
	)
	canvas.add_child(timer)


## ─── Party Manager (added last — needs party + cursor + managers) ─

func _build_party_manager() -> void:
	var pm := Node.new()
	pm.name = "PartyManager"
	pm.set_script(load("res://scripts/party_manager_2d.gd"))
	add_child(pm)


## ─── Build Kage SpriteFrames (128px LPC composite) ───────

func _build_kage_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var dir_names: Array[String] = ["up", "left", "down", "right"]
	var tex := load("res://sprites/kage_lpc.png") as Texture2D
	var cw := 128
	var ch := 128

	# idle: base_row=0, 4 dirs, 2 frames (cols 0-1)
	for d in range(4):
		var anim := "idle_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 2.0)
		frames.set_animation_loop(anim, true)
		_add_frames(frames, anim, tex, 0 + d, [0, 1], cw, ch)

	# run: base_row=4, 4 dirs, 8 frames (cols 1-8)
	for d in range(4):
		var anim := "run_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 10.0)
		frames.set_animation_loop(anim, true)
		_add_frames(frames, anim, tex, 4 + d, [1, 2, 3, 4, 5, 6, 7, 8], cw, ch)

	# slash: base_row=8, 4 dirs, 6 frames (cols 0-5)
	for d in range(4):
		var anim := "slash_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 12.0)
		frames.set_animation_loop(anim, false)
		_add_frames(frames, anim, tex, 8 + d, [0, 1, 2, 3, 4, 5], cw, ch)

	# hurt: base_row=12, 1 dir only — reuse row 12 for all directions
	for d in range(4):
		var anim := "hurt_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 8.0)
		frames.set_animation_loop(anim, false)
		_add_frames(frames, anim, tex, 12, [0, 1, 2, 3, 4, 5], cw, ch)

	return frames


## ─── Build Akari SpriteFrames (64px LPC composite) ───────

func _build_akari_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var dir_names: Array[String] = ["up", "left", "down", "right"]
	var tex := load("res://sprites/akari_lpc.png") as Texture2D
	var cw := 64
	var ch := 64

	# idle: base_row=0, 4 dirs, 2 frames
	for d in range(4):
		var anim := "idle_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 2.0)
		frames.set_animation_loop(anim, true)
		_add_frames(frames, anim, tex, 0 + d, [0, 1], cw, ch)

	# run: base_row=4, 4 dirs, 8 frames (cols 1-8)
	for d in range(4):
		var anim := "run_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 10.0)
		frames.set_animation_loop(anim, true)
		_add_frames(frames, anim, tex, 4 + d, [1, 2, 3, 4, 5, 6, 7, 8], cw, ch)

	# slash: base_row=8, 4 dirs, 6 frames (cols 0-5)
	for d in range(4):
		var anim := "slash_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 12.0)
		frames.set_animation_loop(anim, false)
		_add_frames(frames, anim, tex, 8 + d, [0, 1, 2, 3, 4, 5], cw, ch)

	# hurt: base_row=12, 1 dir only — reuse for all directions
	for d in range(4):
		var anim := "hurt_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 8.0)
		frames.set_animation_loop(anim, false)
		_add_frames(frames, anim, tex, 12, [0, 1, 2, 3, 4, 5], cw, ch)

	return frames


## ─── Build Skeleton SpriteFrames (64px topdown composite) ─

func _build_skeleton_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var dir_names: Array[String] = ["up", "left", "down", "right"]
	var tex := load("res://sprites/skeleton_topdown.png") as Texture2D
	var cw := 64
	var ch := 64

	# idle: base_row=0, 4 dirs, 1 frame
	for d in range(4):
		var anim := "idle_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 2.0)
		frames.set_animation_loop(anim, true)
		_add_frames(frames, anim, tex, 0 + d, [0], cw, ch)

	# walk: base_row=4, 4 dirs, 8 frames (cols 1-8)
	for d in range(4):
		var anim := "walk_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 8.0)
		frames.set_animation_loop(anim, true)
		_add_frames(frames, anim, tex, 4 + d, [1, 2, 3, 4, 5, 6, 7, 8], cw, ch)

	# slash: base_row=8, 4 dirs, 6 frames (cols 0-5)
	for d in range(4):
		var anim := "slash_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 10.0)
		frames.set_animation_loop(anim, false)
		_add_frames(frames, anim, tex, 8 + d, [0, 1, 2, 3, 4, 5], cw, ch)

	# hurt: base_row=12, 1 dir only — reuse for all directions
	for d in range(4):
		var anim := "hurt_" + dir_names[d]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 8.0)
		frames.set_animation_loop(anim, false)
		_add_frames(frames, anim, tex, 12, [0, 1, 2, 3, 4, 5], cw, ch)

	return frames


## ─── Build Big Demon SpriteFrames (64px, non-directional) ─

func _build_big_demon_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var tex := load("res://sprites/big_demon_sheet.png") as Texture2D
	var cw := 64
	var ch := 64

	# Boss is non-directional — single row per animation
	# _play_anim() fallback: tries "idle_down" first, then "idle"

	# idle: row 0, 4 frames
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 4.0)
	frames.set_animation_loop("idle", true)
	_add_frames(frames, "idle", tex, 0, [0, 1, 2, 3], cw, ch)

	# walk: row 1, 4 frames
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 6.0)
	frames.set_animation_loop("walk", true)
	_add_frames(frames, "walk", tex, 1, [0, 1, 2, 3], cw, ch)

	# slash (attack): row 3, 4 frames
	frames.add_animation("slash")
	frames.set_animation_speed("slash", 8.0)
	frames.set_animation_loop("slash", false)
	_add_frames(frames, "slash", tex, 3, [0, 1, 2, 3], cw, ch)

	# hurt: row 4, 2 frames
	frames.add_animation("hurt")
	frames.set_animation_speed("hurt", 6.0)
	frames.set_animation_loop("hurt", false)
	_add_frames(frames, "hurt", tex, 4, [0, 1], cw, ch)

	return frames


## ─── Atlas Frame Helper ──────────────────────────────────

func _add_frames(frames: SpriteFrames, anim_name: String, sheet: Texture2D,
		row: int, cols: Array, cell_w: int = 64, cell_h: int = 64) -> void:
	for col in cols:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
		atlas.filter_clip = true
		frames.add_frame(anim_name, atlas)


## ─── Grid Drawer ──────────────────────────────────────────

class GridDrawer extends Node2D:
	func _draw() -> void:
		var grid_color := Color(0.2, 0.25, 0.18, 0.15)
		var spacing := 100
		for x in range(-1500, 1500, spacing):
			draw_line(Vector2(x, -1500), Vector2(x, 1500), grid_color, 1.0)
		for y in range(-1500, 1500, spacing):
			draw_line(Vector2(-1500, y), Vector2(1500, y), grid_color, 1.0)
