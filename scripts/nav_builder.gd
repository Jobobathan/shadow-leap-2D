extends NavigationRegion2D
## Builds grid-based navigation mesh at runtime.
## Excludes cells that overlap building/cover collision rects.
## TODO: Replace with editor-drawn NavigationPolygon when scene is mature.

func _ready() -> void:
	_build_nav_mesh()


func _build_nav_mesh() -> void:
	var nav_poly := NavigationPolygon.new()
	var CELL := 50.0
	var NAV_MARGIN := 20.0
	var bounds := Rect2(-200, -250, 1600, 1150)

	var obstacles := _get_obstacle_rects(NAV_MARGIN)

	# Build vertex grid
	var cols := int(bounds.size.x / CELL)
	var rows := int(bounds.size.y / CELL)
	var verts := PackedVector2Array()
	for r in range(rows + 1):
		for c in range(cols + 1):
			verts.append(bounds.position + Vector2(c * CELL, r * CELL))
	nav_poly.vertices = verts

	# Add quad polygons for non-blocked cells
	var vert_cols := cols + 1
	var poly_count := 0
	for r in range(rows):
		for c in range(cols):
			var cell_tl := bounds.position + Vector2(c * CELL, r * CELL)
			var cell_rect := Rect2(cell_tl, Vector2(CELL, CELL))
			if _cell_hits_obstacle(cell_rect, obstacles):
				continue
			var i_tl := r * vert_cols + c
			var i_tr := r * vert_cols + c + 1
			var i_br := (r + 1) * vert_cols + c + 1
			var i_bl := (r + 1) * vert_cols + c
			nav_poly.add_polygon(PackedInt32Array([i_tl, i_tr, i_br, i_bl]))
			poly_count += 1

	navigation_polygon = nav_poly
	print("[Navigation] Grid nav mesh: %d verts, %d walkable cells (%d blocked)" % [
		verts.size(), poly_count, (rows * cols) - poly_count])


func _get_obstacle_rects(margin: float) -> Array:
	var rects: Array = []
	# Buildings: collision = lower 60% of visual, offset 20% down
	var buildings := [
		{"pos": Vector2(180, 640), "tw": 96, "th": 256, "s": 1.5},
		{"pos": Vector2(180, 120), "tw": 128, "th": 256, "s": 1.5},
		{"pos": Vector2(1020, 120), "tw": 160, "th": 256, "s": 1.5},
		{"pos": Vector2(1020, 640), "tw": 160, "th": 288, "s": 1.5},
	]
	for b in buildings:
		var vw: float = b["tw"] * b["s"]
		var vh: float = b["th"] * b["s"]
		var center := Vector2(b["pos"]) + Vector2(0, vh * 0.2)
		var half := Vector2(vw / 2.0 + margin, vh * 0.3 + margin)
		rects.append(Rect2(center - half, half * 2.0))
	# Cover objects
	var covers := [
		{"pos": Vector2(350, 450), "sz": Vector2(120, 90)},
		{"pos": Vector2(850, 350), "sz": Vector2(50, 75)},
		{"pos": Vector2(450, 180), "sz": Vector2(90, 60)},
	]
	for c in covers:
		var half := Vector2(c["sz"]) / 2.0 + Vector2(margin, margin)
		var pos := Vector2(c["pos"])
		rects.append(Rect2(pos - half, half * 2.0))
	return rects


func _cell_hits_obstacle(cell: Rect2, obstacles: Array) -> bool:
	for obs in obstacles:
		if cell.intersects(obs as Rect2):
			return true
	return false
