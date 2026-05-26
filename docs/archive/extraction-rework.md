## Extraction Rework Checklist

- [x] Task A — `game/systems/extraction.lua` — Change `DURATION` from 60 to 30. Add `self._ready = false` in `new()`. In `update()`, when the timer fires and the player is not in zone, set `self._ready = true` and return `nil` instead of `"failed"`. Add a new check at the top of `update()`: if `self._ready` and `self:in_zone(player)` return `"extracted"`. Add `is_ready()` method that returns `self._ready`.

- [x] Task B — `game/scenes/run_scene.lua` — Remove the `result == "failed"` branch from `RunScene:update()`. Extraction no longer returns `"failed"`, so this dead branch should be deleted entirely. *Depends on Task A.*

- [x] Task C — `game/ui/hud.lua` — In `HUD:draw()`, after the `extraction:is_active()` block, add an `elseif self.extraction:is_ready()` branch that prints a pulsing `"RETURN TO EXTRACT"` label at the same screen position and colour as the countdown label. *Depends on Task A.*

- [x] Task D — `tests/test_run.lua` — (1) In the existing `"player extracts after completing countdown in zone"` test, reduce `max_seconds` from 70 to 40. (2) Add a new test `"player extracts after returning to zone post-countdown"`: start extraction, teleport player out of zone, let the 30 s timer fire, teleport player back into zone, assert outcome is `"extracted"`. *Depends on Tasks A, B, C.*
