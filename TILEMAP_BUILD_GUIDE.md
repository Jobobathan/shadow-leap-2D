# TileMap Refactor — Build Guide

**Date:** 2026-05-16  
**Previous:** `SESSION_HANDOFF_TILEMAP_REFACTOR.md`  
**Status:** Builder script ready — run in Godot editor

---

## What Was Created

| File | Purpose |
|------|---------|
| `tools/tilemap_builder.gd` | @tool script — creates TileSet, paints buildings, cleans up legacy |
| `sprites/roofs.png` | Copied from Terrain Downloads (2048×2048, needed for TileSet) |
| `TILEMAP_BUILD_GUIDE.md` | This file |

## Architecture

The builder creates **4 TileMapLayers** (replacing flat PNG buildings):

| Layer | Z-Index | Source | Content | Collision |
|-------|---------|--------|---------|-----------|
| `WallLayer` | -3 | colonial.png | Wall autotiles, windows, doors | ✅ Full-tile rectangles |
| `WallOverlay` | -2 | colonial.png | Door frame lintels/arches | ❌ Disabled |
| `RoofLayer` | -1 | roofs.png | Roof tiles (gable + hipped) | ❌ None |
| `RoofOverlay` | 0 | roofs.png | Chimney caps/bodies | ❌ Disabled |

The TileSet (`resources/town_tileset.tres`) includes:
- **Physics layer 0**: collision layer 1, mask 0 (solid walls)
- **Navigation layer 0**: layers 1 (walkable — configure per-tile in editor)
- **Source 0**: colonial.png (auto-scanned, all non-empty tiles registered)
- **Source 1**: roofs.png (auto-scanned, all non-empty tiles registered)

## Step-by-Step: Run the Builder

### 1. Open Godot and load the project

### 2. Add Builder node to main.tscn
- Open `scenes/main.tscn`
- Select the root `Main` node
- Add Child → **Node2D** → rename it `Builder`
- In the inspector, load script: `tools/tilemap_builder.gd`

### 3. Run Phase 1: Build TileSet
- Select the `Builder` node
- In inspector, check **Build Tileset** → ✅
- Watch Output panel for confirmation:
  ```
  [TileMapBuilder] ═══ Phase 1: Building TileSet ═══
    colonial.png: ~XXX tiles
    roofs.png: ~XXX tiles
    Physics: ~XX wall tiles with collision
    ✓ Saved res://resources/town_tileset.tres
  ```
- **Save the project** (Ctrl+S)

### 4. Run Phase 2: Build Level
- Check **Build Level** → ✅
- Watch Output for building placement confirmation
- You should see 4 TileMapLayers appear in the scene tree:
  `WallLayer`, `WallOverlay`, `RoofLayer`, `RoofOverlay`
- The 4 buildings should be visible in the 2D viewport
- **Save the scene** (Ctrl+S)

### 5. Run Phase 3: Cleanup Legacy
- Check **Cleanup Legacy** → ✅
- This removes: `Ground`, `GridOverlay`, `House1-4`, `NavigationRegion2D`
- Keeps: cover objects, trees, fountain, foodogs, car, entities, managers, UI, atmosphere
- **Save the scene** (Ctrl+S)

### 6. Final cleanup
- Delete the `Builder` node from the scene tree
- Save again
- Optionally delete these files (no longer needed):
  - `sprites/building_1.png` through `building_4.png`
  - `sprites/building_diagnostic.png`
  - `scripts/nav_builder.gd`
  - `scripts/grid_drawer.gd`
  - `tools/compose_buildings.py`, `compose_buildings_v2.py`, `compose_buildings_v3.py`

---

## Phase 4: Polish in Editor (Manual)

After the builder runs, you have buildings painted on TileMapLayers. Now polish:

### Ground Layer
1. Open the TileSet resource (`resources/town_tileset.tres`)
2. Add a new atlas source: `sprites/terrain_v7.png` (1024×2048, 32×32 grid)
3. Auto-create tiles from the atlas
4. Add a new `TileMapLayer` called `GroundLayer` (z_index = -10)
5. Assign the town_tileset to it
6. Select Terrain_v7 source in the TileMap panel
7. Paint ground tiles across the play area

### Navigation
1. Open the TileSet in the inspector
2. Go to the TileSet panel (bottom)
3. Switch to **Paint** mode
4. Select **Navigation Layer 0 / Polygon 0**
5. Paint navigation polygons on ground/floor tiles (walkable)
6. Wall tiles should NOT have navigation (they already have physics collision)

### Terrain Sets (Autotiling)
1. In TileSet inspector → Terrain Sets → Add Element
2. Mode: **Match Corners and Sides**
3. Add terrains: `brick_red`, `brick_white`, `wood_blue`, `wood_green`
4. In TileSet panel → Paint → select terrain
5. Paint the 9-cell peering bits for each terrain tile
6. Now you can paint walls with auto-tiling in the TileMap editor

### Building Adjustments
- Click any tile to replace it
- Use the TileMap panel to select different tiles
- Move/add/remove buildings by painting/erasing on WallLayer + RoofLayer
- Add more buildings — just paint wall autotiles + roof tiles

### Props on TileMapLayer
- Consider moving trees/rocks to a `DecorationLayer` TileMapLayer
- Set `collision_enabled = false` on decoration layers
- Can offset decoration layers by a few pixels (position.y += 4) for better grounding
- Can modulate background decoration layers (darken/tint) for depth

### Cover Objects
- Cover_Rock1, Cover_Barrel, Cover_Rock2 are kept as individual StaticBody2D nodes
- This is correct — they need individual collision for gameplay (cover system)
- If you want them on a TileMapLayer later, you'd need custom data on tiles

---

## What Changed vs. Old System

| Old (Flat PNGs) | New (TileMap) |
|-----------------|---------------|
| `compose_buildings_v3.py` composites PNGs | Paint tiles directly in Godot editor |
| `building_1-4.png` flat images | Individual tiles on TileMapLayers |
| `nav_builder.gd` (80 lines, hardcoded rects) | Navigation layer on TileSet (auto) |
| `grid_drawer.gd` (10 lines) | TileMap IS a grid |
| `RectangleShape2D` per building (manual) | Physics layer on TileSet (per-tile) |
| Can't edit one tile without Python + regen | Click any tile → replace in editor |
| Buildings scaled 1.5x (non-standard) | Native 32×32 tiles (standard) |

## What Stayed the Same
- ✅ Entity scenes (kage.tscn, akari.tscn, demons)
- ✅ Behavior scripts (player_2d.gd, AI, managers)
- ✅ SpriteFrames resources
- ✅ Camera, UI, atmosphere (CanvasModulate, particles)
- ✅ @export vars for tweaking
- ✅ Cover objects (individual StaticBody2D for gameplay)

---

## Building Positions (Tile Grid)

| Building | Terrain | Roof Style | Grid Position | Size |
|----------|---------|------------|---------------|------|
| 1 | brick_red | Gable (V_DARK) | (4, 14) | 3×8 |
| 2 | wood_blue | Gable (V_DARK2) | (3, 1) | 4×8 |
| 3 | brick_white | Hipped (V_DARK) | (28, 1) | 5×8 |
| 4 | wood_green | Steep Hipped (V_DARK2) | (28, 13) | 5×9 |

Viewport = 40×22.5 tiles (1280×720 at 32px). Buildings are in 4 quadrants.
