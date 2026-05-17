# New Scene Quick Start — LimeZu / Premium Tilesets

## Step 1: Drop PNGs into folders

Unzip your purchased packs and drag the PNG files into:
```
sprites/tilesets/limezu/     ← LimeZu Modern Exteriors + Interiors
sprites/tilesets/sakura/     ← Sakura pack
```
Just the PNGs — ignore any Tiled/JSON files that come with them.

> **Subfolders are fine!** The creator scans recursively.
> It auto-skips its own upscaled output so you can re-run safely.

## Step 2: Create a new scene

1. **Scene → New Scene → Node2D** → rename root to your location name (e.g., `HubCity`)
2. **Save** as `res://scenes/hub_city.tscn` (or whatever)

## Step 3: Create the TileSet

1. Right-click root → **Add Child Node → Node2D** → rename to `Creator`
2. In the Inspector, attach script: `res://tools/tileset_creator_v2.gd`
3. Click **"Dry Run (scan only)"** first — check the Output panel to see what it found
4. Click **"Create TileSet"** — it will:
   - Auto-detect 16px sheets (LimeZu)
   - Upscale them to 32px with nearest-neighbor
   - Save everything to `res://resources/city_tileset.tres`
5. **Delete the Creator node** (it's done its job)

> ⚠️ **First-run note:** If upscaled files show "needs reimport," just close and
> reopen Godot, then re-run. Godot needs to import the new PNGs it hasn't seen before.

## Step 4: Add TileMapLayers

Right-click root → Add Child → **TileMapLayer**. Create these:

| Layer Name     | Z-Index | Collision | Purpose                          |
|----------------|---------|-----------|----------------------------------|
| `GroundLayer`  | -10     | OFF       | Grass, dirt, pavement, roads     |
| `WallLayer`    | -3      | ON        | Building walls (solid)           |
| `WallOverlay`  | -2      | OFF       | Windows, doors, trim (alpha)     |
| `RoofLayer`    | -1      | OFF       | Rooftops                         |
| `DetailLayer`  | 0       | OFF       | Signs, awnings, AC units         |
| `PropLayer`    | 1       | OFF/ON    | Fences, dumpsters, vending machines |

For **each** layer:
- Inspector → **Tile Set** → Load → `res://resources/city_tileset.tres`
- Set **Z Index** as shown
- WallLayer: `Use Collision = true` (default)

## Step 5: Paint!

1. Select a TileMapLayer in the scene tree
2. TileMap panel opens at the bottom
3. Pick a **Source** from the dropdown (each PNG = one source)
4. Click tiles → click viewport to paint

### Keyboard Shortcuts
| Key | Action |
|-----|--------|
| Left click | Paint |
| Right click / Ctrl+click | Erase |
| Shift+click | Line tool |
| Ctrl+Shift+click | Rectangle fill |
| B | Bucket fill |

## Adding More Packs Later

1. Drop new PNGs into a folder under `sprites/tilesets/`
2. Edit `tileset_creator_v2.gd` → add the folder to `SCAN_DIRS`
3. If the new pack is 16px, also add it to `FORCE_16PX_DIRS`
4. Re-run the Creator (add node, click button, delete node)
5. The `.tres` will be updated with the new sources

## Folder Layout
```
sprites/tilesets/
├── limezu/                    ← LimeZu packs (16px, auto-upscaled)
│   ├── modern_exteriors.png
│   ├── modern_interiors.png
│   └── upscaled_32px/         ← auto-generated 32px versions
├── sakura/                    ← Sakura pack
├── (existing free tilesets)   ← walls.png, victorian-*, etc.
└── (future packs)/
```
