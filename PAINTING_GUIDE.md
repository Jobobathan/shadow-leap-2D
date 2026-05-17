# Shadow Leap 2D — TileMap Painting Guide

## Quick Start

### Step 1: Create the TileSet (one-time)
1. Open `scenes/main.tscn`
2. Add child **Node2D** to Main → rename `Creator` → attach `tools/tileset_creator.gd`
3. Click **"Create TileSet"** in the inspector
4. Watch Output for `✓ Saved` confirmation
5. Delete the `Creator` node, save scene

### Step 2: Add TileMapLayers
Add these as children of **Main** (right-click Main → Add Child → TileMapLayer):

| Layer Name | Z-Index | Collision | Purpose |
|-----------|---------|-----------|---------|
| `GroundLayer` | -10 | OFF | Grass, dirt, stone, paths |
| `WallLayer` | -3 | ON | Building walls (solid) |
| `WallOverlay` | -2 | OFF | Door frames, window trim (alpha) |
| `RoofLayer` | -1 | OFF | Roof tiles |
| `RoofOverlay` | 0 | OFF | Chimneys, roof decorations |
| `PropLayer` | 1 | OFF | Fences, flowers, planters |

For each layer:
- In inspector → **Tile Set** → load `res://resources/town_tileset.tres`
- Set **Z Index** as shown above
- For WallLayer: leave `Collision Enabled = true` (default)
- For all others: set `Collision Enabled = false`

### Step 3: Paint!
1. Select a TileMapLayer in the scene tree
2. The **TileMap** panel opens at the bottom
3. Pick a **Source** from the dropdown (see atlas reference below)
4. Click a tile → click on the viewport to paint
5. Hold Shift to draw lines, hold Ctrl to erase

---

## Atlas Source Reference

Each source has an ID number. Select the source in the TileMap bottom panel dropdown.

### Source 0: `colonial.png` (1024×1024) — Main Building Walls
The primary wall tileset. 32×32 grid = 32 cols × 32 rows.

**Wall terrains** (3×3 autotile blocks — TL, Top, TR / L, Fill, R / BL, Bot, BR):
| Terrain | Origin (col, row) | Use For |
|---------|-------------------|---------|
| brick_red | (0, 0) | Red brick building walls |
| brick_white | (0, 5) | Light/white brick walls |
| wood_blue | (25, 1) | Blue-painted wood siding |
| wood_green | (25, 8) | Green-painted wood siding |

**Windows** (single tiles):
| Style | Position | Notes |
|-------|----------|-------|
| brick_dark | (8, 14) | Dark frame on brick |
| brick_light | (0, 14) | Light frame on brick |
| wood_dark | (21, 18) | Dark frame on wood |

**Doors** (single tiles, place on bottom row):
| Style | Door Tile | Frame Tile (row above) |
|-------|-----------|----------------------|
| red_brick | (4, 11) | (4, 10) |
| dark | (24, 15) | (24, 14) |
| darkest | (30, 17) | (30, 16) |

### Source 1: `roofs.png` (2048×2048) — Roofs
Two color variants:
- **Dark (purple-gray)**: columns start at x=0
- **Blue-gray**: columns start at x=35

Roof shapes are arranged in rows. Browse visually — there are gable ends, hipped roofs, flat sections, chimneys.

### Source 2: `terrain_v7.png` (1024×2048) — Ground
Your main ground tileset. Includes:
- Grass (multiple shades)
- Dirt paths
- Stone/cobblestone
- Water edges
- Sand

### Source 3: `walls.png` (2048×3072) — Extra LPC Walls
Huge wall variety — stone, wood, plaster, half-timber. Browse visually.

### Source 4: `bricks.png` (1024×2048) — Brick Patterns
Multiple brick colors and bond patterns.

### Source 5-6: `victorian-mansion.png` / `victorian-tenement.png`
Victorian building wall tiles — ornate facades, bay windows, multi-story.

### Source 7: `victorian-windows-doors.png` (1024×5120)
Massive collection of window and door styles.

### Source 8: `victorian-accessories.png`
Awnings, signs, balconies, railings, shop fronts.

### Source 9: `decorations-medieval.png`
Barrels, crates, market stalls, weapon racks, shields, banners.

### Source 10: `fence_medieval.png`
Wooden and iron fences — great for **tactical cover** boundaries.

### Source 11: `base_out_atlas.png` — Outdoor Base
General outdoor tiles — alternative ground, paths, cliff edges.

### Source 12: `terrain_atlas.png` — Terrain Alt
Another terrain atlas with different ground textures.

### Source 13: `blacksmith-smelter.png`
Forge, anvil, smelter tiles.

### Source 14-15: `flowers.png` / `planters.png`
Small decorative props for gardens and planters.

---

## Painting Tips

### Building a House
1. Select `WallLayer` → pick **colonial** source
2. Paint the wall terrain: start with corners (TL, TR, BL, BR), then edges, then fill
3. Place windows on fill rows
4. Place door on bottom row
5. Switch to `WallOverlay` → place door frame tile one row above door
6. Switch to `RoofLayer` → pick **roofs** source → paint roof above wall
7. Switch to `RoofOverlay` → add chimney if desired

### Ground
1. Select `GroundLayer` → pick **terrain_v7** source
2. Fill the play area with base grass
3. Paint paths between buildings
4. Add dirt/stone under buildings

### Cover Props
Fences, barrels, and crates can go on `PropLayer`. For ones that need **collision for gameplay** (tactical cover), keep them as individual StaticBody2D nodes like the existing Cover_Rock1, Cover_Barrel, Cover_Rock2.

### Keyboard Shortcuts (TileMap panel)
- **Left click**: Paint
- **Right click / Ctrl+click**: Erase
- **Shift+click**: Line tool
- **Ctrl+Shift+click**: Rectangle fill
- **B**: Bucket fill (fills connected empty area)
- **Mouse wheel**: Scroll through tiles in palette

---

## After Painting — Ask Me To Add:
Once your layout looks good, tell me and I'll add:
- ☐ WindowLight PointLight2Ds at each building
- ☐ Drop shadow ColorRects under buildings
- ☐ Physics collision on wall tiles (paint mode in TileSet)
- ☐ Navigation polygons on walkable ground tiles
- ☐ Terrain sets for wall autotiling
- ☐ Cleanup old House1-4 nodes + legacy scripts
- ☐ Entity position adjustments to match new layout
