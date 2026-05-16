#!/usr/bin/env python3
"""
Shadow Leap 2D — Building Compositor (Session 44)
Composes 4 proper building PNGs from LPC tileset assets.

Sources:
  - colonial.png (1024×1024) — wall/siding tiles
  - roofs.png (2048×2048) — roof tiles
  - victorian_windows_doors.png (1024×5120) — windows + doors

Output: sprites/building_1.png through building_4.png
"""

from PIL import Image, ImageDraw
import numpy as np
import os

TILE = 32
SPRITES = os.path.expanduser('~/shadow-leap/prototype_2d/sprites')
EXTRACTED = os.path.expanduser('~/shadow-leap/prototype_2d/Terrain Downloads/extracted')

# Load source sheets
colonial = Image.open(f'{SPRITES}/colonial.png').convert('RGBA')
roofs = Image.open(f'{EXTRACTED}/lpc-roofs-v2/lpc-roofs-v2/roofs.png').convert('RGBA')
win_sheet = Image.open(f'{SPRITES}/victorian_windows_doors.png').convert('RGBA')

print(f"Colonial: {colonial.size}, Roofs: {roofs.size}, Windows: {win_sheet.size}")


# ─── Tile Analysis ─────────────────────────────────────────

def get_tile(sheet, gx, gy, w=1, h=1):
    """Extract tiles at grid position (gx, gy), w×h tiles."""
    return sheet.crop((gx*TILE, gy*TILE, (gx+w)*TILE, (gy+h)*TILE))


def tile_stats(sheet, gx, gy):
    """Analyze a single 32×32 tile."""
    tile = np.array(get_tile(sheet, gx, gy))
    alpha = tile[:, :, 3]
    alpha_mean = alpha.mean()
    if alpha_mean < 100:
        return None
    # Only analyze opaque pixels
    mask = alpha > 100
    if mask.sum() < 100:
        return None
    rgb = tile[:, :, :3][mask]
    return {
        'gx': gx, 'gy': gy,
        'alpha': alpha_mean,
        'r': float(rgb[:, 0].mean()),
        'g': float(rgb[:, 1].mean()),
        'b': float(rgb[:, 2].mean()),
        'var': float(rgb.std()),
        'brightness': float(rgb.mean()),
    }


# ─── Find Best Wall Tiles from colonial.png ────────────────

print("\n=== Scanning colonial.png for solid wall tiles ===")
wall_tiles = []
for gy in range(32):
    for gx in range(32):
        stats = tile_stats(colonial, gx, gy)
        if stats and stats['alpha'] > 220 and stats['var'] < 30:
            wall_tiles.append(stats)

wall_tiles.sort(key=lambda x: x['var'])
print(f"Found {len(wall_tiles)} solid wall tile candidates")

# Group by color family
def find_by_color(tiles, r_range, g_range, b_range, max_var=30):
    """Find tiles matching a color range."""
    results = []
    for t in tiles:
        if (r_range[0] <= t['r'] <= r_range[1] and
            g_range[0] <= t['g'] <= g_range[1] and
            b_range[0] <= t['b'] <= b_range[1] and
            t['var'] <= max_var):
            results.append(t)
    return sorted(results, key=lambda x: x['var'])

cream_walls = find_by_color(wall_tiles, (150, 230), (130, 210), (90, 180))
gray_walls = find_by_color(wall_tiles, (90, 160), (90, 160), (90, 170), max_var=25)
dark_walls = find_by_color(wall_tiles, (50, 110), (50, 110), (50, 120))
tan_walls = find_by_color(wall_tiles, (110, 170), (90, 150), (60, 130))

print(f"  Cream: {len(cream_walls)}, Gray: {len(gray_walls)}, Dark: {len(dark_walls)}, Tan: {len(tan_walls)}")

for name, tiles in [("Cream", cream_walls), ("Gray", gray_walls), ("Dark", dark_walls), ("Tan", tan_walls)]:
    if tiles:
        t = tiles[0]
        print(f"  Best {name}: grid({t['gx']},{t['gy']}) RGB=({t['r']:.0f},{t['g']:.0f},{t['b']:.0f}) var={t['var']:.1f}")


# ─── Find Roof Tiles from roofs.png ────────────────────────

print("\n=== Scanning roofs.png for dark roof tiles ===")
roof_tiles = []
for gy in range(40):  # Top 40 rows
    for gx in range(64):
        stats = tile_stats(roofs, gx, gy)
        if stats and stats['alpha'] > 200 and stats['brightness'] < 130:
            roof_tiles.append(stats)

roof_tiles.sort(key=lambda x: x['brightness'])
print(f"Found {len(roof_tiles)} dark roof tile candidates")

# Find dark blue-gray roof tiles (Veil aesthetic)
blue_gray_roofs = find_by_color(roof_tiles, (40, 120), (40, 120), (60, 150), max_var=40)
dark_roofs = find_by_color(roof_tiles, (30, 100), (30, 100), (30, 110), max_var=40)
print(f"  Blue-gray: {len(blue_gray_roofs)}, Dark: {len(dark_roofs)}")

for name, tiles in [("Blue-gray", blue_gray_roofs), ("Dark", dark_roofs)]:
    if tiles:
        t = tiles[0]
        print(f"  Best {name}: grid({t['gx']},{t['gy']}) RGB=({t['r']:.0f},{t['g']:.0f},{t['b']:.0f}) var={t['var']:.1f}")


# ─── Find Window Tiles from victorian_windows_doors.png ────

print("\n=== Scanning windows sheet for lit + dark windows ===")
# Report says: dark windows in top ~1000px, lit windows at ~y=1024
# Windows are 1×2 tiles (32×64)

# Sample some window areas
for name, gx, gy in [
    ("Dark win A", 0, 0), ("Dark win B", 2, 0), ("Dark win C", 4, 0),
    ("Lit win A", 2, 32), ("Lit win B", 4, 32), ("Lit win C", 6, 32),
    ("Lit win D", 8, 32), ("Lit win E", 10, 32),
]:
    stats = tile_stats(win_sheet, gx, gy)
    if stats:
        print(f"  {name}: grid({gx},{gy}) RGB=({stats['r']:.0f},{stats['g']:.0f},{stats['b']:.0f}) alpha={stats['alpha']:.0f} var={stats['var']:.1f}")

# Find lit windows (warm colors: high R, medium G, low B)
print("\nSearching for warm lit windows around y=1024...")
lit_win_candidates = []
for gx in range(32):
    for gy in range(30, 36):  # y=960-1152 area
        stats = tile_stats(win_sheet, gx, gy)
        if stats and stats['r'] > 120 and stats['r'] > stats['b']:
            lit_win_candidates.append(stats)

lit_win_candidates.sort(key=lambda x: x['r'] - x['b'], reverse=True)
print(f"Found {len(lit_win_candidates)} warm-colored window tiles")
for t in lit_win_candidates[:5]:
    print(f"  grid({t['gx']},{t['gy']}) RGB=({t['r']:.0f},{t['g']:.0f},{t['b']:.0f}) var={t['var']:.1f}")


# ─── Find Door Tiles ───────────────────────────────────────

print("\n=== Scanning windows sheet for door tiles ===")
# Doors should be in the lower portion of the windows sheet
# Look for darker, taller tiles in the y=2000-4000 range
door_candidates = []
for gx in range(32):
    for gy in range(80, 130):  # y=2560-4160
        stats = tile_stats(win_sheet, gx, gy)
        if stats and stats['brightness'] < 120 and stats['alpha'] > 200:
            door_candidates.append(stats)

door_candidates.sort(key=lambda x: x['var'])
print(f"Found {len(door_candidates)} door-area tile candidates")
for t in door_candidates[:5]:
    print(f"  grid({t['gx']},{t['gy']}) RGB=({t['r']:.0f},{t['g']:.0f},{t['b']:.0f}) var={t['var']:.1f}")


# ═══════════════════════════════════════════════════════════
# COMPOSE BUILDINGS
# ═══════════════════════════════════════════════════════════

def compose_building(name, width_t, height_t, layout, descriptions):
    """
    Compose a building from a tile layout.
    layout: list of rows, each row is list of (sheet, gx, gy) or None or 'DRAW:color'
    """
    img = Image.new('RGBA', (width_t * TILE, height_t * TILE), (0, 0, 0, 0))
    
    for row_idx, row in enumerate(layout):
        for col_idx, spec in enumerate(row):
            if spec is None:
                continue
            if isinstance(spec, str) and spec.startswith('DRAW:'):
                # Draw a colored rectangle as fallback
                color = spec.split(':')[1]
                r, g, b = int(color[0:2], 16), int(color[2:4], 16), int(color[4:6], 16)
                draw = ImageDraw.Draw(img)
                x0, y0 = col_idx * TILE, row_idx * TILE
                draw.rectangle([x0, y0, x0 + TILE - 1, y0 + TILE - 1], fill=(r, g, b, 255))
            else:
                sheet, gx, gy = spec
                tile = get_tile(sheet, gx, gy)
                img.paste(tile, (col_idx * TILE, row_idx * TILE), tile)
    
    # Save
    out_path = f'{SPRITES}/{name}.png'
    img.save(out_path)
    print(f"\n✓ Saved {name} ({width_t*TILE}×{height_t*TILE}px) → {out_path}")
    print(f"  Layout: {descriptions}")
    return img


# ─── Pick best tiles for each role ─────────────────────────

def pick_wall(candidates, fallback_color="8B7D6B"):
    """Pick best wall tile or return draw fallback."""
    if candidates:
        t = candidates[0]
        return (colonial, t['gx'], t['gy'])
    return f'DRAW:{fallback_color}'

def pick_roof(candidates, fallback_color="3D3D4D"):
    if candidates:
        t = candidates[0]
        return (roofs, t['gx'], t['gy'])
    return f'DRAW:{fallback_color}'

def pick_alt_wall(candidates, idx=1, fallback_color="7A6E5E"):
    """Pick an alternate wall tile for variety."""
    if len(candidates) > idx:
        t = candidates[idx]
        return (colonial, t['gx'], t['gy'])
    return pick_wall(candidates, fallback_color)


# Select tiles
# Wall: use cream/tan for base walls (most common in colonial buildings)
W_cream = pick_wall(cream_walls, "C8B896")
W_cream2 = pick_alt_wall(cream_walls, 1, "BEB08A")
W_gray = pick_wall(gray_walls, "8A8A8E")  
W_gray2 = pick_alt_wall(gray_walls, 1, "7E7E84")
W_dark = pick_wall(dark_walls, "5A5A60")
W_tan = pick_wall(tan_walls, "A08868")
W_tan2 = pick_alt_wall(tan_walls, 1, "988060")

# Roof
R_dark = pick_roof(dark_roofs, "3A3A48")
R_blue = pick_roof(blue_gray_roofs, "404058")

# We'll also pick a second roof tile for variety
R_dark2 = pick_roof(dark_roofs[1:] if len(dark_roofs) > 1 else dark_roofs, "3E3E4C") if dark_roofs else 'DRAW:3E3E4C'
if isinstance(R_dark2, str):
    pass
elif len(dark_roofs) > 1:
    t = dark_roofs[1]
    R_dark2 = (roofs, t['gx'], t['gy'])

# Windows: use lit windows if found, otherwise draw warm rectangles
if lit_win_candidates:
    t = lit_win_candidates[0]
    WIN_lit = (win_sheet, t['gx'], t['gy'])
    print(f"\nUsing lit window: grid({t['gx']},{t['gy']})")
else:
    WIN_lit = 'DRAW:FFB060'
    print("\nNo lit window found, using drawn fallback")

# Also get a dark window
dark_win_candidates = []
for gx in range(32):
    for gy in range(0, 20):
        stats = tile_stats(win_sheet, gx, gy)
        if stats and stats['brightness'] < 80 and stats['alpha'] > 200:
            dark_win_candidates.append(stats)
dark_win_candidates.sort(key=lambda x: x['brightness'])

if dark_win_candidates:
    t = dark_win_candidates[0]
    WIN_dark = (win_sheet, t['gx'], t['gy'])
    print(f"Using dark window: grid({t['gx']},{t['gy']})")
else:
    WIN_dark = 'DRAW:2A2A35'
    print("No dark window found, using drawn fallback")

# Door: use dark tile from door area, or draw
if door_candidates:
    t = door_candidates[0]
    DOOR = (win_sheet, t['gx'], t['gy'])
    print(f"Using door tile: grid({t['gx']},{t['gy']})")
else:
    DOOR = 'DRAW:3A2820'
    print("No door tile found, using drawn fallback")


# ═══════════════════════════════════════════════════════════
# BUILDING LAYOUTS
# ═══════════════════════════════════════════════════════════

print("\n" + "="*60)
print("COMPOSING BUILDINGS")
print("="*60)

# Building 1: Small gray/stone residence (3×5 tiles = 96×160px)
# Veil-affected, dark and moody
compose_building("building_1", 3, 5, [
    [R_dark,  R_dark,  R_dark],      # Roof top
    [R_blue,  R_blue,  R_blue],      # Roof bottom  
    [W_gray,  WIN_dark, W_gray],     # Wall + dark window
    [W_gray,  WIN_lit,  W_gray],     # Wall + lit window (warm glow)
    [W_gray2, DOOR,     W_gray2],    # Wall + door
], "Small gray stone, dark roof, 1 lit + 1 dark window, door")

# Building 2: Small cream/tan residence (3×5 tiles = 96×160px)
# Slightly warmer, less Veil-affected
compose_building("building_2", 3, 5, [
    [R_blue,  R_blue,  R_blue],      # Roof
    [R_dark,  R_dark,  R_dark],      # Roof lower
    [W_cream, WIN_lit,  W_cream],    # Wall + lit window
    [W_cream, WIN_dark, W_cream],    # Wall + dark window
    [W_cream2, DOOR,    W_cream2],   # Wall + door
], "Small cream/tan, blue-gray roof, 1 lit + 1 dark window")

# Building 3: Large neutral building (5×6 tiles = 160×192px)
# Wider, more imposing — could be a shop or clinic
compose_building("building_3", 5, 6, [
    [R_dark,  R_dark,  R_dark,  R_dark,  R_dark],    # Roof top
    [R_blue,  R_blue,  R_blue,  R_blue,  R_blue],    # Roof bottom
    [W_tan,   WIN_dark, W_tan,  WIN_dark, W_tan],    # Wall + 2 dark windows
    [W_tan,   W_tan,    W_tan,  W_tan,    W_tan],    # Solid wall
    [W_tan,   WIN_lit,  W_tan,  WIN_lit,  W_tan],    # Wall + 2 lit windows
    [W_tan2,  W_tan2,   DOOR,   W_tan2,   W_tan2],  # Wall + centered door
], "Large tan, dark roof, 2 lit + 2 dark windows, centered door")

# Building 4: Large dark building (4×6 tiles = 128×192px)
# Tallest, most ominous — Veil-heavy
compose_building("building_4", 4, 6, [
    [R_dark,  R_dark,  R_dark,  R_dark],     # Roof top
    [R_dark2 if not isinstance(R_dark2, str) else R_dark, R_blue, R_blue, R_dark2 if not isinstance(R_dark2, str) else R_dark],   # Roof bottom
    [W_dark,  WIN_dark, WIN_dark, W_dark],   # Wall + 2 dark windows
    [W_dark,  W_dark,   W_dark,   W_dark],   # Solid wall
    [W_dark,  WIN_lit,  WIN_lit,  W_dark],   # Wall + 2 lit windows
    [W_gray,  DOOR,     DOOR,     W_gray],   # Wall + wide door
], "Large dark, ominous roof, 2 lit + 2 dark windows, wide door")


# ─── Also create a diagnostic image showing all tiles used ──

print("\n=== Building diagnostic ===")
diag = Image.new('RGBA', (8 * TILE, 6 * TILE), (40, 40, 50, 255))
draw = ImageDraw.Draw(diag)

tile_specs = [
    ("W_cream", W_cream), ("W_gray", W_gray), ("W_dark", W_dark), ("W_tan", W_tan),
    ("R_dark", R_dark), ("R_blue", R_blue), ("WIN_lit", WIN_lit), ("WIN_dark", WIN_dark),
]

for i, (label, spec) in enumerate(tile_specs):
    col, row = i % 4, i // 4
    x, y = col * 2 * TILE, row * 2 * TILE
    
    if isinstance(spec, str) and spec.startswith('DRAW:'):
        color = spec.split(':')[1]
        r, g, b = int(color[0:2], 16), int(color[2:4], 16), int(color[4:6], 16)
        draw.rectangle([x, y, x + TILE - 1, y + TILE - 1], fill=(r, g, b, 255))
        draw.text((x, y + TILE + 2), f"{label}\n(drawn)", fill=(200, 200, 200))
    else:
        sheet, gx, gy = spec
        tile = get_tile(sheet, gx, gy)
        diag.paste(tile, (x, y), tile)
        draw.text((x, y + TILE + 2), f"{label}\n({gx},{gy})", fill=(200, 200, 200))

diag_path = f'{SPRITES}/building_diagnostic.png'
diag.save(diag_path)
print(f"Diagnostic saved → {diag_path}")

print("\n✅ All buildings composed! Update main_scene_builder.gd to load building_1..4.png")
