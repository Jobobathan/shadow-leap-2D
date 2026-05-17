# Shadow Leap 2D — Session Handoff: TileMap Refactor Plan

**Date:** 2026-05-16  
**Previous Handoff:** `SESSION_HANDOFF_BUILDINGS_V3_POLISH.md`  
**Status:** PLAN — not started, pending video ingestion

---

## What Went Wrong (Honest Assessment)

We built the 2D prototype environment backwards:

1. **Python scripts compositing flat PNGs** (`compose_buildings_v3.py`) — This is not game development. A real game designer would never bake tiles into static images. Godot has a TileMap system specifically designed to do this better.

2. **Programmatic scene building** (`main_scene_builder.gd`, 500 lines) — Fixed in this session (converted to proper .tscn with 69 nodes), but the underlying problem remains: the environment is made of flat PNG sprites, not tiles.

3. **Hardcoded navigation mesh** (`nav_builder.gd`) — Manually computing obstacle rects in code. Godot's TileMap has built-in navigation layers that generate nav meshes automatically from tile definitions.

4. **Hardcoded collision** — Each building has manually computed RectangleShape2D collision. TileMap defines collision per-tile, so buildings are automatically solid.

**Root cause:** The reference videos for TileSet/TileMap (`bI5mGEho76U`, `HAOC0FCHWNg`) were marked "Not Relevant" in VIDEO_PHASE_MAP.md because the project was 3D at the time. When we pivoted to 2D, we never updated the plan to use the right tools.

---

## What Is the TileMap System?

TileMap is Godot's built-in system for painting 2D worlds from tile grids. Instead of compositing PNGs in Python, you:

### TileSet Resource (.tres)
- Import your tilesheets (colonial.png, roofs.png, conifers.png, etc.)
- Define each tile's properties in the editor:
  - **Physics layer** — collision shape per tile (walls are solid, floors aren't)
  - **Navigation layer** — which tiles are walkable (auto-generates nav mesh)
  - **Terrain sets** — autotile rules (paint "brick wall" and Godot auto-picks corners/edges/fills)
  - **Custom data** — metadata per tile (e.g., "is_cover", "blocks_LOS")

### TileMapLayer Nodes
- One or more layers in your scene (ground, walls, roofs, decoration)
- **Paint tiles visually** in the Godot editor — click to place, drag to paint
- Layers stack: ground on bottom, walls above, roofs on top
- Each layer can have different z_index for proper visual sorting

### What This Eliminates
| Current Approach | TileMap Replacement |
|-----------------|-------------------|
| `compose_buildings_v3.py` (Python tile compositor) | Paint tiles directly in Godot editor |
| Pre-baked building_1-4.png flat images | Individual tiles placed on TileMapLayers |
| `nav_builder.gd` (hardcoded obstacle rects) | Navigation layer on TileSet — auto nav mesh |
| RectangleShape2D per building (manual collision) | Physics layer on TileSet — auto collision |
| Can't edit one tile without Python + regenerate | Click any tile → replace it in the editor |
| `grid_drawer.gd` (custom grid overlay) | TileMap IS a grid — visible in editor |

### What Stays the Same
- Entity sub-scenes (kage.tscn, akari.tscn, small_demon.tscn, big_demon.tscn) — ✅ correct
- Behavior scripts (player_2d.gd, AI scripts, managers) — ✅ correct
- SpriteFrames resources — ✅ correct
- Camera, UI, atmosphere (CanvasModulate, particles) — ✅ correct
- @export vars for tweaking — ✅ correct

**The entity/character architecture is RIGHT. Only the environment (ground, buildings, trees, cover) needs to switch to TileMap.**

---

## Required Video Ingestion (Before Starting)

These two MichaelGamesOfficial videos from the existing playlist cover exactly what we need:

### 1. `HAOC0FCHWNg` — 02.02 TileSet Asset Creation (Aseprite)
- How to organize a tilesheet for Godot
- Tile size, grid alignment, atlas setup
- **Why first:** Understanding how tiles need to be structured before importing

### 2. `bI5mGEho76U` — 02.03 TileSets, TileMapLayers, and More
- Creating TileSet resources in Godot
- Setting up TileMapLayer nodes
- Physics layers (collision per tile)
- Navigation layers (auto nav mesh)
- Terrain sets (autotile rules for walls)
- Painting tiles in the editor
- **This is THE video** — covers the complete TileMap workflow

### Optional but valuable:
- `maTIXQ9h_0g` — 02.10 Player Spawn & Level Building Advice — practical level design tips
- `gQ_8mu9sTNM` — 02.07 Animated Props — for fountain, torches, etc.

---

## Refactor Plan

### Phase 1: Ingest Videos + Create TileSet
1. Watch/ingest `HAOC0FCHWNg` and `bI5mGEho76U`
2. Create a TileSet resource from colonial.png (32×32 grid)
   - Define wall terrains (brick_red, brick_white, wood_blue, wood_green)
   - Set up autotile terrain rules so painting a wall auto-picks corners
   - Add physics layer: wall tiles get collision, floor tiles don't
   - Add navigation layer: floor tiles are walkable, wall tiles aren't
3. Create a TileSet resource from roofs.png (32×32 grid within 64×64 patterns)
   - Define roof tile variants
4. Consider creating a TileSet from conifers.png for trees

### Phase 2: Build TileMapLayers
Replace the flat building PNGs with painted tile layers:
1. **Ground layer** (z=-10) — dirt/grass tiles painted across the play area
2. **Walls layer** (z=-2) — building walls painted using terrain autotiles
3. **Roofs layer** (z=0) — roof tiles painted above walls
4. **Decoration layer** (z=1) — trees, barrels, rocks, props

### Phase 3: Clean Up
1. Delete: `compose_buildings_v3.py`, building_1-4.png, `nav_builder.gd`, `grid_drawer.gd`
2. Delete: all AtlasTexture sub-resources for covers/trees in main.tscn
3. Keep: entity sub-scenes, behavior scripts, atmosphere, UI, camera
4. Navigation mesh now auto-generated from TileSet navigation layer
5. Collision now auto-generated from TileSet physics layer

### Phase 4: Polish in Editor
- Adjust building layouts by clicking/painting tiles
- Fix any wrong tiles by clicking the tile and selecting the right one
- Move props, adjust spacing — all visual, all in the editor
- **This is where "how do I replace one tile" becomes: click it → pick new tile**

---

## Assets Already Available for TileSet

These tilesets are already in the project and ready to import:

| Asset | Grid | Location |
|-------|------|----------|
| colonial.png | 32×32 | `sprites/colonial.png` (1024×1024) — walls, windows, doors |
| roofs.png | 32×32 | `Terrain Downloads/extracted/lpc-roofs-v2/.../roofs.png` — all roof types |
| conifers.png | varies | `sprites/conifers.png` (1024×512) — tree tiles |
| rocks.png | varies | `sprites/rocks.png` (1024×1024) — rock/boulder tiles |
| barrels.png | 32×32 | `sprites/barrels.png` (160×64) — barrel props |
| terrain_v7.png | 32×32 | `sprites/terrain_v7.png` (1024×2048) — ground/terrain tiles |

The LPC (Liberated Pixel Cup) tilesets in `Terrain Downloads/extracted/` have additional options:
- `lpc-terrains/` — ground terrain autotiles
- `lpc-walls/` — wall autotiles  
- `lpc-bricks-v6/` — brick wall variants
- `lpc_objectspack/` — decoration objects

---

## Key Decision: Scope

The entity system (characters, enemies, combat scripts) is solid. Don't redo it.
Only the **environment rendering** needs to switch from flat PNGs to TileMap.

Estimated effort: 1 session after video ingestion.

---

## Commit History
```
4568a48  Rebuild scene as proper Godot nodes — replace monolithic builder
5d2b88c  Add @tool mode: see scene in Godot editor without play
38b6b92  Fix scene glitches: trees, boss, building tints
36a3206  v3 polish: door frames, chimneys, window/door tile matching analysis
```
