## Compass Checklist

- [x] Task A — `game/data/items.lua` — Add `compass` entry to `definitions` (`id="compass"`, `name="Compass"`, `value=3`). Add `make_compass` factory: copies definition fields, sets no `use_fn`, no `update`, no timer state. Register it in `factories`. Update the file header comment to document the new item.

- [x] Task B — `game/ui/hud.lua` — Add `player` as a third parameter to `HUD.new`; store as `self.player`. In `HUD:draw()`, after the extraction indicator block, add a compass arrow section: if `self.player` is set and the active item's id is `"compass"`, compute `dx/dy` from `player:centre()` to `self.extraction._zone.{x,y}`, derive `world_angle = math.atan2(dy, dx)`, compute `relative_angle = world_angle - self.player.angle`, then draw a small filled white triangle (arrow) at screen center-bottom (x=640, y=680) rotated by `relative_angle` using `love.graphics.push/pop` + `love.graphics.translate/rotate`. Reset color and line width after.

- [x] Task C — `game/scenes/run_scene.lua` — Change the single `HUD.new(self.player.inventory, self.extraction)` call to `HUD.new(self.player.inventory, self.extraction, self.player)`.

- [x] Task D — `test/run_test.lua` — Add one `it("compass item can be held without errors")` test: build a `RunConfig` with `budget=3` and `loadout_item = items.new("compass")`, create `Simulation.new(run_config)`, call `sim:step(1/60)` several times (e.g. 10 frames), assert no error and `state` is returned (outcome is nil). This is a smoke test — compass has no behavioral side-effects to assert.
