# NIGHTFALL — Open Questions

All questions resolved. Kept here as a decision log.

---

## Monster Traits

**1. Can Speed stack?**
**RESOLVED: Each trait appears at most once per run.**

**2. What is the monster's base speed?**
**RESOLVED: Monster and player share the same base speed. Both live in a single configurable constant.**

**3. Hearing: what counts as a "sound event"?**
**RESOLVED: Only player movement triggers hearing. Nothing else.**

**4. Smell: does it work through walls?**
**RESOLVED: Smell is global (no range limit, no wall blocking), but polls at a lower frequency than other senses.**

**5. Sight: what happens at the edge of detection range?**
**RESOLVED: Sight is LOS-blocked (no seeing through walls). Detection is instant — monster immediately chases. Monster itself walks through walls.**

**6. Trait reveal — how much info?**
**RESOLVED: Trait names only on the pre-run card. No mechanical descriptions.**

---

## Extraction

**7. Does the monster intensify during the countdown?**
**RESOLVED: No special behavior. Monster's existing senses apply naturally — Sight/Hearing may draw it to the zone.**

**8. Can you cancel the countdown?**
**RESOLVED: No cancelling. Countdown runs to zero once the flare is fired.**

**9. Items lost on death during countdown?**
**RESOLVED: Yes. Any death loses all items carried on the run.**

---

## Inventory & Items

**10. Can you drop items or swap with ground items?**
**RESOLVED: Both. Player can drop held items and swap inventory items with ground items.**

**11. Do flashlight and torch run out?**
**RESOLVED: Both are consumables with limited duration.**

**12. Can a sighted monster detect the torch's glow without player LOS?**
**RESOLVED: Yes. Torch glow is visible to a sighted monster even through walls.**

**13. Does the stash start with anything?**
**RESOLVED: Nothing. First run the player goes in empty.**

---

## Maps

**14. Are doors toggleable? Does the monster open them?**
**RESOLVED: No doors. Open corridors only.**

**15. Exact map dimensions?**
**RESOLVED: Start with ~40 × 30 cells. Configurable for playtesting.**

**16. Is the flare gun location fixed or random?**
**RESOLVED: Random each run, but guaranteed not to spawn close to the player spawn point.**

**17. Minimap?**
**RESOLVED: Never present. Intentional design pillar.**

---

## Phase 1 / Persistence

**18. Stash penalty on death?**
**RESOLVED: Stash is always safe. Only items carried on the run are lost.**

**19. Stash persistence across sessions?**
**RESOLVED: In-memory for v1. Disk save (love.filesystem) is a future consideration.**

**20. Does the difficulty budget affect loot?**
**RESOLVED: Yes. Each item has a point value (e.g. torch = 1 pt). An item can only spawn if its value is ≤ the run's budget. Higher difficulty unlocks higher-value loot.**

---

## Polish / Feel

**21. Player facing direction?**
**RESOLVED: Last-moved direction. Controls are WASD + one interact button + one pickup/drop button. No mouse aim.**

**22. Sprint mechanic?**
**RESOLVED: No sprint.**

**23. Screen shake implementation?**
**RESOLVED: Shake is a random offset layered on top of the camera follow, not replacing it.**

**24. Audio in scope for v1?**
**RESOLVED: No audio for v1. Visual prototype first.**
