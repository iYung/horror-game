# Web CI Deploy

## Goal

Add a GitHub Actions workflow that builds a playable web version of NIGHTFALL
using love.js and deploys it to GitHub Pages — a live preview for every PR, and
a canonical build on every push to master. Mirror the setup used in the wip and
wip-3d repos. Also make the repo public so GitHub Pages can serve it.

## Affected files

- `.github/workflows/web.yml` — new workflow (build + deploy + PR preview + cleanup)
- `scripts/build_web.sh` — new build script (zip → love.js → inject controls)
- `web-template/controls.js` — new mobile/touch control overlay (adapted for WASD + F/G/Esc)
- `package.json` — new, declares `love.js@11.4.1` as a dev dependency

## What changes

### Workflow (`.github/workflows/web.yml`)

Identical structure to wip-3d's `web.yml`, with two differences:
- Triggers on `master` (this repo's primary branch), not `main`
- PR preview URL points to `https://iyung.github.io/horror-game/pr-N/`

Four jobs:
1. **build** — runs on push to master and on PR open/sync; zips game files, runs love.js, uploads artifact
2. **deploy** — runs on push to master; deploys artifact to gh-pages root
3. **deploy-pr** — runs on PR open/sync; deploys artifact to `gh-pages/pr-N/` and posts a comment with the preview link
4. **cleanup-pr** — runs on PR close; removes `gh-pages/pr-N/` directory

### Build script (`scripts/build_web.sh`)

Same pipeline as wip-3d, but zips horror-game's file tree:
```
main.lua  conf.lua  assets/  core/  game/
```
`tests/` and `docs/` are excluded — not needed at runtime.

### Controls (`web-template/controls.js`)

Adapted from wip-3d's controls.js. Canvas scaling stays the same (1280×720).
Button layout adapted for NIGHTFALL's control scheme:

| Cluster | Buttons |
|---------|---------|
| Left (movement) | W (up), A (left), S (down), D (right) |
| Right (actions) | F (use), G (pickup/drop), Esc (settings) |

Planning-scene controls (M, Up/Down, L, Enter) are keyboard-only for now —
they're one-time config actions that work fine on desktop.

### `package.json`

Declares `love.js@11.4.1` as the only dev dependency, matching wip-3d exactly.

### Repo visibility

The repo must be made public for GitHub Pages to serve the site on the free
plan. This is a one-time manual step in GitHub settings (Settings → Danger Zone
→ Change visibility).

## What stays the same

- Existing `ci.yml` (test runner) is untouched
- Game source, conf.lua, and all Lua code unchanged
- love.js version matches wip and wip-3d (11.4.1)

## Open questions

None — the reference implementations in wip and wip-3d are a direct template.
The only manual step is making the repo public on GitHub before the first
Pages deploy will succeed.
