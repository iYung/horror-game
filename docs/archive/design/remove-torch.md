## Goal

Remove the torch item entirely. The flashlight becomes the only light source the player can find on the ground. The flashlight's active-on state inherits the one mechanic the torch uniquely owned: alerting the monster's Sight trait without LOS.

## Affected files

- `game/data/items.lua` — delete torch definition and `make_torch` factory
- `game/world/item_spawner.lua` — remove 3–5 torch spawn block
- `game/scenes/run_scene.lua` — remove torch branch from fog-range picker
- `game/entities/monster.lua` — retarget `torch_glow` check to flashlight-on
- `test/watch_scene.lua` — remove torch fog-range branch
- `game/systems/fov.lua` — remove dead torch-omni pass (file is already unused in 3D but tidy while here)

## What changes

### items.lua
Delete the `torch` entry from `definitions` and the `make_torch` function. Remove `torch` from `factories`.

### item_spawner.lua
Remove the `if budget >= 1` torch block (lines that spawn 3–5 torches). The flashlight block that follows it stays; it already uses the same `budget >= 1` guard and spawns 3–5 flashlights.

### run_scene.lua — fog range
Current logic:
```
torch active  → fog_range = 11
flashlight on → fog_range = 14
default       → fog_range = 8
```
New logic (two tiers):
```
flashlight on → fog_range = 14
default       → fog_range = 8
```
Delete the `item.id == "torch"` branch.

### monster.lua — Sight glow trigger
Current: `torch_glow = active_item.id == "torch" and active_item.active`
New: `flashlight_glow = active_item.id == "flashlight" and active_item.active and active_item.on`

Rename the local and update the condition in the Sight check so a player running with the flashlight on is spotted without LOS, exactly as the torch was.

### watch_scene.lua
Remove the `item.id == "torch"` fog-range branch so the helper only returns 14 for flashlight-on and 8 otherwise.

### fov.lua
Remove the `torch_active` local, the omni-ring pass, and `self._torch_active` assignment. The file is not called in 3D but should not carry dead code.

## What stays the same

- Flashlight factory, burn timer, toggle behaviour — untouched
- Flare gun — untouched
- Fog range values (8 / 14) — unchanged
- Sight LOS raycast logic — unchanged; only the secondary glow trigger is retargeted
- item_spawner flashlight count (3–5 at budget ≥ 1) — unchanged
- Tests for flashlight and flare gun — should still pass with no edits

## Open questions

None — user confirmed:
- Sight glow transfers to flashlight-on
- Two fog tiers (8 / 14) are acceptable; no intermediate value needed
