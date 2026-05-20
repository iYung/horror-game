## Wall Torches Checklist

Tasks are grouped by dependency. Run Group 1 in parallel, then Group 2 in parallel, then Group 3.

---

### Group 1 — no dependencies (run in parallel)

- [x] Task A — `game/world/map.lua` — Add optional `torches` parameter to `Map.new(grid, spawn, extraction, torches)`. Store it as `self.torches = torches or {}`. No other changes to the file.

- [x] Task D — `core/lua/raycaster.lua` — Replace the fog_range lighting system with a point-light model.
  - Change `opts.fog_range` → `opts.lights` (list of `{x, y, radius, intensity}` in 1-indexed grid units).
  - **Per-column wall brightness**: after computing the wall hit cell `(mx, my)`, compute `hit_gx = mx + 0.5`, `hit_gy = my + 0.5`, then accumulate `brightness = sum of max(0, 1 - dist/light.radius) * light.intensity` over all lights where `dist = sqrt((hit_gx - light.x)^2 + (hit_gy - light.y)^2)`. Clamp to `[0, 1]`. Replace the old `fog` variable with this `brightness`. Keep the existing N/S vs E/W face shade multipliers (`0.7` / `0.45`) — multiply them by `brightness` exactly as `fog` was used before.
  - **Ceiling/floor brightness**: before the wall loop, compute `player_brightness` by sampling each light at player position `(px, py)` using the same formula. Clamp to `[0, 1]`.
  - **Ceiling color**: replace the fixed `(0.06, 0.04, 0.06)` rectangle with `(0.55 * s, 0.50 * s, 0.45 * s)` where `s = player_brightness * 0.45`.
  - **Floor color**: replace the fixed `(0.10, 0.08, 0.08)` rectangle with `(0.35 * s, 0.28 * s, 0.22 * s)` where `s = player_brightness * 0.55`.
  - **Sprite fog**: the sprite loop still uses a `fog` factor for billboard fade. Replace `1.0 - tz / fog_range` with the same point-light accumulation sampled at the sprite's grid position `(sp.x, sp.y)`.
  - Remove the `fog_range` local entirely. If `opts.lights` is nil or empty, brightness is 0 everywhere (pitch black).

---

### Group 2 — depends on Task A (run in parallel after A completes)

- [x] Task B — `game/world/map_forest.lua` — Add a `torches` table of 12 entries (one per room, on a wall cell of that room's north wall — row index = room's top row, col index = room's horizontal centre). Pass it as the 4th argument to `Map.new()`.

  Exact positions (1-indexed col, row of the wall cell):
  ```
  -- Row 1 rooms (top row = row 2)
  {col=5,  row=2},   -- A1 north wall (col centre of A: cols 2–9 → col 5)
  {col=13, row=2},   -- B1 north wall (col centre of B: cols 12–15 → col 13)
  {col=24, row=2},   -- C1 north wall (col centre of C: cols 22–27 → col 24)
  {col=35, row=2},   -- D1 north wall (col centre of D: cols 32–39 → col 35)
  -- Row 2 rooms (top row = row 12)
  {col=5,  row=12},  -- A2
  {col=13, row=12},  -- B2
  {col=24, row=12},  -- C2
  {col=35, row=12},  -- D2
  -- Row 3 rooms (top row = row 22)
  {col=5,  row=22},  -- A3
  {col=13, row=22},  -- B3
  {col=24, row=22},  -- C3
  {col=35, row=22},  -- D3
  ```

- [x] Task C — `game/world/map_hospital.lua` — Add a `torches` table of 20 entries (one per room on the room's north wall), pass as 4th arg to `Map.new()`.

  Exact positions (1-indexed col, row):
  ```
  -- Row 1 rooms (top row = row 2)
  {col=3,  row=2},   -- A1 (cols 2–5 → col 3)
  {col=10, row=2},   -- B1 (cols 8–13 → col 10)
  {col=20, row=2},   -- C1 (cols 19–22 → col 20)
  {col=29, row=2},   -- D1 (cols 26–32 → col 29)
  {col=37, row=2},   -- E1 (cols 35–39 → col 37)
  -- Row 2 rooms (top row = row 8)
  {col=3,  row=8},   -- A2
  {col=10, row=8},   -- B2
  {col=20, row=8},   -- C2
  {col=29, row=8},   -- D2
  {col=37, row=8},   -- E2
  -- Row 3 rooms (top row = row 16)
  {col=3,  row=16},  -- A3
  {col=10, row=16},  -- B3
  {col=20, row=16},  -- C3
  {col=29, row=16},  -- D3
  {col=37, row=16},  -- E3
  -- Row 4 rooms (top row = row 24)
  {col=3,  row=24},  -- A4
  {col=10, row=24},  -- B4
  {col=20, row=24},  -- C4
  {col=29, row=24},  -- D4
  {col=37, row=24},  -- E4
  ```

---

### Group 3 — depends on Tasks A, B, C, D

- [x] Task E — `game/scenes/run_scene.lua` — Wire the point-light system and wall torch billboards.
  1. **Remove** `current_fog_range(player)` entirely.
  2. **Add** `build_lights(self)` that returns a flat list for `opts.lights`:
     - For each entry in `self.map.torches`: `{x = t.col + 0.5, y = t.row + 0.5, radius = 6, intensity = 1.0}`.
     - If player's active item is a torch and `item.active == true`: append `{x = self.player.x, y = self.player.y, radius = 4, intensity = 0.9}`.
     - If player's active item is a flashlight and `item.active == true` and `item.on == true`: append `{x = self.player.x, y = self.player.y, radius = 6, intensity = 1.0}`.
  3. **Update `build_sprites(self)`** — at the end, before `return sprites`, iterate `self.map.torches` and insert each as a billboard: `{x = t.col + 0.5, y = t.row + 0.5, size = 0.25, color = {1.0, 0.65, 0.15, 1}}`.
  4. **Update `RunScene:draw()`** — replace `fog_range = current_fog_range(self.player)` with `lights = build_lights(self)` in the opts table passed to `self.raycaster:draw`.
