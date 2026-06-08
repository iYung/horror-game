# Audio System

## Goal

Port the `sound.lua` module architecture from `../wip-3d` and wire it into horror-game's events. The result is a singleton `Sound` module that any file can call without passing references. No audio assets are required to ship the code — every `load()` path checks `love.filesystem.getInfo` before creating a source, so missing files are silently skipped.

---

## Affected files

| File | Change |
|------|--------|
| `game/sound.lua` | New file — ported + adapted from wip-3d |
| `main.lua` | `Sound.load()` in `love.load`; `Sound.update(dt)` in `love.update` |
| `game/scenes/run_scene.lua` | Trigger SFX on footstep, alert, item pickup/use, extraction, death |
| `game/scenes/planning_scene.lua` | Start menu music on enter; stop on exit |
| `game/scenes/result_scene.lua` | Play win/lose sting on enter |
| `game/entities/monster.lua` | Trigger `"monster_step"` in the step timer callback |
| `assets/sounds/` | Placeholder directory (empty, .gitkeep) |
| `assets/music/` | Placeholder directory (empty, .gitkeep) |

---

## What changes

### `game/sound.lua`

Straight port of wip-3d's architecture (module-level singleton, no `new()`). Game-specific adaptations:

**SFX events** (one `.wav` per name, static source, cloned on each play):

| Event name | When triggered |
|------------|---------------|
| `"monster_step"` | Monster step timer fires (already calls `shake:trigger`) |
| `"monster_alerted"` | Monster transitions into ALERTED or CHASE state |
| `"item_pickup"` | Player picks up a ground item (`G` key path in RunScene) |
| `"item_use"` | Player uses active item (`F` key path in RunScene) |
| `"extraction_start"` | `extraction:try_start()` returns true |
| `"extraction_ready"` | Extraction timer fires while player is out of zone (`_ready` set) |
| `"player_death"` | `monster.on_kill` fires |

**Music tracks** (`.wav` or `.mp3`, streamed, looping):

| Track name | Scene | Behaviour |
|------------|-------|-----------|
| `"menu"` | PlanningScene / ResultScene | Plays on `PlanningScene:on_enter()`; stops on exit to run |
| `"ambient"` | RunScene (calm) | Fades in on `RunScene:on_enter()` |
| `"chase"` | RunScene (monster CHASE state) | Fades in when monster enters CHASE; fades back to `"ambient"` when monster leaves CHASE |

API — identical to wip-3d's except event names:
```lua
Sound.load()                           -- called once in love.load
Sound.update(dt)                       -- called every frame in love.update
Sound.play(name)                       -- fire-and-forget SFX clone
Sound.set_sfx_volume(0..1)
Sound.set_music_volume(0..1)
Sound.play_music(name)                 -- start immediately at full volume
Sound.fade_music(name, target, secs)   -- smooth volume ramp
Sound.stop_music(name)
Sound.is_music_playing(name) → bool
```

`play_animalese` and all wip-3d plant/shop events are removed.

### Chase music toggle

Monster's state machine currently runs `self.state = "chase"` in several places. RunScene will detect state transitions in its `update()` loop:

```lua
-- after monster:update(dt, player)
local new_state = self.monster.state
if new_state ~= self._prev_monster_state then
    if new_state == "chase" then
        Sound.fade_music("chase",   1, 1.0)
        Sound.fade_music("ambient", 0, 1.0)
    elseif self._prev_monster_state == "chase" then
        Sound.fade_music("ambient", 1, 2.0)
        Sound.fade_music("chase",   0, 2.0)
    end
    self._prev_monster_state = new_state
end
```

`self._prev_monster_state` is set to `"wander"` in `RunScene:on_enter()`.

### `main.lua`

In the normal (non-headless) path:
- `Sound.load()` called inside `love.load()` after `love.window.setMode`.
- `Sound.update(dt)` called at the top of `love.update(dt)` unconditionally (no-ops if audio is disabled or assets are missing).

In headless mode, `love.audio` is nil (conf.lua already disables it), so every `Sound.*` function checks `if not love.audio then return end` and exits immediately — no changes needed to the headless path.

---

## What stays the same

- All game logic untouched.
- `Simulation` / headless testing: `love.audio` is nil in `--headless` mode; every Sound function guards on this and returns early.
- Settings menu: volume sliders are out of scope for this feature (can be wired later via `Sound.set_sfx_volume` / `Sound.set_music_volume`).

---

## Open questions

None. Asset files (`.wav`, `.mp3`) are decoupled — the system is functional and testable without them. Real audio assets can be added to `assets/sounds/` and `assets/music/` at any time.
