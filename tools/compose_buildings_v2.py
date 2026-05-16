#!/usr/bin/env python3
"""
Shadow Leap 2D — Building Compositor v2 (Session 44)
Uses EXACT assembly patterns decoded from roofs-preview.tmx.

Building anatomy (SNES RPG style):
  - Roof dominates (60-70% of building height)
  - Roof has shaped/triangular outline with transparency
  - Wall is thin strip at bottom with autotile edges
  - Roof drawn ON TOP of wall (alpha compositing at overlap)

Sources:
  - colonial.png (32×32 grid) — wall autotiles
  - roofs.png (64×64 grid) — shaped roof tiles
  
Color variants in roofs.png: every 5 columns (0-4, 5-9, 10-14, ...)
Wall terrains in colonial.png: 3×3 autotile blocks at specific positions
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

# Analyze each variant's darkness for Veil aesthetic
print("\n=== Roof color variants (10 variants, 5 cols each) ===")
variant_brightness = []
for vi in range(10):
    V = vi * 5
    # Sample center tile at row 2 (slope fill — representative)
    tile = np.array(get_roof_tile(V + 2, 2))
    mask = tile[:,:,3] > 10
    if mask.sum() > 0:
        rgb = tile[:,:,:3][mask]
        bright = float(rgb.mean())
        r, g, b = float(rgb[:,0].mean()), float(rgb[:,1].mean()), float(rgb[:,2].mean())
        variant_brightness.append((vi, V, bright, r, g, b))
        print(f"  Variant {vi} (V={V}): RGB=({r:.0f},{g:.0f},{b:.0f}) brightness={bright:.0f}")

# Sort by darkness
variant_brightness.sort(key=lambda x: x[2])
print(f"\n  By brightness: {[(v[0], f'V={v[1]}', f'b={v[2]:.0f}') for v in variant_brightness]}")

# Pick COOL-TONED variants for Veil aesthetic (blue-gray, not red/green)
# Variant 0: purple-gray RGB=(65,59,75) — excellent for Veil
# Variant 7: blue-gray RGB=(60,66,70) — excellent for Veil
V_DARK = 0     # Variant 0: purple-gray (cool, moody)
V_DARK2 = 35   # Variant 7: blue-gray (cool, slightly lighter)
print(f"  Selected: V_DARK={V_DARK} (purple-gray), V_DARK2={V_DARK2} (blue-gray)")


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

# Analyze wall terrain colors
print("\n=== Wall terrain colors ===")
for name, (wc, wr) in TERRAINS.items():
    tile = np.array(get_wall_tile(wc+1, wr+1))  # Center fill tile
    mask = tile[:,:,3] > 10
    if mask.sum() > 0:
        rgb = tile[:,:,:3][mask]
        r, g, b = float(rgb[:,0].mean()), float(rgb[:,1].mean()), float(rgb[:,2].mean())
        print(f"  {name}: fill tile ({wc+1},{wr+1}) RGB=({r:.0f},{g:.0f},{b:.0f})")


# ═══════════════════════════════════════════════════════════
# BUILDING COMPOSITION ENGINE
# ═══════════════════════════════════════════════════════════

def make_wall_rows(terrain_name, width, use_top_edges=True):
    """Generate wall tile grid from autotile terrain.
    
    use_top_edges: True for hipped (wall top is visible), 
                   False for gable (roof overlaps wall top)
    """
    wc, wr = TERRAINS[terrain_name]
    rows = []
    
    if use_top_edges:
        # Row 0: top edges
        row = []
        for col in range(width):
            if col == 0:
                row.append(('wall', wc+0, wr+0))  # TL
            elif col == width-1:
                row.append(('wall', wc+2, wr+0))  # TR
            else:
                row.append(('wall', wc+1, wr+0))  # Top
        rows.append(row)
    
    # Fill row(s)
    fill_count = 2 if use_top_edges else 2
    for _ in range(fill_count):
        row = []
        for col in range(width):
            if col == 0:
                row.append(('wall', wc+0, wr+1))  # Left
            elif col == width-1:
                row.append(('wall', wc+2, wr+1))  # Right
            else:
                row.append(('wall', wc+1, wr+1))  # Fill
        rows.append(row)
    
    # Bottom row
    row = []
    for col in range(width):
        if col == 0:
            row.append(('wall', wc+0, wr+2))  # BL
        elif col == width-1:
            row.append(('wall', wc+2, wr+2))  # BR
        else:
            row.append(('wall', wc+1, wr+2))  # Bottom
    rows.append(row)
    
    return rows


def compose_building(name, width, roof_layout, wall_layout, overlap=0):
    """
    Compose a building PNG.
    
    roof_layout: list of rows, each row is list of ('roof', gx, gy) or None
    wall_layout: list of rows, each row is list of ('wall', gx, gy)
    overlap: number of rows where roof overlaps wall (gable=1, hipped=0)
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
    
    # Step 2: Draw roof tiles on top (alpha compositing)
    for row_idx, row in enumerate(roof_layout):
        for col_idx, spec in enumerate(row):
            if spec is not None:
                _, gx, gy = spec
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
# BUILDING RECIPES (from TMX decode)
# ═══════════════════════════════════════════════════════════

print("\n" + "="*60)
print("COMPOSING BUILDINGS (TMX-verified recipes)")
print("="*60)

# ─── Building 1: Small 3-wide Gable ────────────────────────
# Classic peaked house, dark roof, brick walls
V = V_DARK
R = lambda gx, gy: ('roof', gx, gy)

roof_1 = [
    [None,        R(V+2, 0),  None],           # Peak
    [R(V+0, 2),   R(V+2, 1),  R(V+4, 2)],     # Upper slope
    [R(V+0, 3),   R(V+2, 2),  R(V+4, 3)],     # Middle slope
    [R(V+0, 4),   R(V+2, 3),  R(V+4, 4)],     # Lower slope
    [R(V+0, 5),   None,        R(V+4, 5)],     # Eave (center = wall shows through)
]
wall_1 = make_wall_rows('brick_red', 3, use_top_edges=False)
compose_building("building_1", 3, roof_1, wall_1, overlap=1)


# ─── Building 2: Medium 4-wide Gable ──────────────────────
# Wider peaked house, 2nd darkest roof, blue wood walls
V = V_DARK2
roof_2 = [
    [None,        R(V+1, 1),  R(V+3, 1),  None],        # Peak pair
    [R(V+0, 2),   R(V+1, 2),  R(V+3, 2),  R(V+4, 2)],  # Upper slope
    [R(V+0, 3),   R(V+1, 3),  R(V+3, 3),  R(V+4, 3)],  # Middle slope
    [R(V+0, 4),   R(V+1, 4),  R(V+3, 4),  R(V+4, 4)],  # Lower slope
    [R(V+0, 5),   None,        None,        R(V+4, 5)],  # Eave
]
wall_2 = make_wall_rows('wood_blue', 4, use_top_edges=False)
compose_building("building_2", 4, roof_2, wall_2, overlap=1)


# ─── Building 3: Large 5-wide Hipped ──────────────────────
# Wider building with flat-top hipped roof, white brick walls
V = V_DARK
roof_3 = [
    [R(V+1, 9),  R(V+1,15),  R(V+2,15),  R(V+3,15),  R(V+3, 9)],  # Hip top
    [R(V+1,10),  R(V+1,17),  R(V+2,17),  R(V+3,17),  R(V+3,10)],  # Hip middle
    [R(V+1,11),  R(V+2,11),  R(V+2,11),  R(V+2,11),  R(V+3,11)],  # Eave
]
wall_3 = make_wall_rows('brick_white', 5, use_top_edges=True)
compose_building("building_3", 5, roof_3, wall_3, overlap=0)


# ─── Building 4: Large 5-wide Steep Hipped ────────────────
# Tallest building, steep hipped roof, green wood walls
V = V_DARK2
roof_4 = [
    [R(V+0,13),  R(V+1,15),  R(V+2,15),  R(V+3,15),  R(V+4,13)],  # Steep top
    [R(V+0,14),  R(V+1,17),  R(V+2,17),  R(V+3,17),  R(V+4,14)],  # Upper hip
    [R(V+0,15),  R(V+2,11),  R(V+2,11),  R(V+2,11),  R(V+4,15)],  # Lower hip
    [R(V+0,16),  R(V+2,11),  R(V+2,11),  R(V+2,11),  R(V+4,16)],  # Eave
]
wall_4 = make_wall_rows('wood_green', 5, use_top_edges=True)
compose_building("building_4", 5, roof_4, wall_4, overlap=0)


print("\n✅ All 4 buildings composed with TMX-verified LPC assembly!")
print("   Roof shapes: peaked gable + hipped (proper SNES RPG style)")
print("   Wall autotile: correct corner/edge/fill from colonial.tsx")
