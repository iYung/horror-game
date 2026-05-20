## Remove Torch Checklist

- [x] Task A — `game/data/items.lua` — delete the `torch` entry from `definitions`, the `make_torch` function, and the `torch = make_torch` line from `factories`
- [x] Task B — `game/world/item_spawner.lua` — remove the `if budget >= 1` torch spawn block (the `torch_count` local, `pick_random` call, and the loop inserting torch ground entries); leave the flashlight block intact
- [x] Task C — `game/scenes/run_scene.lua` — remove the `item.id == "torch" and item.active` branch from the fog-range picker so only the flashlight-on branch and the default `fog_range = 8` remain
- [x] Task D — `game/entities/monster.lua` — rename `torch_glow` to `flashlight_glow` and change its condition to `active_item.id == "flashlight" and active_item.active and active_item.on`; update the Sight check that references it
- [x] Task E — `test/watch_scene.lua` — remove the `item.id == "torch"` fog-range branch from the helper that computes fog range for rendering
- [x] Task F — `game/systems/fov.lua` — remove the `torch_active` local, the omni-ring pass block, and the `self._torch_active` assignment (file is unused in 3D but should not carry dead code)
- [x] Task G — `test/run_test.lua` — add an `it()` that: gives the monster the Sight trait, places the player out of LOS, toggles the flashlight on, steps the simulation, and asserts the monster transitions to chase; run the full test suite headlessly and confirm all pass
