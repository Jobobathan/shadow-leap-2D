# Shadow Leap 2D — Session Handoff: Tileset Shopping List

**Date:** 2026-05-17  
**Previous Handoff:** `SESSION_HANDOFF_TILEMAP_BUILD.md`  
**Status:** TileMap workflow established, David painting town — need premium tilesets  
**Commit:** `63b482d`

---

## What Happened This Session

### 1. TileMap Workflow Established
- Scrapped the programmatic building painter (metronome on a live recording)
- Created `tools/tileset_creator.gd` — one-button TileSet creation (16 atlas sources)
- Created `PAINTING_GUIDE.md` — layer setup, atlas reference, painting tips
- David is painting his first town in the Godot TileMap editor and loving it

### 2. Massive Free Tileset Library Built (70+ files)
Downloaded from OpenGameArt and organized in `sprites/tilesets/`:
- **Medieval/Victorian:** walls, bricks, colonial, roofs, victorian mansion/tenement/accessories/decorations
- **Modern/Urban:** LPC Modern Streets (sidewalks, curbs, road markings, traffic lights, signs, chain link fences, manholes, trash bins), city_mega_32px (upscaled 16→32px)
- **Classical:** Roman architecture (columns, arches, marble), Greek architecture (temples, pediments), aqueducts
- **Props:** flowers, planters, barrels, chests, dumpster, hanging signs, decorations-medieval, fences
- **Cars:** 4-car set (Firetruck, Luxury, Racing, Regular) + modern_cars_sheet
- **Office/Interior:** LPC Office furniture (desks, laptops, copy machines, TVs, water coolers)
- **Ground/Terrain:** terrain_v7, terrain_atlas, base_out_atlas

### 3. What's Missing (Why We Need Premium Tilesets)
Free tileset world is heavily medieval fantasy. Shadow Leap is **modern-day Tokyo-NYC with ancient elements**. Gaps:
- **Japanese architecture** — temples, shrines, torii gates, pagodas, shoji screens, tatami
- **Modern skyscrapers/high-rises** — glass towers, office buildings, downtown skyline
- **Modern government buildings** — city hall, police stations, hospitals
- **Middle Eastern architecture** — for Act 1 mission setting
- **Veil/dark versions** — corrupted/nightmare overlays of all the above
- **Wilderness/nature** — forests, mountains, camping, road trip environments

---

## The Game — What the Next Agent Needs to Know

### Genre & Aesthetic
- **SNES-style Action RPG** — Chrono Trigger / FF6 / A Link to the Past
- **¾-view 2D** (Chrono Trigger perspective), sprite-based
- **Modern-day setting** with smartphones, skyscrapers, ancient shrines crammed between them
- **Engine:** Godot 4.6, 32×32 tile grid, 1280×720 viewport
- **Tone:** Dark but not edgy. Real-world parallels. The thesis is "darkness ≠ evil"

### The World
- **The Veil:** Same world, different frequency. Emotional truth becomes visible. Happy places glow. Traumatic places look like hell. Not a spirit realm — it's always been here.
- **Demons:** Born from collective suffering of extinct species. Lower-tier = monsters. Upper-tier = trained corporate executives (70 years of Demon Zero's development program). They influence through dreams/whispers, NOT possession.
- **Tengu:** Evolutionary human response to demons. Can perceive the Veil. Nearly extinct — hunted by Demon Zero for decades. The protagonist is the last activated Tengu.
- **Ninjas:** Visible, despised social caste. Blue-collar mercenaries. Used by Samurai establishment for dirty work, then scapegoated.
- **Setting:** Tokyo-NYC hybrid. Modern city with ancient shrines. Smartphones and skyscrapers alongside Tengu sites and demon-haunted ruins.

### The Story (5 Acts)
1. **Act 1 — The Mission (10-15hrs):** Middle East military mission. Kage (ninja protagonist), Wedge (partner), and a nationalist friend. Mission reveals systemic corruption. Kage kills friend who won't stand down. System scapegoats the dead. Kage is done with the establishment.
2. **Act 2 — The Road Trip (8-12hrs):** Kage and Wedge take time off. Find old Tengu site. A middle-manager demon starts tailing/influencing Kage. Kage's latent powers awaken to save Wedge. First demon kill.
3. **Act 3 — The Ascension:** Wedge undergoes the Ascension Ritual, becomes Tengu. Atria (samurai woman) joins. The Veil thins.
4. **Acts 4-5:** Not fully designed yet. Confrontation with Demon Zero's hierarchy. Final battle.

### Key Locations Needed (Tileset Requirements)

| Location | Acts | Aesthetic | What We Need |
|----------|------|-----------|-------------|
| **Hub City** | All | Tokyo-NYC hybrid — dense, vertical, neon + shrines | Skyscrapers, glass towers, neon signs, subway, convenience stores, shrine tucked between buildings |
| **Small Town** | 2 | American/Japanese small town (currently being built) | ✅ HAVE — colonial, victorian, streets, props |
| **Middle East** | 1 | Desert urban, military compound, market streets | Sandstone buildings, bazaar stalls, desert terrain, military structures, palm trees |
| **Tengu Mountain Site** | 2-3 | Ancient Japanese mountain shrine, weathered, sacred | Torii gates, stone lanterns, moss-covered steps, mountain paths, shrine buildings |
| **The Veil (overlay)** | All | Dark, emotional distortion of normal locations | Corrupted/nightmare versions of tiles, shadow effects, organic horror growth, cracked/bleeding textures |
| **Wilderness/Road** | 2 | Japanese countryside, forests, camping | Dense forests, mountain trails, rivers, campfire, rural roads |
| **Demon Lairs** | 2-5 | Corporate hell — clean suits in nightmare spaces | Dark office + organic horror hybrid. Boardrooms that bleed. |
| **Government/Samurai HQ** | 1,3 | Grand institutional — marble, columns, imposing | ✅ PARTIAL — have Roman/Greek columns, Victorian mansion |
| **Ninja Quarter** | 1 | Blue-collar, cramped, working-class neighborhood | Dense housing, narrow streets, laundry lines, small shops |
| **Interiors** | All | Homes, offices, shops, shrines, military | ✅ PARTIAL — have office furniture, need more |

---

## Task for Next Session: Find the Best Tilesets

### Search Strategy
David is willing to invest money in quality tilesets. Search these sources:
1. **itch.io** — largest paid pixel art marketplace
2. **OpenGameArt** — free (already mined heavily)
3. **GameDevMarket** — paid asset marketplace
4. **humble bundle** — occasionally has pixel art bundles
5. **PixelJoint / DeviantArt** — individual artists with packs

### Priority Search Terms (by urgency)

**HIGH PRIORITY:**
1. "japanese tileset pixel art top down 32x32" — temples, shrines, torii, pagodas
2. "modern city tileset pixel art top down" — skyscrapers, downtown, neon
3. "middle east tileset pixel art top down" — desert, bazaar, sandstone
4. "dark/horror tileset pixel art top down" — Veil overlay, corruption, nightmare

**MEDIUM PRIORITY:**
5. "japanese interior tileset" — tatami, shoji, traditional rooms
6. "forest/nature tileset pixel art top down 32x32" — wilderness, mountains
7. "cyberpunk/neon city tileset" — for hub city nightlife district
8. "military base tileset pixel art" — Act 1 compound

**NICE TO HAVE:**
9. "subway/train station tileset pixel art" — hub city transit
10. "office interior tileset modern" — government/corporate buildings
11. "marketplace/bazaar tileset" — Middle East and hub city markets

### Requirements for Any Tileset
- **32×32 grid** (or 16×16 that can be upscaled 2×)
- **Top-down ¾-view** (Chrono Trigger perspective) — NOT side-scroll, NOT isometric
- **PNG format** with transparency
- **LPC-compatible style preferred** but not required if quality is high
- Present options to David with: price, preview link, what it contains, grid size

### What David Already Bought
David mentioned buying "the two you mentioned" — likely:
- A Japanese pixel tileset from itch.io
- A modern city tileset from itch.io
Check what he has and integrate those first.

---

## Technical State

### Files Structure
```
sprites/
├── colonial.png, roofs.png, terrain_v7.png    ← core tilesets (in use)
└── tilesets/                                   ← tileset library
    ├── walls.png, bricks.png, victorian-*.png  ← medieval/victorian
    ├── modern_*.png, street_*.png              ← modern/urban
    ├── roman_*.png, greek_*.png                ← classical
    ├── city_mega_32px.png                      ← biggest city tileset
    ├── streets/                                ← LPC Modern Streets pack
    ├── cars/                                   ← vehicle sprites
    └── office/                                 ← office furniture sprites
```

### Key Scripts
- `tools/tileset_creator.gd` — @tool script, one button creates TileSet from all atlases
- `tools/tilemap_builder.gd` — OLD, superseded, kept for reference only

### Scene State
- `scenes/main.tscn` — untouched on disk, David painting in editor on gaming PC
- Old House1-4 nodes still present (reference while painting)
- TileMapLayers added by David in editor (GroundLayer, WallLayer, etc.)

### Git
- Repo: `Jobobathan/shadow-leap-2D` (GitHub)
- **Push requires:** `gh auth switch --user Jobobathan` → push → `gh auth switch --user DBarberTKE`
- Gaming PC pulls via GitHub Desktop or browser download

---

## Commit History (This Session)
```
63b482d  Add LPC Office furniture + Adobe buildings
23a0a66  Add Roman & Greek architecture — columns, grand halls for capital buildings
e746363  Add city mega pack, Victorian decorations, LPC windows/doors, shipping docks
f1d9e24  Add LPC Modern Streets pack + urban props + more cars
bba2162  Add modern tilesets: streets, roads, cars, ruins, city buildings
8279036  New approach: you paint, I wire — 17 tilesets + lean creator + painting guide
5dec3c8  Fix tilemap_builder: decompress textures for pixel scan, rescue lights/shadows in cleanup
```
