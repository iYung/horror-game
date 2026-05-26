## Goal

Make extraction more forgiving. Currently the 30 s countdown is a hard deadline — if the player is not standing in the zone the instant it hits zero, they fail the run. The new behaviour keeps the extraction zone "hot" after the timer fires so the player can return and still extract, removing the binary pass/fail on zone presence at expiry. The timer is also halved from 60 s to 30 s to preserve tension.

## Affected files

- `game/systems/extraction.lua` — core logic change + duration constant
- `game/scenes/run_scene.lua` — remove "failed" handler; extraction can no longer produce a fail outcome
- `game/ui/hud.lua` — new display state when timer has fired but player isn't yet in zone
- `tests/test_run.lua` — update existing extraction test's `max_seconds`, add new test for out-then-back scenario

## What changes

### `extraction.lua`

- `Extraction.DURATION`: 60 → 30
- Add `_ready` boolean field (default false). Represents "timer fired, waiting for player to step in."
- `update()` logic when the timer fires:
  - If player is in zone → return `"extracted"` (unchanged)
  - If player is not in zone → set `self._ready = true`, return `nil` (was `"failed"`)
- `update()` each subsequent frame when `_ready` is true:
  - If player is in zone → return `"extracted"`
  - Otherwise → return `nil` (keep waiting)
- Add `is_ready()` method — returns `self._ready`. Used by HUD to differentiate "counting down" from "timer done, return to zone."
- `is_active()` continues to return true during the countdown phase. Once `_ready` is true the timer object is gone, so `is_active()` naturally returns false — callers that need to distinguish countdown vs ready use `is_ready()`.
- `time_remaining()` already returns 0 when `_timer` is nil, which covers the ready state.

### `run_scene.lua`

- Remove the `result == "failed"` branch entirely. The "failed" outcome is no longer reachable from extraction.

### `hud.lua`

- Current: shows `"EXTRACTING  MM:SS"` when `extraction:is_active()` (countdown running).
- New: after countdown, `is_active()` returns false but `is_ready()` returns true. HUD shows a pulsing `"RETURN TO EXTRACT"` label (same position, amber colour) to guide the player back.
- The pulsing `"▼ EXTRACT"` indicator (shown when discovered but not yet started) is unchanged.

### `tests/test_run.lua`

- `"player extracts after completing countdown in zone"`: reduce `max_seconds` from 70 to 40 (30 s timer + buffer).
- New test `"player extracts after returning to zone post-countdown"`: start countdown, teleport player out of zone during countdown, let timer fire, teleport player back in, assert `"extracted"`.

## What stays the same

- How extraction starts — fire flare gun while in zone
- The discovery mechanic and `"▼ EXTRACT"` pulsing indicator
- Monster behaviour, player death (`"death"` outcome), all other systems
- `result_scene.lua` — the `"failed"` outcome path remains in ResultScene in case it's used elsewhere, but RunScene will no longer route to it via extraction

## Open questions

None — the behaviour is fully specified by the request.
