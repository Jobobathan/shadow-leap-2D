#!/usr/bin/env python3
"""Generate proper Godot 4 scene/resource files for Shadow Leap 2D.

Replaces monolithic main_scene_builder.gd with proper .tscn/.tres files.
Each entity becomes its own scene. Every node is individually editable in Godot.

Run once:  cd prototype_2d && python3 tools/generate_scene_files.py
"""

import os

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def write_file(rel_path, content):
    full = os.path.join(PROJECT, rel_path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w') as f:
        f.write(content)
    print(f"  ✓ {rel_path}")


# ════════════════════════════════════════════════════════════
# SpriteFrames .tres Generation
# ════════════════════════════════════════════════════════════

def make_sprite_frames(tex_path, cw, ch, anims):
    """Generate SpriteFrames .tres file content.

    anims: list of {name, speed, loop, frames: [(col, row), ...]}
    """
    subs = []       # (sub_id, x, y, w, h)
    anim_ids = []   # per-animation list of sub_resource IDs
    idx = 0
    for a in anims:
        ids = []
        for col, row in a['frames']:
            idx += 1
            sid = f"AtlasTexture_{idx:04d}"
            subs.append((sid, col * cw, row * ch, cw, ch))
            ids.append(sid)
        anim_ids.append(ids)

    ls = len(subs) + 2  # ext_resource + sub_resources + resource
    out = [f'[gd_resource type="SpriteFrames" load_steps={ls} format=3]', '',
           f'[ext_resource type="Texture2D" path="{tex_path}" id="1_sheet"]', '']

    for sid, x, y, w, h in subs:
        out += [f'[sub_resource type="AtlasTexture" id="{sid}"]',
                'atlas = ExtResource("1_sheet")',
                f'region = Rect2({x}, {y}, {w}, {h})',
                'filter_clip = true', '']

    # Build animations array
    parts = []
    for i, a in enumerate(anims):
        fs = ', '.join(
            f'{{"duration": 1.0, "texture": SubResource("{fid}")}}'
            for fid in anim_ids[i])
        loop = 'true' if a['loop'] else 'false'
        parts.append(
            f'{{\n"frames": [{fs}],\n"loop": {loop},\n'
            f'"name": &"{a["name"]}",\n"speed": {a["speed"]}\n}}')

    out.append('[resource]')
    out.append('animations = [' + ', '.join(parts) + ']')
    out.append('')
    return '\n'.join(out)


def dir4(prefix, base_row, cols, speed, loop):
    """4-directional animations (up/left/down/right), one row per direction."""
    return [{'name': f'{prefix}_{d}', 'speed': speed, 'loop': loop,
             'frames': [(c, base_row + i) for c in cols]}
            for i, d in enumerate(['up', 'left', 'down', 'right'])]


def dir4_same(prefix, row, cols, speed, loop):
    """4-directional anims using same row for all directions."""
    return [{'name': f'{prefix}_{d}', 'speed': speed, 'loop': loop,
             'frames': [(c, row) for c in cols]}
            for d in ['up', 'left', 'down', 'right']]


def gen_kage_tres():
    a = (dir4('idle', 0, [0, 1], 2.0, True) +
         dir4('run', 4, list(range(1, 9)), 10.0, True) +
         dir4('slash', 8, list(range(6)), 12.0, False) +
         dir4_same('hurt', 12, list(range(6)), 8.0, False))
    return make_sprite_frames('res://sprites/kage_lpc.png', 128, 128, a)


def gen_akari_tres():
    a = (dir4('idle', 0, [0, 1], 2.0, True) +
         dir4('run', 4, list(range(1, 9)), 10.0, True) +
         dir4('slash', 8, list(range(6)), 12.0, False) +
         dir4_same('hurt', 12, list(range(6)), 8.0, False))
    return make_sprite_frames('res://sprites/akari_lpc.png', 64, 64, a)


def gen_skeleton_tres():
    a = (dir4('idle', 0, [0], 2.0, True) +
         dir4('walk', 4, list(range(1, 9)), 8.0, True) +
         dir4('slash', 8, list(range(6)), 10.0, False) +
         dir4_same('hurt', 12, list(range(6)), 8.0, False))
    return make_sprite_frames('res://sprites/skeleton_topdown.png', 64, 64, a)


def gen_big_demon_tres():
    a = [
        {'name': 'idle', 'speed': 4.0, 'loop': True,
         'frames': [(i, 0) for i in range(4)]},
        {'name': 'walk', 'speed': 6.0, 'loop': True,
         'frames': [(i, 1) for i in range(4)]},
        {'name': 'slash', 'speed': 8.0, 'loop': False,
         'frames': [(i, 3) for i in range(4)]},
        {'name': 'hurt', 'speed': 6.0, 'loop': False,
         'frames': [(0, 4), (1, 4)]},
    ]
    return make_sprite_frames('res://sprites/big_demon_sheet.png', 64, 64, a)


# ════════════════════════════════════════════════════════════
# Entity .tscn Generation
# ════════════════════════════════════════════════════════════

def gen_kage_tscn():
    return """\
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/player_2d.gd" id="1_script"]
[ext_resource type="SpriteFrames" path="res://resources/kage_frames.tres" id="2_frames"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 16.0

[node name="Kage" type="CharacterBody2D" groups=["party_member"]]
script = ExtResource("1_script")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
scale = Vector2(1.02, 1.02)
sprite_frames = ExtResource("2_frames")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")
"""


def gen_akari_tscn():
    return """\
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/player_2d.gd" id="1_script"]
[ext_resource type="SpriteFrames" path="res://resources/akari_frames.tres" id="2_frames"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 16.0

[node name="Akari" type="CharacterBody2D" groups=["party_member"]]
script = ExtResource("1_script")
is_ranged = true

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
scale = Vector2(2.03, 2.03)
sprite_frames = ExtResource("2_frames")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")
"""


def gen_small_demon_tscn():
    return """\
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/small_demon_ai_2d.gd" id="1_script"]
[ext_resource type="SpriteFrames" path="res://resources/skeleton_frames.tres" id="2_frames"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 14.0

[node name="SmallDemon" type="CharacterBody2D"]
script = ExtResource("1_script")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
scale = Vector2(2.0, 2.0)
sprite_frames = ExtResource("2_frames")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")

[node name="NavigationAgent2D" type="NavigationAgent2D" parent="."]
path_desired_distance = 8.0
target_desired_distance = 8.0
"""


def gen_big_demon_tscn():
    return """\
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/big_demon_ai_2d.gd" id="1_script"]
[ext_resource type="SpriteFrames" path="res://resources/big_demon_frames.tres" id="2_frames"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 36.0

[node name="BigDemon" type="CharacterBody2D"]
script = ExtResource("1_script")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
scale = Vector2(4.0, 4.0)
sprite_frames = ExtResource("2_frames")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")

[node name="NavigationAgent2D" type="NavigationAgent2D" parent="."]
path_desired_distance = 16.0
target_desired_distance = 16.0
"""


# ════════════════════════════════════════════════════════════
# Main Scene .tscn Generation
# ════════════════════════════════════════════════════════════

def gen_main_tscn():
    """Generate main.tscn with all nodes individually placed."""

    SCALE = 1.5  # Building/prop scale
    PROP_SCALE = 1.5

    # ── Building definitions ──
    buildings = [
        {'name': 'House1', 'pos': (180, 640), 'tex': 'bld1',
         'tw': 96, 'th': 256, 'tint': (0.95, 0.90, 0.90), 'lights': 1},
        {'name': 'House2', 'pos': (180, 120), 'tex': 'bld2',
         'tw': 128, 'th': 256, 'tint': (0.88, 0.92, 0.98), 'lights': 1},
        {'name': 'House3', 'pos': (1020, 120), 'tex': 'bld3',
         'tw': 160, 'th': 256, 'tint': (0.95, 0.93, 0.88), 'lights': 2},
        {'name': 'House4', 'pos': (1020, 640), 'tex': 'bld4',
         'tw': 160, 'th': 288, 'tint': (0.85, 0.95, 0.85), 'lights': 2},
    ]

    # ── Cover definitions ──
    covers = [
        {'name': 'Cover_Rock1', 'pos': (350, 450), 'tex': 'rocks',
         'region': (384, 0, 128, 128), 'scale': (1.5, 1.5), 'col': (120, 90)},
        {'name': 'Cover_Barrel', 'pos': (850, 350), 'tex': 'barrels',
         'region': (0, 0, 32, 64), 'scale': (2.5, 2.5), 'col': (50, 75)},
        {'name': 'Cover_Rock2', 'pos': (450, 180), 'tex': 'rocks',
         'region': (0, 0, 96, 96), 'scale': (1.5, 1.5), 'col': (90, 60)},
    ]

    # ── Tree definitions ──
    trees = [
        {'pos': (60, 60), 'region': (0, 0, 128, 192)},
        {'pos': (60, 700), 'region': (320, 0, 128, 192)},
        {'pos': (1140, 60), 'region': (640, 0, 128, 192)},
        {'pos': (1140, 700), 'region': (480, 0, 64, 128)},
        {'pos': (600, -200), 'region': (320, 0, 64, 128)},
    ]

    town = (600, 330)
    demons = [(600, 80), (100, 380), (1100, 380)]

    # ── Count: 26 ext + 17 sub + 1 = 44 ──
    o = []
    o.append('[gd_scene load_steps=44 format=3]')
    o.append('')

    # ── External Resources ──
    ext = [
        ('Script', 'res://scripts/main.gd', 'main_script'),
        ('Script', 'res://scripts/grid_drawer.gd', 'grid_script'),
        ('Script', 'res://scripts/nav_builder.gd', 'nav_script'),
        ('Script', 'res://scripts/ui_updater.gd', 'ui_script'),
        ('Script', 'res://scripts/camera_follow_2d.gd', 'cam_script'),
        ('Script', 'res://scripts/turn_manager_2d.gd', 'tm_script'),
        ('Script', 'res://scripts/engagement_manager_2d.gd', 'em_script'),
        ('Script', 'res://scripts/tactical_cursor_2d.gd', 'tc_script'),
        ('Script', 'res://scripts/party_manager_2d.gd', 'pm_script'),
        ('Texture2D', 'res://sprites/ground_tile.png', 'ground_tex'),
        ('Texture2D', 'res://sprites/building_1.png', 'bld1'),
        ('Texture2D', 'res://sprites/building_2.png', 'bld2'),
        ('Texture2D', 'res://sprites/building_3.png', 'bld3'),
        ('Texture2D', 'res://sprites/building_4.png', 'bld4'),
        ('Texture2D', 'res://sprites/rocks.png', 'rocks'),
        ('Texture2D', 'res://sprites/barrels.png', 'barrels'),
        ('Texture2D', 'res://sprites/conifers.png', 'conifers'),
        ('Texture2D', 'res://sprites/fountain_large.png', 'fountain_tex'),
        ('Texture2D', 'res://sprites/fountain_large_shadow.png', 'fountain_sh_tex'),
        ('Texture2D', 'res://sprites/foodog.png', 'foodog_tex'),
        ('Texture2D', 'res://sprites/foodog_shadow.png', 'foodog_sh_tex'),
        ('Texture2D', 'res://sprites/car_parked.png', 'car_tex'),
        ('PackedScene', 'res://scenes/entities/kage.tscn', 'kage_scene'),
        ('PackedScene', 'res://scenes/entities/akari.tscn', 'akari_scene'),
        ('PackedScene', 'res://scenes/entities/small_demon.tscn', 'demon_scene'),
        ('PackedScene', 'res://scenes/entities/big_demon.tscn', 'boss_scene'),
    ]
    for etype, path, eid in ext:
        o.append(f'[ext_resource type="{etype}" path="{path}" id="{eid}"]')
    o.append('')

    # ── Sub-resources ──

    # Light gradient (radial white→transparent)
    o.append('[sub_resource type="Gradient" id="Gradient_1"]')
    o.append('colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0)')
    o.append('')
    o.append('[sub_resource type="GradientTexture2D" id="LightTex_1"]')
    o.append('gradient = SubResource("Gradient_1")')
    o.append('fill = 1')
    o.append('fill_from = Vector2(0.5, 0.5)')
    o.append('fill_to = Vector2(0.5, 0)')
    o.append('width = 128')
    o.append('height = 128')
    o.append('')

    # Building collision shapes (4 unique sizes)
    for i, b in enumerate(buildings):
        vw = b['tw'] * SCALE
        vh = b['th'] * SCALE
        o.append(f'[sub_resource type="RectangleShape2D" id="BldShape_{i+1}"]')
        o.append(f'size = Vector2({vw}, {vh * 0.6})')
        o.append('')

    # Cover collision shapes
    for i, c in enumerate(covers):
        o.append(f'[sub_resource type="RectangleShape2D" id="CoverShape_{i+1}"]')
        o.append(f'size = Vector2({c["col"][0]}, {c["col"][1]})')
        o.append('')

    # Cover atlas textures
    for i, c in enumerate(covers):
        r = c['region']
        o.append(f'[sub_resource type="AtlasTexture" id="CoverAtlas_{i+1}"]')
        o.append(f'atlas = ExtResource("{c["tex"]}")')
        o.append(f'region = Rect2({r[0]}, {r[1]}, {r[2]}, {r[3]})')
        o.append('filter_clip = true')
        o.append('')

    # Tree atlas textures
    for i, t in enumerate(trees):
        r = t['region']
        o.append(f'[sub_resource type="AtlasTexture" id="TreeAtlas_{i+1}"]')
        o.append('atlas = ExtResource("conifers")')
        o.append(f'region = Rect2({r[0]}, {r[1]}, {r[2]}, {r[3]})')
        o.append('filter_clip = true')
        o.append('')

    # ══════════════════════════════════════════════════════
    # NODE TREE — every node individually selectable/movable
    # ══════════════════════════════════════════════════════

    # Root
    o.append('[node name="Main" type="Node2D"]')
    o.append('y_sort_enabled = true')
    o.append('script = ExtResource("main_script")')
    o.append('')

    # ── Ground ──
    o.append('[node name="Ground" type="Sprite2D" parent="."]')
    o.append('texture_repeat = 2')
    o.append('z_index = -10')
    o.append('position = Vector2(-1500, -1500)')
    o.append('texture = ExtResource("ground_tex")')
    o.append('centered = false')
    o.append('region_enabled = true')
    o.append('region_rect = Rect2(0, 0, 3000, 3000)')
    o.append('')

    # ── Grid Overlay ──
    o.append('[node name="GridOverlay" type="Node2D" parent="."]')
    o.append('z_index = -9')
    o.append('script = ExtResource("grid_script")')
    o.append('')

    # ── Buildings ──
    for i, b in enumerate(buildings):
        name = b['name']
        px, py = b['pos']
        vw = b['tw'] * SCALE
        vh = b['th'] * SCALE
        t = b['tint']

        o.append(f'[node name="{name}" type="StaticBody2D" parent="."]')
        o.append(f'position = Vector2({px}, {py})')
        o.append('')

        o.append(f'[node name="Sprite2D" type="Sprite2D" parent="{name}"]')
        o.append(f'texture = ExtResource("{b["tex"]}")')
        o.append(f'scale = Vector2({SCALE}, {SCALE})')
        o.append(f'modulate = Color({t[0]}, {t[1]}, {t[2]}, 1)')
        o.append('z_index = -2')
        o.append('')

        o.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="{name}"]')
        o.append(f'position = Vector2(0, {vh * 0.2})')
        o.append(f'shape = SubResource("BldShape_{i+1}")')
        o.append('')

        # Window lights
        nl = b['lights']
        for w in range(nl):
            x_off = (w - (nl - 1) / 2.0) * 50.0
            ln = f"WindowLight{'_' + str(w+1) if nl > 1 else ''}"
            o.append(f'[node name="{ln}" type="PointLight2D" parent="{name}"]')
            o.append(f'position = Vector2({x_off}, {vh * 0.1})')
            o.append('color = Color(1, 0.69, 0.38, 1)')
            o.append('energy = 0.5')
            o.append('texture = SubResource("LightTex_1")')
            o.append('texture_scale = 2.5')
            o.append('')

        # Ground shadow
        sw = vw + 16
        sx = -vw / 2.0 - 8
        sy = vh / 2.0 - 4
        o.append(f'[node name="Shadow" type="ColorRect" parent="{name}"]')
        o.append(f'offset_left = {sx}')
        o.append(f'offset_top = {sy}')
        o.append(f'offset_right = {sx + sw}')
        o.append(f'offset_bottom = {sy + 12}')
        o.append('z_index = -3')
        o.append('color = Color(0, 0, 0, 0.25)')
        o.append('')

    # ── Cover Objects ──
    for i, c in enumerate(covers):
        name = c['name']
        px, py = c['pos']
        cs = c['col']

        o.append(f'[node name="{name}" type="StaticBody2D" parent="."]')
        o.append(f'position = Vector2({px}, {py})')
        o.append('')

        o.append(f'[node name="Sprite2D" type="Sprite2D" parent="{name}"]')
        o.append(f'texture = SubResource("CoverAtlas_{i+1}")')
        o.append(f'scale = Vector2({c["scale"][0]}, {c["scale"][1]})')
        o.append('')

        o.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="{name}"]')
        o.append(f'shape = SubResource("CoverShape_{i+1}")')
        o.append('')

        sx = -cs[0] / 2.0 - 5
        sy = cs[1] / 2.0 - 2
        o.append(f'[node name="Shadow" type="ColorRect" parent="{name}"]')
        o.append(f'offset_left = {sx}')
        o.append(f'offset_top = {sy}')
        o.append(f'offset_right = {sx + cs[0] + 10}')
        o.append(f'offset_bottom = {sy + 8}')
        o.append('z_index = -1')
        o.append('color = Color(0, 0, 0, 0.3)')
        o.append('')

    # ── Fountain ──
    tcx, tcy = town

    o.append('[node name="FountainShadow" type="Sprite2D" parent="."]')
    o.append(f'position = Vector2({tcx + 4}, {tcy + 6})')
    o.append(f'scale = Vector2({PROP_SCALE}, {PROP_SCALE})')
    o.append('z_index = -2')
    o.append('texture = ExtResource("fountain_sh_tex")')
    o.append('')

    o.append('[node name="Fountain" type="Sprite2D" parent="."]')
    o.append(f'position = Vector2({tcx}, {tcy})')
    o.append(f'scale = Vector2({PROP_SCALE}, {PROP_SCALE})')
    o.append('texture = ExtResource("fountain_tex")')
    o.append('')

    o.append('[node name="FountainLight" type="PointLight2D" parent="."]')
    o.append(f'position = Vector2({tcx}, {tcy})')
    o.append('color = Color(0.5, 0.7, 1, 1)')
    o.append('energy = 0.3')
    o.append('texture = SubResource("LightTex_1")')
    o.append('texture_scale = 3.0')
    o.append('')

    # ── Foodog Guardians ──
    for side, label in [(-1, 'L'), (1, 'R')]:
        dx = tcx + side * 160
        dy = tcy + 10

        o.append(f'[node name="FoodogShadow_{label}" type="Sprite2D" parent="."]')
        o.append(f'position = Vector2({dx + 3}, {dy + 4})')
        o.append(f'scale = Vector2({PROP_SCALE}, {PROP_SCALE})')
        o.append('z_index = -2')
        o.append('texture = ExtResource("foodog_sh_tex")')
        o.append('')

        o.append(f'[node name="Foodog_{label}" type="Sprite2D" parent="."]')
        o.append(f'position = Vector2({dx}, {dy})')
        o.append(f'scale = Vector2({PROP_SCALE}, {PROP_SCALE})')
        o.append('texture = ExtResource("foodog_tex")')
        if side == 1:
            o.append('flip_h = true')
        o.append('')

    # ── Trees ──
    for i, t in enumerate(trees):
        px, py = t['pos']
        o.append(f'[node name="Tree_{i}" type="Sprite2D" parent="."]')
        o.append(f'position = Vector2({px}, {py})')
        o.append(f'scale = Vector2({PROP_SCALE}, {PROP_SCALE})')
        o.append('modulate = Color(0.7, 0.8, 0.7, 1)')
        o.append('z_index = 1')
        o.append(f'texture = SubResource("TreeAtlas_{i+1}")')
        o.append('')

    # ── Parked Car ──
    o.append('[node name="ParkedCar" type="Sprite2D" parent="."]')
    o.append('position = Vector2(70, 420)')
    o.append('modulate = Color(0.5, 0.55, 0.65, 0.7)')
    o.append('z_index = -3')
    o.append('texture = ExtResource("car_tex")')
    o.append('')

    # ── Navigation ──
    o.append('[node name="NavigationRegion2D" type="NavigationRegion2D" parent="."]')
    o.append('script = ExtResource("nav_script")')
    o.append('')

    # ── Atmosphere ──
    o.append('[node name="VeilModulate" type="CanvasModulate" parent="."]')
    o.append('color = Color(0.55, 0.6, 0.75, 1)')
    o.append('')

    o.append('[node name="VeilParticles" type="CPUParticles2D" parent="."]')
    o.append('position = Vector2(600, 350)')
    o.append('z_index = 10')
    o.append('amount = 40')
    o.append('lifetime = 6.0')
    o.append('emission_shape = 2')
    o.append('emission_rect_extents = Vector2(600, 400)')
    o.append('direction = Vector2(0.3, -1)')
    o.append('spread = 30.0')
    o.append('gravity = Vector2(0, 5)')
    o.append('initial_velocity_min = 8.0')
    o.append('initial_velocity_max = 20.0')
    o.append('scale_amount_min = 1.0')
    o.append('scale_amount_max = 3.0')
    o.append('color = Color(0.8, 0.6, 0.4, 0.3)')
    o.append('')

    # ── Managers ──
    o.append('[node name="TurnManager" type="Node" parent="."]')
    o.append('script = ExtResource("tm_script")')
    o.append('')

    o.append('[node name="EngagementManager" type="Node" parent="."]')
    o.append('script = ExtResource("em_script")')
    o.append('')

    o.append('[node name="TacticalCursor" type="Node2D" parent="."]')
    o.append('position = Vector2(550, 580)')
    o.append('script = ExtResource("tc_script")')
    o.append('')

    # ── Party (instanced sub-scenes) ──
    o.append('[node name="Kage" parent="." instance=ExtResource("kage_scene")]')
    o.append('position = Vector2(550, 580)')
    o.append('')

    o.append('[node name="Akari" parent="." instance=ExtResource("akari_scene")]')
    o.append('position = Vector2(650, 620)')
    o.append('')

    # ── Enemies (instanced sub-scenes) ──
    for i, (dx, dy) in enumerate(demons):
        o.append(f'[node name="SmallDemon_{i}" parent="." instance=ExtResource("demon_scene")]')
        o.append(f'position = Vector2({dx}, {dy})')
        o.append('')

    o.append('[node name="BigDemon" parent="." instance=ExtResource("boss_scene")]')
    o.append('position = Vector2(600, -80)')
    o.append('')

    # ── Camera ──
    o.append('[node name="Camera2D" type="Camera2D" parent="."]')
    o.append('position = Vector2(550, 550)')
    o.append('script = ExtResource("cam_script")')
    o.append('')

    # ── Party Manager ──
    o.append('[node name="PartyManager" type="Node" parent="."]')
    o.append('script = ExtResource("pm_script")')
    o.append('')

    # ── UI ──
    o.append('[node name="UI" type="CanvasLayer" parent="."]')
    o.append('script = ExtResource("ui_script")')
    o.append('')

    help_text = ("2D PROTOTYPE \\u2014 Tactical: WASD cursor, Space move, "
                 "Tab switch, Q aim, E end turn\\n"
                 "ARPG: WASD move, J attack (3-hit combo), K dodge (i-frames), L parry")

    o.append('[node name="HelpLabel" type="Label" parent="UI"]')
    o.append('offset_left = 10.0')
    o.append('offset_top = 10.0')
    o.append('offset_right = 800.0')
    o.append('offset_bottom = 50.0')
    o.append(f'text = "{help_text}"')
    o.append('theme_override_colors/font_color = Color(1, 1, 1, 0.7)')
    o.append('theme_override_font_sizes/font_size = 14')
    o.append('')

    o.append('[node name="PhaseLabel" type="Label" parent="UI"]')
    o.append('offset_left = 10.0')
    o.append('offset_top = 55.0')
    o.append('offset_right = 300.0')
    o.append('offset_bottom = 80.0')
    o.append('theme_override_colors/font_color = Color(1, 0.9, 0.3, 1)')
    o.append('theme_override_font_sizes/font_size = 18')
    o.append('')

    o.append('[node name="HPLabel" type="Label" parent="UI"]')
    o.append('offset_left = 10.0')
    o.append('offset_top = 80.0')
    o.append('offset_right = 400.0')
    o.append('offset_bottom = 100.0')
    o.append('theme_override_colors/font_color = Color(0.3, 1, 0.3, 1)')
    o.append('theme_override_font_sizes/font_size = 16')
    o.append('')

    o.append('[node name="EngLabel" type="Label" parent="UI"]')
    o.append('offset_left = 10.0')
    o.append('offset_top = 105.0')
    o.append('offset_right = 500.0')
    o.append('offset_bottom = 125.0')
    o.append('theme_override_colors/font_color = Color(0.5, 0.8, 1, 1)')
    o.append('theme_override_font_sizes/font_size = 14')
    o.append('')

    return '\n'.join(o)


# ════════════════════════════════════════════════════════════
# Main
# ════════════════════════════════════════════════════════════

if __name__ == '__main__':
    print("Generating Godot 4 scene/resource files for Shadow Leap 2D...")
    print()

    print("SpriteFrames resources:")
    write_file('resources/kage_frames.tres', gen_kage_tres())
    write_file('resources/akari_frames.tres', gen_akari_tres())
    write_file('resources/skeleton_frames.tres', gen_skeleton_tres())
    write_file('resources/big_demon_frames.tres', gen_big_demon_tres())
    print()

    print("Entity scenes:")
    write_file('scenes/entities/kage.tscn', gen_kage_tscn())
    write_file('scenes/entities/akari.tscn', gen_akari_tscn())
    write_file('scenes/entities/small_demon.tscn', gen_small_demon_tscn())
    write_file('scenes/entities/big_demon.tscn', gen_big_demon_tscn())
    print()

    print("Main scene:")
    write_file('scenes/main.tscn', gen_main_tscn())
    print()

    print("✅ Done! Generated 9 files.")
    print()
    print("Next: write the 4 new GDScript files, then open in Godot.")
    print("Scene tree will show individual nodes you can select and move.")
