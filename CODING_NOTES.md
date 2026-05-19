# Coding Notes

## Use core components whenever possible

All engine primitives live in [core/lua/](core/lua/). Reach for them before writing anything new.

| Need | Use |
|------|-----|
| Something drawable | `Sprite` or `SpriteSet` |
| Managing draw order | `Drawer` — register with a priority, let it sort |
| Game states | `Scene` — subclass it, override `update`/`draw`/`on_enter`/`on_exit` |
| Switching states | `SceneManager:switch()` |
| Camera tracking / transforms | `Camera` — use `attach()`/`detach()` around world draws |
| Keyboard input | `Input` with an action map — never call `love.keyboard` directly |
| Recurring ticks / countdowns | `Timer` |

If you find yourself reimplementing interval tracking, input polling, or draw ordering, stop and use the core class instead.

New engine-level utilities (e.g. `camera_shake`, `pathfinder`, `fov`) should live in `core/lua/` and carry no game-specific knowledge, matching the style of existing core files.

---

## Run tests and add tests for every change

For any change to game logic: **run the existing suite, then add a new test** for the new behaviour before calling it done.

```
love . -- --headless    # fast, exits 0/1 — run this before committing
love . -- --watch       # visual — watch the scenarios play out in 3D
```

Tests live in `test/run_test.lua`. The existing suite covers kill detection, extraction success/failure, and all four traits. Every new trait, item, or touch to monster/extraction logic needs a matching `it()` added there. See **CLAUDE.md → Testing** for what each type of change requires.
