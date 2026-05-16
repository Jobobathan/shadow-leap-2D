#!/usr/bin/env python3
"""
Shadow Leap 2D — Building Compositor v3 (SNES RPG Style)
Fixes from v2:
  - Adds front-facing WINDOWS to wall sections
  - Adds centered DOORS at bottom of walls
  - Fixes eave gaps (fills center of eave with wall tile)
  - SNES RPG references: Chrono Trigger, Illusion of Gaia, Secret of Mana

Building anatomy (SNES RPG style, 3/4 top-down view):
  - Roof dominates (60-70% of building height)
  - Roof has shaped/triangular outline with transparency
  - Wall is thin strip at bottom showing front face
  - Front face has: windows (upper), door (center-bottom)
  - Roof drawn ON TOP of wall (alpha compositing at overlap)

Sources:
  - colonial.png (32×32 grid) — wall autotiles + windows + doors
  - roofs.png (64×64 grid) — shaped roof tiles
"""

from PIL import Image
import numpy as np
import os

TILE = 32
SPRITES = os.path.expanduser('~/shadow-leap/prototype_2d/sprites')
EXTRACTED = os.path.expanduser('~/shadow-leap/prototype_2d/Terrain Downloads/extracted')

colonial = Image.open(f'{SPRITES}/colonial.png').convert('RGBA')
roofs_img = Image.open(f'{EXTRACTED}/lpc-roofs-v2/lpc-roofs-v2/roofs.png').convert('RGBA')

print(f"Colonial: {colonial.size}, Roofs: {roofs_img.size}")


def get_roof_tile(gx, gy):
    """Get a 32×32 tile from roofs.png at grid position."""
    return roofs_img.crop((gx*TILE, gy*TILE, (gx+1)*TILE, (gy+1)*TILE))

def get_wall_tile(gx, gy):
    """Get a 32×32 tile from colonial.png at grid position."""
    return colonial.crop((gx*TILE, gy*TILE, (gx+1)*TILE, (gy+1)*TILE))


# ═══════════════════════════════════════════════════════════
# ROOF COLOR VARIANTS (columns in roofs.png, 5 per variant)
# ═══════════════════════════════════════════════════════════

# Variant 0: purple-gray (cool, moody) — excellent for Veil aesthetic
# Variant 7: blue-gray (cool, slightly lighter)
V_DARK = 0     # Variant 0: purple-gray
V_DARK2 = 35   # Variant 7: blue-gray
print(f"Roof variants: V_DARK={V_DARK} (purple-gray), V_DARK2={V_DARK2} (blue-gray)")


# ═══════════════════════════════════════════════════════════
# WALL TERRAIN DEFINITIONS (from colonial.tsx)
# ═══════════════════════════════════════════════════════════
# Each terrain is a 3×3 autotile block: (start_col, start_row)
# Pattern: TL=(+0,+0) Top=(+1,+0) TR=(+2,+0)
#          L=(+0,+1)  Fill=(+1,+1) R=(+2,+1)
#          BL=(+0,+2) Bot=(+1,+2)  BR=(+2,+2)

TERRAINS = {
    'brick_red':     (0, 0),    # House_Brick_Red
    'brick_white':   (0, 5),    # House_Brick_White
    'wood_white':    (18, 1),   # House_Wood_White
    'wood_blue':     (25, 1),   # House_Wood_Blue
    'wood_yellow':   (18, 8),   # House_Wood_Yellow
    'wood_green':    (25, 8),   # House_Wood_Green
}

# ═══════════════════════════════════════════════════════════
# WINDOW AND DOOR TILE POSITIONS (from colonial.png analysis)
# ═══════════════════════════════════════════════════════════
# Windows: tiles with dark center (glass) and lighter wall frame
# Doors: dark rectangular tiles

# Window tiles identified from scan (colonial.png grid positions)
# These are wall tiles that contain window features
WINDOWS = {
    # (gx, gy) -> description
    'wood_dark':    (21, 18),   # High contrast window, dark glass (center=61, edge=144)
    'wood_light':   (18, 18),   # Lighter window (center=99, edge=133)
    'brick_dark':   (8, 14),    # Window on brick-like wall (center=59, edge=112)
    'brick_light':  (0, 14),    # Lighter brick window (center=98, edge=142)
    'generic':      (26, 19),   # Generic window tile
}

# Door tiles identified from scan
DOORS = {
    'dark':         (24, 15),   # Dark door (mean=56)
    'darkest':      (30, 17),   # Darkest door (mean=50)
    'medium':       (24, 21),   # Medium door (mean=63)
    'red_brick':    (4, 11),    # Door for brick walls (mean=66)
    'upper':        (24, 14),   # Upper door section (mean=35, very dark)
}

# Door frame (upper/lintel) tiles — composited ON TOP of wall fill as overlays
# These have partial transparency (arch shapes) so wall fill shows through
DOOR_FRAMES = {
    'dark':      (24, 14),   # Upper frame for dark door (85% opaque, dark arch)
    'darkest':   (30, 16),   # Upper frame for darkest door (28% opaque, subtle arch)
    'red_brick': (4, 10),    # Upper frame for red_brick door (64% opaque, lintel)
    'medium':    (24, 14),   # Reuse dark frame
}

# Chimney tiles from roofs.png (per roof variant, matched to roof color)
# Gable chimneys: rows 6-8 (30% coverage caps)
# Hipped chimneys: rows 11-13 (42% coverage bodies)
CHIMNEYS = {
    'gable': {
        V_DARK:  (3, 6),    # Purple-gray chimney cap, 30% coverage
        V_DARK2: (38, 6),   # Blue-gray chimney cap, 30% coverage
    },
    'hipped': {
        V_DARK:  (2, 12),   # Purple-gray chimney body, 42% coverage
        V_DARK2: (37, 12),  # Blue-gray chimney body, 42% coverage
    },
}

# ═══════════════════════════════════════════════════════════
# WINDOW/DOOR TILE MATCHING ANALYSIS (v3 polish)
# ═══════════════════════════════════════════════════════════
# RGB Euclidean distance confirmed current window assignments are optimal:
#   brick_red  fill=(173,78,67)  → brick_dark  (8,14) edge=(125,119,113) dist=78
#   brick_white fill=(220,216,190) → brick_light (0,14) edge=(150,147,146) dist=108
#   wood_blue  fill=(152,178,184) → wood_dark   (21,18) edge=(156,149,143) dist=50
#   wood_green fill=(144,194,133) → wood_dark   (21,18) edge=(156,149,143) dist=48
# No closer window tiles exist in colonial.png. All assignments kept as-is.


# ═══════════════════════════════════════════════════════════
# IMPROVED WALL CONSTRUCTION WITH WINDOWS + DOORS
# ═══════════════════════════════════════════════════════════

def make_wall_rows_v3(terrain_name, width, window_positions=None, door_col=None, 
                       window_tile='wood_dark', door_tile='dark', extra_fill_rows=0):
    """Generate wall tile grid with windows and doors (SNES RPG style).
    
    Args:
        terrain_name: key into TERRAINS dict
        width: number of tiles wide
        window_positions: list of (col, row_offset) for window placement in fill area
                         row_offset: 0 = first fill row, 1 = second fill row
        door_col: column index for the door (usually center), or None for no door
        window_tile: key into WINDOWS dict
        door_tile: key into DOORS dict  
        extra_fill_rows: additional fill rows for taller buildings
    """
    wc, wr = TERRAINS[terrain_name]
    rows = []
    
    # Get window and door tile coords
    win_gx, win_gy = WINDOWS.get(window_tile, WINDOWS['wood_dark'])
    door_gx, door_gy = DOORS.get(door_tile, DOORS['dark'])
    
    # Row 0: top edges (always show for clean transition)
    row = []
    for col in range(width):
        if col == 0:
            row.append(('wall', wc+0, wr+0))  # TL
        elif col == width-1:
            row.append(('wall', wc+2, wr+0))  # TR
        else:
            row.append(('wall', wc+1, wr+0))  # Top
    rows.append(row)
    
    # Fill rows (with optional windows)
    fill_count = 2 + extra_fill_rows
    for fill_idx in range(fill_count):
        row = []
        for col in range(width):
            # Check if this position should be a window
            is_window = False
            if window_positions:
                for win_col, win_row in window_positions:
                    if col == win_col and fill_idx == win_row:
                        is_window = True
                        break
            
            if is_window:
                row.append(('wall', win_gx, win_gy))
            elif col == 0:
                row.append(('wall', wc+0, wr+1))  # Left
            elif col == width-1:
                row.append(('wall', wc+2, wr+1))  # Right
            else:
                row.append(('wall', wc+1, wr+1))  # Fill
        rows.append(row)
    
    # Bottom row (with door)
    row = []
    for col in range(width):
        is_door = (door_col is not None and col == door_col)
        
        if is_door:
            row.append(('wall', door_gx, door_gy))
        elif col == 0:
            row.append(('wall', wc+0, wr+2))  # BL
        elif col == width-1:
            row.append(('wall', wc+2, wr+2))  # BR
        else:
            row.append(('wall', wc+1, wr+2))  # Bottom
    rows.append(row)
    
    return rows


# ═══════════════════════════════════════════════════════════
# BUILDING COMPOSITION ENGINE (same as v2 but with gap fixes)
# ═══════════════════════════════════════════════════════════

def compose_building(name, width, roof_layout, wall_layout, overlap=0,
                     wall_overlays=None, chimney_overlays=None):
    """
    Compose a building PNG with proper roof-over-wall layering.
    
    Layers (bottom to top): wall tiles → wall overlays (door frames) → roof → chimneys.
    The eave gaps from v2 are fixed by ensuring wall fills extend
    into the eave row.
    
    wall_overlays: list of (col, wall_row, gx, gy) from colonial.png
                   drawn on top of wall tiles (e.g., door frame arches)
    chimney_overlays: list of (col, roof_row, gx, gy) from roofs.png
                      drawn on top of roof tiles
    """
    roof_h = len(roof_layout)
    wall_h = len(wall_layout)
    total_h = roof_h + wall_h - overlap
    
    img = Image.new('RGBA', (width * TILE, total_h * TILE), (0, 0, 0, 0))
    
    # Step 1: Draw wall tiles first (at bottom)
    wall_y_start = roof_h - overlap
    for row_idx, row in enumerate(wall_layout):
        for col_idx, spec in enumerate(row):
            if spec is not None:
                _, gx, gy = spec
                tile = get_wall_tile(gx, gy)
                y = (wall_y_start + row_idx) * TILE
                img.paste(tile, (col_idx * TILE, y), tile)
    
    # Step 1b: Draw wall overlays (door frames composited on wall fill)
    if wall_overlays:
        for col_idx, wall_row_idx, gx, gy in wall_overlays:
            tile = get_wall_tile(gx, gy)
            y = (wall_y_start + wall_row_idx) * TILE
            img.paste(tile, (col_idx * TILE, y), tile)
    
    # Step 2: Draw roof tiles on top (alpha compositing)
    for row_idx, row in enumerate(roof_layout):
        for col_idx, spec in enumerate(row):
            if spec is not None:
                _, gx, gy = spec
                tile = get_roof_tile(gx, gy)
                img.paste(tile, (col_idx * TILE, row_idx * TILE), tile)
    
    # Step 3: Draw chimney overlays (on top of roof, from roofs.png)
    if chimney_overlays:
        for col_idx, row_idx, gx, gy in chimney_overlays:
            tile = get_roof_tile(gx, gy)
            img.paste(tile, (col_idx * TILE, row_idx * TILE), tile)
    
    # Save
    out_path = f'{SPRITES}/{name}.png'
    img.save(out_path)
    
    # Stats
    arr = np.array(img)
    opaque = (arr[:,:,3] > 10).mean() * 100
    print(f"✓ {name}: {img.size[0]}×{img.size[1]}px ({width}×{total_h} tiles), "
          f"{opaque:.0f}% opaque → {out_path}")
    return img


# ═══════════════════════════════════════════════════════════
# BUILDING RECIPES (SNES RPG style with windows + doors)
# ═══════════════════════════════════════════════════════════

print("\n" + "="*60)
print("COMPOSING BUILDINGS v3 (SNES RPG style: windows + doors)")
print("="*60)

R = lambda gx, gy: ('roof', gx, gy)

# ─── Building 1: Small 3-wide Gable (brick_red) ───────────
# SNES style: peaked roof, 1 window above door, centered door
# Fix: fill eave center with wall tile instead of None
V = V_DARK
roof_1 = [
    [None,        R(V+2, 0),  None],           # Peak
    [R(V+0, 2),   R(V+2, 1),  R(V+4, 2)],     # Upper slope
    [R(V+0, 3),   R(V+2, 2),  R(V+4, 3)],     # Middle slope
    [R(V+0, 4),   R(V+2, 3),  R(V+4, 4)],     # Lower slope
    [R(V+0, 5),   R(V+2, 4),  R(V+4, 5)],     # Eave - FIXED: fill center with roof fill
]

# Wall with window at center-top, door at center-bottom
wall_1 = make_wall_rows_v3('brick_red', 3, 
    window_positions=[(1, 0)],  # Window at center, first fill row
    door_col=1,                  # Door at center
    window_tile='brick_dark',
    door_tile='red_brick')
compose_building("building_1", 3, roof_1, wall_1, overlap=1,
    wall_overlays=[(1, 2, 4, 10)],       # Door frame (lintel) above red_brick door
    chimney_overlays=[(2, 1, 3, 6)])      # Chimney cap on right upper slope


# ─── Building 2: Medium 4-wide Gable (wood_blue) ─────────
# SNES style: wider peaked roof, 2 windows, centered door
V = V_DARK2
roof_2 = [
    [None,        R(V+1, 1),  R(V+3, 1),  None],        # Peak pair
    [R(V+0, 2),   R(V+1, 2),  R(V+3, 2),  R(V+4, 2)],  # Upper slope
    [R(V+0, 3),   R(V+1, 3),  R(V+3, 3),  R(V+4, 3)],  # Middle slope
    [R(V+0, 4),   R(V+1, 4),  R(V+3, 4),  R(V+4, 4)],  # Lower slope
    [R(V+0, 5),   R(V+1, 5),  R(V+3, 5),  R(V+4, 5)],  # Eave - FIXED: fill center
]

# Wall with 2 windows flanking where door will be
wall_2 = make_wall_rows_v3('wood_blue', 4,
    window_positions=[(1, 0), (2, 0)],  # Windows at cols 1,2 on first fill row
    door_col=1,                          # Door slightly left of center (4-wide)
    window_tile='wood_dark',
    door_tile='dark')
compose_building("building_2", 4, roof_2, wall_2, overlap=1,
    wall_overlays=[(1, 2, 24, 14)],       # Door frame (dark arch) above door
    chimney_overlays=[(0, 1, 38, 6)])     # Chimney cap on left upper slope


# ─── Building 3: Large 5-wide Hipped (brick_white) ────────
# SNES style: hipped roof, 2 windows, centered door
V = V_DARK
roof_3 = [
    [R(V+1, 9),  R(V+1,15),  R(V+2,15),  R(V+3,15),  R(V+3, 9)],  # Hip top
    [R(V+1,10),  R(V+1,17),  R(V+2,17),  R(V+3,17),  R(V+3,10)],  # Hip middle
    [R(V+1,11),  R(V+2,11),  R(V+2,11),  R(V+2,11),  R(V+3,11)],  # Eave
]

# Wall with 2 windows, centered door, extra fill row for larger building
wall_3 = make_wall_rows_v3('brick_white', 5,
    window_positions=[(1, 0), (3, 0)],  # Windows flanking center
    door_col=2,                          # Door at center col
    window_tile='brick_light',
    door_tile='dark',
    extra_fill_rows=1)                   # Taller wall for bigger building
compose_building("building_3", 5, roof_3, wall_3, overlap=0,
    wall_overlays=[(2, 3, 24, 14)],       # Door frame (dark arch) above door
    chimney_overlays=[(4, 0, 2, 12)])     # Chimney on right hip edge


# ─── Building 4: Large 5-wide Steep Hipped (wood_green) ───
# SNES style: steep hipped roof, 2 windows, centered door
V = V_DARK2
roof_4 = [
    [R(V+0,13),  R(V+1,15),  R(V+2,15),  R(V+3,15),  R(V+4,13)],  # Steep top
    [R(V+0,14),  R(V+1,17),  R(V+2,17),  R(V+3,17),  R(V+4,14)],  # Upper hip
    [R(V+0,15),  R(V+2,11),  R(V+2,11),  R(V+2,11),  R(V+4,15)],  # Lower hip
    [R(V+0,16),  R(V+2,11),  R(V+2,11),  R(V+2,11),  R(V+4,16)],  # Eave
]

# Wall with 2 windows, centered door, extra fill row
wall_4 = make_wall_rows_v3('wood_green', 5,
    window_positions=[(1, 0), (3, 0)],  # Windows flanking center
    door_col=2,                          # Door at center col
    window_tile='wood_dark',
    door_tile='darkest',
    extra_fill_rows=1)
compose_building("building_4", 5, roof_4, wall_4, overlap=0,
    wall_overlays=[(2, 3, 30, 16)],       # Door frame (arch) above darkest door
    chimney_overlays=[(0, 0, 37, 12)])    # Chimney on left steep hip edge


print("\n✅ All 4 buildings composed with SNES RPG style (v3 polished)!")
print("   Improvements over v2:")
print("   ✓ Front-facing WINDOWS on all buildings (color-distance verified optimal)")
print("   ✓ Centered DOORS with DOOR FRAMES (lintel/arch overlays above)")
print("   ✓ CHIMNEYS on all roofs (gable caps + hipped bodies from roofs.png)")
print("   ✓ Eave gaps FIXED (filled with roof/wall tiles)")
print("   ✓ Taller walls on large buildings (extra fill row)")
print("   References: Chrono Trigger, Illusion of Gaia, Secret of Mana")
