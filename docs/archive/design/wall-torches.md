# Wall Torches & Roof Lighting

## Goal

Replace the current global distance-fog lighting model with a point-light system driven by
wall-mounted torches defined per map. The environment should feel genuinely enclosed (a roof
overhead) and genuinely dark: pitch black between torches, with small islands of amber light
wherever a wall torch is mounted. Carried items (hand torch, flashlight) remain useful as
moveable point lights on top of the fixed wall torches.

---

## Affected files

| File | Role |
|------|------|
| `core/lua/raycaster.lua` | Rendering — replace fog_range with per-column point-light accumulation |
| `game/world/map.lua` | Data — add `torches` field to `Map.new()` |
| `game/world/map_forest.lua` | Data — define wall torch positions |
| `game/world/map_hospital.lua` | Data — define wall torch positions |
| `game/scenes/run_scene.lua` | Orchestration — build per-frame `lights` list, add torch billboards |

---

## What changes

### 1. Raycaster — point-light model

`opts.fog_range` is replaced by `opts.lights`, a flat list of point lights:

```lua
opts.lights = {
    { x, y, radius, intensity },  -- x/y in 1-indexed grid units (float)
    ...
}
```

**Wall column brightness** (per column, computed at the wall hit cell center):

```lua
hit_gx = mx + 0.5   -- mx is math.floor(px), so 1-indexed integer → float centre
hit_gy = my + 0.5
brightness = 0
for each light:
    dist = sqrt((hit_gx - light.x)^2 + (hit_gy - light.y)^2)
    brightness = brightness + max(0, 1 - dist / light.radius) * light.intensity
brightness = min(brightness, 1)
```

The existing wall shade multiplier (`0.7` or `0.45` for N/S vs E/W faces) is kept and
multiplied by `brightness` instead of the old `fog` value.

No ambient baseline — `brightness` starts at `0` so areas with no nearby light are
pitch black.

**Ceiling and floor brightness** (uniform per frame, sampled at player position):

```lua
player_brightness = 0
for each light:
    dist = sqrt((px - light.x)^2 + (py - light.y)^2)
    player_brightness = player_brightness + max(0, 1 - dist / light.radius) * light.intensity
player_brightness = min(player_brightness, 1)
```

Ceiling color: base `{0.55, 0.50, 0.45}` × `player_brightness × 0.45` — dark stone
revealed by nearby torches, pitch black when no torch is close.

Floor color: base `{0.35, 0.28, 0.22}` × `player_brightness × 0.55` — dark stone floor,
slightly warmer and brighter than ceiling.

These base colors replace the current fixed `(0.06, 0.04, 0.06)` ceiling and `(0.10, 0.08,
0.08)` floor, giving the enclosed, roofed feeling: in a lit room you can see grey stone
above and below; between torches everything collapses to black.

### 2. Map data — torch positions

`Map.new(grid, spawn, extraction, torches)` gains an optional `torches` parameter (defaults
to `{}`). Each entry is:

```lua
{ col = number, row = number }   -- 1-indexed cell coords of the wall cell the torch is on
```

The map stores `self.torches = torches or {}`.

`map_forest.lua` and `map_hospital.lua` each add a `torches` table before `Map.new()`.

**Placement strategy** — one torch per room (mounted on a wall cell of that room), zero
torches in hallways. Hallways are the dark, tense stretches the player must navigate between
lit rooms.

Forest Facility (12 rooms → 12 torches). Example placements (north wall of each room):

```
A1: {col=5, row=2}    B1: {col=13,row=2}   C1: {col=24,row=2}   D1: {col=35,row=2}
A2: {col=5, row=12}   B2: {col=13,row=12}  C2: {col=24,row=12}  D2: {col=35,row=12}
A3: {col=5, row=22}   B3: {col=13,row=22}  C3: {col=24,row=22}  D3: {col=35,row=22}
```

Hospital (20 rooms → 20 torches). Same principle — one per room on a wall cell interior to
that room. Exact coordinates TBD by the task agent reading the map layout.

**Light parameters for wall torches**: radius = 6 grid cells, intensity = 1.0. This fills a
medium room (4–6 cells wide) and bleeds slightly into adjacent hallway entrances.

### 3. Run scene — per-frame lights list

`current_fog_range()` is removed. A new helper `build_lights(self)` builds the list each
frame:

```lua
-- Fixed wall torches
for each map.torches entry:
    table.insert(lights, {
        x         = torch.col + 0.5,
        y         = torch.row + 0.5,
        radius    = 6,
        intensity = 1.0,
    })

-- Player's carried torch (hand torch, active)
local item = player:active_item()
if item and item.id == "torch" and item.active then
    table.insert(lights, { x=player.x, y=player.y, radius=4, intensity=0.9 })
end

-- Player's flashlight (on)
if item and item.id == "flashlight" and item.active and item.on then
    table.insert(lights, { x=player.x, y=player.y, radius=6, intensity=1.0 })
end
```

`raycaster:draw` is called with `opts.lights = lights` instead of `opts.fog_range`.

### 4. Wall torch billboards

Wall torches appear as small orange sprites in the world. They render as billboards at the
wall cell's grid position; the raycaster z-buffer naturally occludes them when another wall
is in front.

```lua
for each map.torches entry:
    table.insert(sprites, {
        x     = torch.col + 0.5,
        y     = torch.row + 0.5,
        size  = 0.25,
        color = {1.0, 0.65, 0.15, 1},
    })
```

These are added in `build_sprites()` in `run_scene.lua`.

### 5. Monster sight trait — no change needed

The trait already reads `player:active_item().active == true` to detect a carried torch glow.
The player torch still sets `.active = true` on use, so this continues to work. The only
conceptual difference is that wall torches also light the scene, but they don't affect monster
sight (the monster reacts to the player carrying a light, not to ambient room light).

---

## What stays the same

- Sprite billboard system (monsters, ground items, extraction pillar)
- Inventory, item timers, flashlight toggle logic
- All monster traits
- Extraction system
- `fog_range` in `opts` still accepted by raycaster for backward compat if needed (but
  `run_scene` will stop sending it)
- Map grid structure — only the `torches` list is added

---

## Open questions

None — all design decisions confirmed before writing this doc:

| Decision | Answer |
|----------|--------|
| Carried items still useful? | Yes — player torch/flashlight contribute as point lights |
| Default darkness | Pitch black (no ambient floor) |
| Torch flicker | No — steady brightness |
