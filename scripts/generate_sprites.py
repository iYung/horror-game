#!/usr/bin/env python3
"""Generate solid-colour RGBA PNGs for all billboard types used in the game."""
from PIL import Image
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
os.makedirs(OUT_DIR, exist_ok=True)

def rect(filename, w, h, r, g, b, a=255):
    img = Image.new("RGBA", (w, h), (int(r * 255), int(g * 255), int(b * 255), a))
    path = os.path.join(OUT_DIR, filename)
    img.save(path)
    print(f"  {filename}  ({w}x{h})")

# Billboards
rect("monster.png",    64, 128, 0.9, 0.1, 0.1)   # red
rect("flashlight.png", 64,  64, 1.0, 0.9, 0.3)   # yellow
rect("flare_gun.png",  64,  64, 1.0, 0.2, 0.8)   # pink
rect("compass.png",    64,  64, 0.3, 0.8, 1.0)   # cyan
rect("tracker.png",    64,  64, 1.0, 0.4, 0.1)   # orange
rect("adrenaline.png", 64,  64, 0.2, 1.0, 0.4)   # green
rect("taser.png",      64,  64, 0.3, 0.8, 1.0)   # light blue
rect("extraction.png", 32, 256, 0.1, 1.0, 0.2)   # bright green, tall
rect("torch.png",      32,  32, 1.0, 0.65, 0.15) # amber

print("\nDone. Output written to assets/sprites/")
