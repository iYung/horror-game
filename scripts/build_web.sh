#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Zipping game files into game.love..."
zip -r game.love main.lua conf.lua assets/ core/ game/

echo "Running love.js to build web output..."
npx love.js game.love web/ --title "NIGHTFALL" --compatibility

echo "Copying controls.js into web/..."
cp web-template/controls.js web/controls.js

echo "Injecting controls.js script tag into web/index.html..."
sed -i 's|</body>|<script src="controls.js"></script>\n</body>|' web/index.html

echo "Cleaning up game.love..."
rm game.love

echo "Build complete. Output is in web/"
