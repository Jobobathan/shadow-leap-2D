# Shadow Leap 2D — Session Handoff: Buildings v3 & michaelgames Series

**Date:** 2026-05-16
**Session Focus:** House cleanup + michaelgames series review

---

## What Was Done

### 1. Buildings Compositor v3 Created
**File:** `prototype_2d/tools/compose_buildings_v3.py`

Rebuilt all 4 building PNGs with SNES RPG-style improvements (Chrono Trigger, Illusion of Gaia, Secret of Mana references):

| Building | Wall Type | Size (v2→v3) | Windows | Door | Eave Fix |
|----------|-----------|--------------|---------|------|----------|
| 1 (small gable) | brick_red | 96×224→96×256 | 1 (brick_dark @ 8,14) | red_brick @ 4,11 | ✅ roof fill |
| 2 (medium gable) | wood_blue | 128×224→128×256 | 2 (wood_dark @ 21,18) | dark @ 24,15 | ✅ roof fill |
| 3 (large hipped) | brick_white | 160×224→160×256 | 2 (brick_light @ 0,14) | dark @ 24,15 | N/A (hipped) |
| 4 (large steep hipped) | wood_green | 160×256→160×288 | 2 (wood_dark @ 21,18) | darkest @ 30,17 | N/A (hipped) |

**Key changes from v2:**
- Front-facing **windows** on all buildings (dark glass center with wall frame)
- Centered **doors** on all buildings
- Gable eave gaps **fixed** (center filled with roof tile instead of `None`)
- **Top wall edges** always rendered for clean roof-to-wall transitions
- Large buildings get **extra fill row** for proper proportions
- `make_wall_rows_v3()` takes `window_positions`, `door_col`, `window_tile`, `door_tile`, `extra_fill_rows` params

### 2. michaelgames Series Cataloged
**Series:** "Make a 2D Action & Adventure RPG in Godot 4" by Michael Games
**Total episodes found:** 30+ (ongoing series)

**E04 watched in detail** — "Tilemaps & Tilesets" (26:32)
Key takeaways applied to Shadow Leap:
- TileMap as reusable scenes (grass_01.tscn pattern) — natural evolution from programmatic `main_scene_builder.gd`
- 32×32 pixel tile grid confirmed compatible with LPC assets
- Physics layers with named collision (Layer 1="player", Layer 5="walls")
- Terrain sets for auto-tiling (corners + sides mode) — ideal for ground/path painting
- Motion mode = "floating" for top-down (not "grounded") — enables wall sliding
- `direction = direction.normalized()` prevents faster diagonal movement

---

## What Needs Doing Next

### Immediate: Update main_scene_builder.gd
The building PNGs changed dimensions. The `_create_building()` function auto-adapts collision from texture size, BUT `_get_nav_obstacle_rects()` has **hardcoded** `tw`/`th` values that need updating:

```gdscript
# OLD hardcoded values in _get_nav_obstacle_rects():
var buildings := [
    {"pos": Vector2(180, 640), "tw": 96, "th": 224, "s": 1.5},   # Building 1: th was 224
    {"pos": Vector2(180, 120), "tw": 128, "th": 224, "s": 1.5},  # Building 2: th was 224
    {"pos": Vector2(1020, 120), "tw": 160, "th": 224, "s": 1.5}, # Building 3: th was 224
    {"pos": Vector2(1020, 640), "tw": 160, "th": 256, "s": 1.5}, # Building 4: th was 256
]

# NEW values needed:
# Building 1: th = 256 (was 224)
# Building 2: th = 256 (was 224)  
# Building 3: th = 256 (was 224)
# Building 4: th = 288 (was 256)
```

Also review window glow positioning in `_create_building()` — the `win_count` param controls how many lights are placed, but positions may need adjustment for the taller walls.

### Short-term: Building Polish
- **Window/door tile matching** — Current window/door tiles come from different areas of colonial.png. Some may not perfectly match their wall terrain colors. Could scan colonial.png for terrain-specific window/door variants (e.g., find windows specifically designed for brick_red vs wood_blue).
- **Door frame tiles** — The LPC colonial set likely has door frame pieces (upper door at 24,14) that could be composited above the door tile for a taller, more realistic entrance.
- **Chimney tiles** — LPC roofs.png has chimney pieces that could add character to buildings.

### Medium-term: Transition to TileMap workflow
Based on michaelgames E04, the natural evolution is:
1. Convert from programmatic `main_scene_builder.gd` to **TileMap-based** scene composition
2. Each tileset becomes a reusable scene (buildings, terrain, props)
3. Set up **terrain sets** for auto-tiling ground/paths
4. Use **physics layers** on tiles instead of manual `StaticBody2D`
5. Use **TileMapLayer** nodes (E48 covers migration from old TileMap)

### michaelgames Episodes to Watch Next

**Priority 1 (directly applicable now):**
| Ep | Title | Duration | Why Watch | URL |
|----|-------|----------|-----------|-----|
| E63 | Advanced Tileset Layer Settings | 17:48 | Layer-based building composition, roof-over-wall in-engine | https://youtube.com/watch?v=l9NRc1jfXHs |
| E48 | Update TileMap to TileMapLayer | 16:59 | Modern Godot 4 tilemap approach | https://youtube.com/watch?v=QeL24XUlgg8 |
| E42 | Lighting & Torches | 17:59 | Directly applicable to Veil atmosphere/glow system | https://youtube.com/watch?v=J1Zm7AGJrsk |
| E64 | Custom Footstep Audio using TileSets | 41:24 | Data-driven tile metadata for gameplay | https://youtube.com/watch?v=HrhzPlfm0zY |

**Priority 2 (combat/character systems Shadow Leap will need):**
| Ep | Title | Duration | URL |
|----|-------|----------|-----|
| E01 | Basic Top Down Character | 25:46 | https://youtube.com/watch?v=QPeycNt29tY |
| E03 | Player State Machine | 31:42 | https://youtube.com/watch?v=ozUS1cSgFKs |
| E06 | Hit & Hurt Boxes | 35:46 | https://youtube.com/watch?v=K6o8vEuqI6Q |
| E09 | Make a Slime Enemy (part I) | 47:52 | https://youtube.com/watch?v=fLzmZPNJNDk |
| E11 | Player Stun State | 40:24 | https://youtube.com/watch?v=DXojXbpdMyE |

**Priority 3 (game infrastructure for later):**
| Ep | Title | Duration | URL |
|----|-------|----------|-----|
| E14 | Scene Manager | 54:58 | https://youtube.com/watch?v=rA-pI06mpw4 |
| E15 | Basic Save & Load | 47:48 | https://youtube.com/watch?v=D57Q-8W9qNE |
| E29 | NPC Part I | 56:22 | https://youtube.com/watch?v=MZKHruN7TJo |
| E56 | Basic Player Stats & Leveling | 55:37 | https://youtube.com/watch?v=2gJ0VCx_IAA |
| E59 | Equipment System Part 1 | 21:21 | https://youtube.com/watch?v=RRGT3u17GYA |

---

## Asset Reference

### Window tiles in colonial.png (32×32 grid positions)
```
wood_dark:    (21, 18)  — High contrast, dark glass (center=61, edge=144). Best for wood walls.
wood_light:   (18, 18)  — Lighter glass (center=99, edge=133)
brick_dark:   (8, 14)   — Window on brick-like wall (center=59, edge=112)
brick_light:  (0, 14)   — Lighter brick window (center=98, edge=142)
generic:      (26, 19)  — Generic window tile
```

### Door tiles in colonial.png
```
dark:         (24, 15)  — Dark door (mean=56)
darkest:      (30, 17)  — Darkest door (mean=50)
medium:       (24, 21)  — Medium door (mean=63)
red_brick:    (4, 11)   — Door for brick walls (mean=66)
upper:        (24, 14)  — Upper door section (mean=35, very dark)
```

### Wall terrains in colonial.png
```
brick_red:     (0, 0)   — Building 1
brick_white:   (0, 5)   — Building 3
wood_white:    (18, 1)  — Not currently used
wood_blue:     (25, 1)  — Building 2
wood_yellow:   (18, 8)  — Not currently used
wood_green:    (25, 8)  — Building 4
```

### Roof variants in roofs.png
```
V_DARK  = 0   — Variant 0: purple-gray (cool, moody Veil aesthetic)
V_DARK2 = 35  — Variant 7: blue-gray (cool, slightly lighter)
```
