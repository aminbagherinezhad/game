"""Crops and grades the weapon card photos into assets/weapons.

Usage: python tools/prepare_weapon_photos.py <weapon photo folder> <drone photo folder>
See assets/CREDITS.md for the source and licence of each photo.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SOURCE = Path(sys.argv[1])
DRONE_SOURCE = Path(sys.argv[2])
OUT = Path(__file__).resolve().parent.parent / "assets" / "weapons"
OUT.mkdir(parents=True, exist_ok=True)
WIDTH = 900


def crop(name, box, source=SOURCE):
    image = Image.open(source / name).convert("RGB")
    w, h = image.size
    area = (int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h))
    part = image.crop(area)
    return part.resize((WIDTH, int(part.height * WIDTH / part.width)), Image.LANCZOS)


def vignette(size, strength):
    w, h = size
    ys, xs = np.mgrid[0:h, 0:w]
    dx, dy = (xs - w / 2) / (w / 2), (ys - h / 2) / (h / 2)
    return 1 - strength * np.clip(np.hypot(dx, dy) - 0.45, 0, 1) ** 1.4


def grade(image, contrast, brightness, edge):
    pixels = np.asarray(image, dtype=np.float32) / 255
    pixels = np.clip((pixels - 0.5) * contrast + 0.5, 0, 1) * brightness
    pixels = pixels * vignette(image.size, edge)[..., None]
    return np.clip(pixels, 0, 1)


def save(pixels, name):
    Image.fromarray((pixels * 255).astype(np.uint8)).save(OUT / name, quality=90)


# The gun is cool grey and the wall warm, which lets the wall fall away into darkness.
gun = crop("c10.jpg", (0.58, 0.22, 1.0, 0.79))
values = np.asarray(gun, dtype=np.float32) / 255
coolness = values[..., 2] - values[..., 0]
mask = Image.fromarray((np.clip((coolness - 0.015) / 0.05, 0, 1) * 255).astype(np.uint8))
mask = np.asarray(mask.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(1.5)), dtype=np.float32)[..., None] / 255
steel = values.mean(axis=2, keepdims=True) * np.array([0.92, 0.97, 1.05])
steel = np.clip((steel - 0.42) * 1.9 + 0.5, 0, 1)
wall = values.mean(axis=2, keepdims=True) * np.array([0.1, 0.12, 0.15])
save(np.clip((steel * mask + wall * (1 - mask)), 0, 1) * vignette(gun.size, 0.7)[..., None], "gun.jpg")

save(grade(crop("c02.jpg", (0.13, 0.03, 0.69, 0.71)), 1.22, 0.9, 0.85), "kheibar.jpg")

fattah = grade(crop("c06.jpg", (0.12, 0.0, 0.8, 1.0)), 1.3, 1.0, 0.8)
save(np.repeat(fattah.mean(axis=2, keepdims=True), 3, axis=2), "fattah2.jpg")

save(grade(crop("s04.jpg", (0.47, 0.25, 1.0, 0.88), DRONE_SOURCE), 1.2, 0.92, 0.8), "shahed136.jpg")
