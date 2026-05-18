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
