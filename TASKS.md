# NIGHTFALL — Build Tasks

Roughly in implementation order. Complete each before moving to the next.

---

## 0. Project Setup

- [ ] Rename window title to "NIGHTFALL" in `main.lua`
- [ ] Create folder structure: `game/entities/`, `game/systems/`, `game/world/`, `game/ui/`, `game/data/`
- [ ] Create `game/data/items.lua` — item definitions (torch, flashlight, flare gun)
- [ ] Create `game/data/traits.lua` — trait definitions and point costs

---

## 1. World & Map

- [ ] Create `game/world/map.lua` — grid data structure, tile types (floor/wall), collision query
- [ ] Create `game/world/map_forest.lua` — Forest Facility layout (40×30 grid, spawn point, extraction zone)
- [ ] Create `game/world/map_hospital.lua` — Abandoned Hospital layout (40×30 grid, spawn point, extraction zone)
- [ ] Render map tiles via Drawer (walls a different color from floors)

---

## 2. Core Systems

- [ ] Create `game/systems/fov.lua` — raycast from player position, wall-blocked, cone shaped by facing direction; track explored vs visible cells
- [ ] Create `game/systems/camera_shake.lua` — offset layered on top of Camera follow; driven by distance buckets
- [ ] Create `game/systems/inventory.lua` — 5 slots, active slot toggle, drop, ground swap
- [ ] Create `game/systems/pathfinder.lua` — A* on the grid (used by monster WANDER state)

---

## 3. Player

- [ ] Create `game/entities/player.lua` — WASD movement, last-moved facing direction, same base speed as monster constant
- [ ] Wire inventory to player — slot toggle (`Q`/`E`), use item (`F`), pick up / drop (`G`)
- [ ] Wire player into FOV system — recompute visibility each frame from player position + facing

---

## 4. Monster

- [ ] Create `game/entities/monster.lua` — base wander state (random walk via pathfinder), kills player on contact
- [ ] Implement monster state machine: WANDER → ALERTED → CHASE → SEARCH → WANDER
- [ ] Implement **Sight** trait — LOS raycast, instant chase on detection, lose player after 3 s without LOS
- [ ] Implement **Speed** trait — apply speed tier constant to monster
- [ ] Implement **Smell** trait — global player position poll at low frequency, trigger chase
- [ ] Implement **Hearing** trait — detect player movement within 8 cells, trigger alerted state
- [ ] Wire monster step timer → camera shake system (proximity buckets)
- [ ] Monster walks through walls (ignore wall collision, pathfinder only used for WANDER idle)

---

## 5. Items

- [ ] Create `game/world/item_spawner.lua` — place items randomly on floor tiles, budget-gated, flare gun min distance from spawn
- [ ] Implement **Torch** — omnidirectional light radius (~3 cells), consumable duration, visible to sighted monster through walls
- [ ] Implement **Flashlight** — widens FOV cone to ~120°, extended range, consumable battery, toggle on/off
- [ ] Implement **Flare Gun** — single use, triggers extraction countdown when used at extraction zone

---

## 6. Extraction Flow

- [ ] Mark extraction zone on map; show pulsing icon in HUD once player has been within 3 cells
- [ ] Flare gun use at extraction zone starts 60-second countdown
- [ ] HUD countdown timer display
- [ ] On countdown end, player steps exit tile → run over (extraction success)
- [ ] Death at any point during run → all carried items lost → death result

---

## 7. HUD

- [ ] Create `game/ui/hud.lua` — 5 inventory slots, active slot highlight, extraction countdown

---

## 8. Scenes

- [ ] Create `game/scenes/planning_scene.lua` — stash panel (max 10), loadout slot, map picker, budget picker, confirm button; builds `RunConfig` and rolls monster traits
- [ ] Create `game/scenes/trait_reveal_scene.lua` — full-screen card, monster name, trait names list, "press any key"
- [ ] Create `game/scenes/run_scene.lua` — initialise map + spawner + player + monster + FOV + HUD; handle win/lose transitions
- [ ] Create `game/scenes/result_scene.lua` — extraction success or death summary; on success merge inventory into stash; return to planning
- [ ] Wire all scenes through `SceneManager` in `main.lua`

---

## 9. Fog of War Rendering

- [ ] Render unexplored cells as fully black
- [ ] Render explored-but-not-visible cells at ~40% brightness
- [ ] Render currently-visible cells at full brightness
- [ ] Only draw monster sprite when inside a currently-visible cell
- [ ] Torch glow visible to sighted monster even outside player's FOV cone

---

## 10. Polish

- [ ] Screen shake tuning — tweak magnitude values per distance bucket
- [ ] Extraction zone pulse animation
- [ ] Trait reveal card styling
- [ ] Planning scene layout and visual polish
- [ ] Result screen styling (success vs death)
