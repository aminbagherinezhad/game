"""Converts Unity Labs CC0 flipbooks into thermal-camera sheets in assets/textures.

Usage: python tools/convert_vfx.py <folder with the extracted x_<Name> folders>
Colour becomes white-hot brightness; the alpha of the simulation is kept.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SOURCE = Path(sys.argv[1])
OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"

# (source folder, tga name, output name, gamma, gain, lift)
SHEETS = [
    ("x_Explosion02HD", "Explosion02HD_5x5.tga", "explosion_fire.png", 1.5, 0.82, 0.17),
    ("x_Explosion01", "Explosion01_5x5.tga", "explosion_fire_b.png", 1.5, 0.82, 0.17),
    ("x_DiscSmoke01", "DiscSmoke01_16x4.tga", "explosion_dust.png", 0.8, 1.0, 0.2),
]

for folder, tga, name, gamma, gain, lift in SHEETS:
    pixels = np.asarray(Image.open(SOURCE / folder / tga).convert("RGBA"), dtype=np.float32) / 255
    brightness = pixels[..., 0] * 0.45 + pixels[..., 1] * 0.45 + pixels[..., 2] * 0.1
    value = np.clip(lift + brightness ** gamma * gain, 0, 1)
    channels = np.stack([value, pixels[..., 3]], axis=-1)
    Image.fromarray((channels * 255).astype(np.uint8), "LA").save(OUT / name)
