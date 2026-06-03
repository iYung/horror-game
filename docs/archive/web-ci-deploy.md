## Web CI Deploy Checklist

- [x] Task A — `package.json` — create with `love.js@11.4.1` as the only dev dependency
- [x] Task B — `scripts/build_web.sh` — create build script: zip `main.lua conf.lua assets/ core/ game/` into `game.love`, run `npx love.js`, copy `web-template/controls.js` into `web/`, inject `<script src="controls.js"></script>` before `</body>` in `web/index.html`, delete `game.love`
- [x] Task C — `web-template/controls.js` — create touch/mobile control overlay adapted for NIGHTFALL: canvas scaling at 1280×720 aspect ratio, left cluster WASD buttons, right cluster F / G / Esc buttons
- [x] Task D — `.github/workflows/web.yml` — create workflow: trigger on push to `master` and PR events (opened/synchronize/reopened/closed); four jobs: build (zip + love.js + upload artifact), deploy (master push → gh-pages root), deploy-pr (PR open/sync → `pr-N/` + post preview comment to `https://iyung.github.io/horror-game/pr-N/`), cleanup-pr (PR close → delete `pr-N/` from gh-pages)
