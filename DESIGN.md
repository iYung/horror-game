# NIGHTFALL — Horror Game Design Document

## Overview

A single-player top-down horror game with an Escape from Tarkov-style loop: plan a run, survive it, extract. Each run pits you against one procedurally-traitened monster on a grid-based map with free movement. Think more *Alien: Isolation* than *Call of Duty* — you are slow, fragile, and outmatched. Your only advantages are preparation and patience.

---

## Game Loop

```
[PHASE 1: PLANNING] → [PHASE 2: RUN] → back to PHASE 1
           ↑                  │
           └──────────────────┘  (whether you extracted or died)
```

---

## Phase 1 — Planning Screen

A menu-style UI between runs. No time pressure.

### Panels

**Stash (left)**
- Your permanent item collection, max 10 slots. In-memory only (not saved to disk in v1).
- Items survive extraction; all items carried on a run are lost on death.
- Populated by items you successfully extracted in previous runs.
- First run begins with an empty stash — no starting items.

**Loadout (centre)**
- One item slot. Drag or select one item from the stash to bring into the run.
- The chosen item appears in your Phase 2 inventory slot 1.

**Mission Config (right)**

| Setting | Options |
|---------|---------|
| Map | Forest Facility / Abandoned Hospital |
| Difficulty Budget | 0 – 7 points |

The difficulty budget is the total trait-point ceiling for the monster spawned this run. Higher budget = potentially scarier monster = better loot table.

**Confirm** button starts Phase 2.

---

## Phase 2 — The Run

### Monster Trait Screen (splash before gameplay)

Before the player gains control, a full-screen card lists:

- Monster name (flavour only, e.g. "THE HOLLOW")
- Each trait the monster rolled, with a one-line description
- "Press any key to begin"

### World

- **Grid**: each cell is 32 × 32 pixels (world units). Walls, doors, and impassable terrain snap to the grid.
- **Movement**: player and monster move freely in world-space (not locked to cells). The grid is only a layout / collision primitive.
- **Map size**: ~40 × 30 cells (1280 × 960 world pixels). Camera tracks the player with gentle lerp.

### Fog of War & Line of Sight

- All cells start fully occluded (black).
- **Explored cells** (previously visible) render dimmed (~40% brightness).
- **Currently visible cells** are fully lit.
- Visibility is a cone/circle raycast from the player, blocked by walls.
- The monster is only drawn when inside a currently-visible cell.
- Flashlight item extends the cone; torch item reveals a small static ring around the player.

### Player

- **HP**: 1 (death on monster contact).
- **Speed**: Same base speed as the monster. Both defined in a shared configurable constant.
- **Facing**: Last-moved direction. No mouse aim.
- **Inventory**: 5 slots, toggled with `Q` / `E` or number keys 1–5. Active item shown in HUD.
- **Actions**: `F` to interact (use item, trigger extraction); `G` to pick up a ground item or drop/swap the active item. No sprint.

#### Starting conditions
- Spawns at the map's designated spawn point.
- Slot 1 holds the item chosen in Phase 1 (if any).

### Items

Each item has a **point value** — it can only spawn on a run if its value ≤ the difficulty budget.

| Item | Value | Effect |
|------|-------|--------|
| Torch | 1 pt | Lights a small omnidirectional radius (~3 cells) around the player. Consumable — burns out after a fixed duration. A sighted monster can see the torch's glow through walls. |
| Flashlight | 1 pt | Widens LOS cone to ~120°, extended range. Consumable — battery runs out after a fixed duration. Toggle on/off. |
| Flare Gun | — | Always spawns. Single-use. Required to trigger extraction. Spawns randomly each run, guaranteed not near the player spawn. |

Flashlight and Torch spawn randomly on the ground (3–6 each, budget-gated). Flare Gun has one spawn per run.

### Extraction

1. Player reaches the **Extraction Zone** (marked on map once visited, always on opposite side from spawn).
2. Player uses the **Flare Gun** (`F` while it's active) at the zone.
3. **60-second countdown** begins. A visible timer appears in the HUD.
4. Player survives the wait. Monster aggro may intensify during countdown (TBD, see open questions).
5. Player steps on the exit tile → run ends → extraction success screen → return to Phase 1 with any inventory items added to stash.

Death during countdown = failed extraction. Items in inventory are lost.

### Monster

#### Base Behaviour (0 pts)

- Wanders the map on a random walk: picks a random navigable cell, pathfinds to it, then picks another.
- Kills the player instantly on contact (bounding-box overlap, ~16 px radius).
- No perception — completely blind and deaf at base.

#### Traits (point costs)

| Trait | Cost | Effect |
|-------|------|--------|
| **Sight** | 2 pts | Detects player via LOS raycast (wall-blocked). Instant chase on detection. Loses player if LOS breaks for > 3 s. |
| **Speed** | 1 pt | Increases movement speed by one configurable tier above base. |
| **Smell** | 1 pt | Detects the player globally (no range limit, no wall blocking) at a low polling frequency. |
| **Hearing** | 1 pt | Detects player movement within 8 cells. Only player movement triggers it — no other sound events. |

Each trait appears at most once per run. Trait selection is random within the budget: sample the affordable trait pool and greedily pick until the next trait would exceed the budget. This means a 3-pt budget might produce [Smell + Hearing] or [Speed + Hearing] or [Sight], etc.

#### Monster States

```
WANDER → (triggered) → ALERTED → (LOS/smell/hearing lost for threshold) → SEARCH → (timeout) → WANDER
                                         ↓ (finds player)
                                       CHASE
```

- **WANDER**: slow random walk.
- **ALERTED**: moves toward trigger location, head-turn animation (v1: just faster wander toward point).
- **CHASE**: full speed beeline to player last-known-position.
- **SEARCH**: paces around last-known-position for a few seconds.

#### Screen Shake (Proximity)

The monster emits a "step" event on a timer synced to its walk cycle (~0.5 s).

- Distance buckets and shake intensity:

| Distance (cells) | Shake magnitude |
|------------------|----------------|
| > 10 | none |
| 6 – 10 | very subtle (±1 px) |
| 3 – 6 | noticeable (±3 px) |
| < 3 | violent (±6 px) |

Shake is a random offset applied to the camera for one frame, decaying over ~0.15 s. This fires even through walls — proximity, not LOS.

---

## Maps

### Map A — Forest Facility

Outdoor corridors between modular prefab buildings. Sparse, long sightlines. Cover is rare. Monster has more room to roam. Good for sight-heavy builds.

Key landmarks: Guard shack (spawn), generator room, storage depot, extraction helipad. No doors — open corridors throughout.

### Map B — Abandoned Hospital

Dense indoor rooms, many doors. Short sightlines. Lots of ambush corners. Monster feels claustrophobic. Good for hearing/smell builds.

Key landmarks: Ambulance bay (spawn), wards, operating theatre (likely flare location), roof exit (extraction). No doors — open corridors throughout.

---

## HUD

```
┌─────────────────────────────────────────────────────────┐
│  [1][2][3][4][5]   (item slots, active slot highlighted) │
│                                                         │
│                  [world view]                           │
│                                                         │
│                               EXTRACTING: 00:47  (cond)│
└─────────────────────────────────────────────────────────┘
```

- No minimap — ever. Disorientation is intentional.
- Extraction zone marked with a subtle pulsing icon once the player has been within 3 cells of it.

---

## Scenes (Love2D SceneManager)

| Scene | File | Purpose |
|-------|------|---------|
| `PlanningScene` | `game/scenes/planning_scene.lua` | Phase 1 UI |
| `TraitRevealScene` | `game/scenes/trait_reveal_scene.lua` | Pre-run monster card |
| `RunScene` | `game/scenes/run_scene.lua` | Phase 2 gameplay |
| `ResultScene` | `game/scenes/result_scene.lua` | Extraction / death summary |

---

## File Structure (proposed)

```
game/
  scenes/
    planning_scene.lua
    trait_reveal_scene.lua
    run_scene.lua
    result_scene.lua
  entities/
    player.lua
    monster.lua
  systems/
    fov.lua          -- raycasting / fog of war
    camera_shake.lua -- shake state driven by monster proximity
    pathfinder.lua   -- A* on the grid
    inventory.lua    -- slot management
  world/
    map.lua          -- grid data, tile types, collision
    map_forest.lua   -- Forest Facility layout definition
    map_hospital.lua -- Abandoned Hospital layout definition
    item_spawner.lua -- random item placement
  ui/
    hud.lua
    stash_panel.lua
    mission_panel.lua
  data/
    items.lua        -- item definitions
    traits.lua       -- trait definitions and costs
```

---

## Data Structures (sketch)

```lua
-- Save state (persists between runs)
SaveState = {
  stash = { Item, ... },  -- max 10
}

-- Run config (set in planning, consumed in run)
RunConfig = {
  map_id         = "forest" | "hospital",
  budget         = number,       -- 0..7
  loadout_item   = Item | nil,
  monster_traits = { Trait, ... },
}

-- Item
Item = {
  id      = string,
  name    = string,
  use_fn  = function(player, world),
}

-- Trait
Trait = {
  id    = string,
  name  = string,
  cost  = number,
  apply = function(monster),
}
```

---

## Phase 1 → Phase 2 Hand-off

1. Planning scene builds a `RunConfig`.
2. Rolls monster traits from budget: repeatedly sample random traits until adding the next one would exceed the budget. Shuffle the affordable pool and greedily pick.
3. Passes `RunConfig` to `TraitRevealScene`, which then passes to `RunScene`.
4. `RunScene.on_enter()` initialises map, spawns items, creates monster with traits applied.

---

## Win / Lose Conditions

| Outcome | Condition | Result |
|---------|-----------|--------|
| Extraction | Player steps off exit tile after flare countdown | Items added to stash, success screen |
| Death | Monster touches player | Items lost, death screen |

Both return to the Planning scene.
