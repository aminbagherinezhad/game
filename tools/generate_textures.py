"""Builds the battlefield textures from CC0 Poly Haven photos.

Usage: python tools/generate_textures.py <folder with *_diff.jpg / *_nor_gl.jpg>
Writes greyscale maps to assets/textures. The layout constants must match
scripts/battlefield.gd.
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SOURCE = Path(sys.argv[1])
OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"
OUT.mkdir(parents=True, exist_ok=True)

MAP_SIZE = 4096
WORLD_SIZE = 240.0
SCALE = MAP_SIZE / WORLD_SIZE

ROAD_V_X = 16.0
ROAD_V_WIDTH = 9.0
ROAD_H_Z = 34.0
ROAD_H_WIDTH = 8.0
PAD = (-30.0, -36.0, 8.0, 24.0)
CRATERS = [(2, -44, 9), (-46, 14, 11), (34, 58, 8), (-74, 48, 12), (-60, -30, 7), (60, 34, 7), (-20, 62, 8)]

random.seed(4)
np.random.seed(4)


def px(value):
    return (value + WORLD_SIZE / 2) * SCALE


def grey(name, size=None):
    image = Image.open(SOURCE / f"{name}.jpg").convert("L")
    return image.resize((size, size), Image.LANCZOS) if size else image


def tiled(name, tile):
    image = np.asarray(grey(f"{name}_diff", tile), dtype=np.float32) / 255
    # Mirroring hides the seams of photos that do not tile perfectly.
    image = np.block([[image, image[:, ::-1]], [image[::-1, :], image[::-1, ::-1]]])
    reps = MAP_SIZE // (tile * 2) + 1
    return np.tile(image, (reps, reps))[:MAP_SIZE, :MAP_SIZE]


def blotches(cells, blur=0):
    small = Image.fromarray((np.random.rand(cells, cells) * 255).astype(np.uint8))
    big = small.resize((MAP_SIZE, MAP_SIZE), Image.BICUBIC)
    if blur:
        big = big.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(big, dtype=np.float32) / 255


def fractal(cells=(160, 420, 1000, 2100), weights=(0.42, 0.3, 0.18, 0.1)):
    return sum(blotches(cell) * weight for cell, weight in zip(cells, weights))


def smooth(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def mask(draw_fn, blur=1.5):
    image = Image.new("L", (MAP_SIZE, MAP_SIZE), 0)
    draw_fn(ImageDraw.Draw(image))
    return np.asarray(image.filter(ImageFilter.GaussianBlur(blur)), dtype=np.float32) / 255


def road_shape(draw, grow=0.0):
    half_v = ROAD_V_WIDTH / 2 + grow
    half_h = ROAD_H_WIDTH / 2 + grow
    draw.rectangle([px(ROAD_V_X - half_v), 0, px(ROAD_V_X + half_v), MAP_SIZE], fill=255)
    draw.rectangle([0, px(ROAD_H_Z - half_h), px(ROAD_V_X), px(ROAD_H_Z + half_h)], fill=255)


def tracks(draw, count):
    for _ in range(count):
        x = random.uniform(-110, 80)
        z = random.uniform(-110, 110)
        heading = random.uniform(0, math.tau)
        turn = random.uniform(-0.02, 0.02)
        left, right = [], []
        for _ in range(random.randint(50, 160)):
            heading += turn + random.uniform(-0.012, 0.012)
            x += math.cos(heading)
            z += math.sin(heading)
            side_x, side_z = -math.sin(heading) * 0.85, math.cos(heading) * 0.85
            left.append((px(x + side_x), px(z + side_z)))
            right.append((px(x - side_x), px(z - side_z)))
        draw.line(left, fill=random.randint(120, 230), width=7)
        draw.line(right, fill=random.randint(120, 230), width=7)


def scorch_marks():
    field = np.ones((MAP_SIZE, MAP_SIZE), dtype=np.float32)
    grain = fractal()
    for cx, cz, radius in CRATERS:
        size = int(radius * SCALE * 2.6)
        left, top = int(px(cx)) - size // 2, int(px(cz)) - size // 2
        ys, xs = np.mgrid[0:size, 0:size]
        dx, dy = xs - size / 2, ys - size / 2
        angle = np.arctan2(dy, dx)
        rays = sum(np.sin(angle * f + random.uniform(0, 6)) * a for f, a in [(4, 0.2), (9, 0.16), (17, 0.12), (37, 0.08)])
        dist = np.hypot(dx, dy) / (radius * SCALE) * (1 + rays * 0.55)
        patch = grain[top:top + size, left:left + size]
        burn = 1 - smooth(0.15, 1.2, dist + (patch - 0.5) * 1.3)
        pit = 1 - smooth(0.0, 0.26, dist + (patch - 0.5) * 0.4)
        field[top:top + size, left:left + size] *= 1 - burn * 0.7 - pit * 0.2
    return field


def debris():
    dark = Image.new("L", (MAP_SIZE, MAP_SIZE), 0)
    draw = ImageDraw.Draw(dark)
    for _ in range(14000):
        x, y = random.randrange(MAP_SIZE), random.randrange(MAP_SIZE)
        size = random.choice([1, 1, 2, 2, 3, 4])
        draw.polygon([(x + random.randint(-size, size), y + random.randint(-size, size)) for _ in range(4)],
                     fill=random.randint(120, 255))
    for cx, cz, radius in CRATERS:
        for _ in range(500):
            angle = random.uniform(0, math.tau)
            dist = random.uniform(0.3, 1.7) ** 2 * radius
            x, y = px(cx + math.cos(angle) * dist), px(cz + math.sin(angle) * dist)
            size = random.choice([1, 2, 3, 5, 7])
            draw.polygon([(x + random.randint(-size, size), y + random.randint(-size, size)) for _ in range(4)], fill=255)
    return np.asarray(dark, dtype=np.float32) / 255


def build_ground():
    dirt = tiled("aerial_mud_1", 1300)
    rock = tiled("aerial_ground_rock", 1500)
    field = dirt * 0.95 + 0.04
    field = field * (1 - smooth(0.42, 0.62, blotches(9, 40))) + rock * 1.1 * smooth(0.42, 0.62, blotches(9, 40))
    field *= 0.86 + 0.28 * blotches(14, 30)
    field = field * 0.8 + 0.1

    sand = tiled("aerial_sand", 1100) * 0.55 + 0.45
    ys, xs = np.mgrid[0:MAP_SIZE, 0:MAP_SIZE]
    world_x = xs / SCALE - WORLD_SIZE / 2
    world_z = ys / SCALE - WORLD_SIZE / 2
    shore = world_x + 12 * np.sin(world_z * 0.045) + 6 * np.sin(world_z * 0.13 + 1) - 70
    shore_blend = smooth(-22, -8, shore + (blotches(40, 6) - 0.5) * 14)
    field = field * (1 - shore_blend) + sand * shore_blend

    track_mask = mask(lambda d: tracks(d, 70), 1.2) * smooth(0.25, 0.7, blotches(160))
    field *= 1 - track_mask * 0.5

    asphalt = tiled("aerial_asphalt_01", 800) * 0.75 + 0.02
    concrete = tiled("concrete_floor_02", 620) * 0.5 + 0.17
    concrete *= 0.8 + 0.4 * blotches(30, 14)

    shoulder = mask(lambda d: road_shape(d, 2.4), 9)
    field *= 1 - shoulder * 0.28
    noise_edge = (blotches(240) - 0.5) * 0.5
    road = smooth(0.42, 0.56, mask(road_shape, 4) + noise_edge)
    field = field * (1 - road) + asphalt * road

    def dashes(draw):
        for z in range(-120, 120, 8):
            draw.rectangle([px(ROAD_V_X - 0.14), px(z), px(ROAD_V_X + 0.14), px(z + 3.6)], fill=255)
        for x in range(-120, int(ROAD_V_X) - 6, 8):
            draw.rectangle([px(x), px(ROAD_H_Z - 0.14), px(x + 3.6), px(ROAD_H_Z + 0.14)], fill=255)

    paint = mask(dashes, 1) * smooth(0.3, 0.6, blotches(90))
    field = field * (1 - paint * 0.75) + paint * 0.75 * 0.9

    x0, z0, x1, z1 = PAD
    pad = mask(lambda d: d.rectangle([px(x0), px(z0), px(x1), px(z1)], fill=255), 2)

    def seams(draw):
        for x in np.arange(x0, x1, 6.0):
            draw.line([px(x), px(z0), px(x), px(z1)], fill=255, width=3)
        for z in np.arange(z0, z1, 6.0):
            draw.line([px(x0), px(z), px(x1), px(z)], fill=255, width=3)

    def stripes(draw):
        for z in np.arange(z0 + 3, z1 - 2, 3.6):
            draw.rectangle([px(x1 - 7.5), px(z), px(x1 - 1.2), px(z + 1.5)], fill=255)
        draw.rectangle([px(x0 + 1), px(z0 + 1), px(x1 - 1), px(z1 - 1)], outline=255, width=9)

    field = field * (1 - pad) + concrete * pad
    field *= 1 - mask(seams, 0.8) * 0.4
    worn = smooth(0.3, 0.62, blotches(120))
    painted = mask(stripes, 1) * worn
    field = field * (1 - painted * 0.8) + painted * 0.8 * 0.92

    field *= scorch_marks()
    specks = debris()
    field *= 1 - specks * 0.68

    field = np.clip(field, 0, 1)
    Image.fromarray((field * 255).astype(np.uint8)).save(OUT / "ground_map.jpg", quality=86)


def build_camo():
    size = 1024
    base = np.asarray(grey("rusty_metal_02_diff", size), dtype=np.float32) / 255
    pattern = np.zeros((size, size), dtype=np.float32)
    rng = np.random.default_rng(9)
    layers = []
    for cells in (5, 9):
        tile = rng.random((cells, cells))
        wrapped = Image.fromarray((np.block([[tile, tile], [tile, tile]]) * 255).astype(np.uint8))
        big = wrapped.resize((size * 2, size * 2), Image.BICUBIC).filter(ImageFilter.GaussianBlur(14))
        layers.append(np.asarray(big, dtype=np.float32)[size // 2:size // 2 + size, size // 2:size // 2 + size] / 255)
    field = layers[0] * 0.7 + layers[1] * 0.3
    low, high = np.quantile(field, [0.36, 0.7])
    pattern[field < low] = 0.2
    pattern[(field >= low) & (field < high)] = 0.46
    pattern[field >= high] = 0.72
    pattern = np.asarray(Image.fromarray((pattern * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255
    camo = pattern * (0.7 + 0.6 * base)
    Image.fromarray((np.clip(camo, 0, 1) * 255).astype(np.uint8)).save(OUT / "camo.jpg", quality=88)


def build_frond():
    width, height = 256, 1024
    image = Image.new("LA", (width, height), (0, 0))
    draw = ImageDraw.Draw(image)
    center = width / 2
    draw.line([(center, height), (center, 8)], fill=(70, 255), width=9)
    for y in range(height - 20, 20, -11):
        t = 1 - y / height
        length = (center - 8) * math.sin(math.pi * min(1.0, t * 0.92 + 0.06)) ** 0.7
        droop = 90 * t + 30
        for side in (-1, 1):
            tip = (center + side * length * random.uniform(0.82, 1.0), y + droop * 0.32 * random.uniform(0.8, 1.2))
            shade = random.randint(95, 175)
            draw.polygon([(center, y - 5), tip, (center, y + 5)], fill=(shade, 255))
    image.save(OUT / "palm_frond.png")


def build_smoke_puffs():
    """A 4 x 4 sheet of billowy puffs, lit from the sun's side of the sky."""
    frame = 256
    sheet = Image.new("LA", (frame * 4, frame * 4))
    ys, xs = np.mgrid[0:frame, 0:frame]
    radius = np.hypot(xs - frame / 2, ys - frame / 2) / (frame / 2)
    for index in range(16):
        noise = np.zeros((frame, frame), dtype=np.float32)
        for cells, weight in [(4, 0.5), (8, 0.26), (16, 0.15), (32, 0.09)]:
            layer = Image.fromarray((np.random.rand(cells, cells) * 255).astype(np.uint8))
            noise += np.asarray(layer.resize((frame, frame), Image.BICUBIC), dtype=np.float32) / 255 * weight
        edge = smooth(0.12, 0.42, noise * 1.2 - radius * 0.5 + 0.14) * (1 - smooth(0.72, 0.98, radius))
        height = np.asarray(Image.fromarray((noise * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5)), dtype=np.float32) / 255
        slope_x, slope_y = np.gradient(height)
        light = np.clip(0.72 + (slope_x - slope_y) * 11, 0.3, 1)
        pixels = np.stack([(light * 255).astype(np.uint8), (edge * 255).astype(np.uint8)], axis=2)
        sheet.paste(Image.fromarray(pixels, "LA"), ((index % 4) * frame, (index // 4) * frame))
    sheet.save(OUT / "smoke_puffs.png")


def build_craters():
    """Three shell craters: colour with alpha, plus a normal map for the bowl and rim."""
    size = 1024
    ys, xs = np.mgrid[0:size, 0:size]
    dx, dy = (xs - size / 2) / (size / 2), (ys - size / 2) / (size / 2)
    angle = np.arctan2(dy, dx)
    radius = np.hypot(dx, dy)

    def octaves(pairs):
        total = np.zeros((size, size), dtype=np.float32)
        for cells, weight in pairs:
            layer = Image.fromarray((np.random.rand(cells, cells) * 255).astype(np.uint8))
            total += np.asarray(layer.resize((size, size), Image.BICUBIC), dtype=np.float32) / 255 * weight
        return total

    for variant in range(3):
        coarse = octaves([(10, 0.5), (24, 0.3), (60, 0.2)])
        fine = octaves([(120, 0.5), (260, 0.3), (520, 0.2)])
        rays = sum(np.sin(angle * f + random.uniform(0, 6)) * a for f, a in [(3, 0.12), (7, 0.15), (13, 0.13), (29, 0.1), (53, 0.07)])
        warped = radius * (1 + rays * 0.8) + (coarse - 0.5) * 0.3

        scorch = 1 - smooth(0.2, 0.86, warped + (fine - 0.5) * 0.4)
        bowl = np.exp(-(warped / 0.2) ** 2)
        rim = np.exp(-((warped - 0.27) / 0.085) ** 2) * (0.6 + coarse * 0.8)

        specks = Image.new("L", (size, size), 0)
        draw = ImageDraw.Draw(specks)
        for _ in range(1500):
            theta = random.uniform(0, math.tau)
            dist = random.uniform(0.24, 0.98) ** 1.5
            x, y = size / 2 + math.cos(theta) * dist * size / 2, size / 2 + math.sin(theta) * dist * size / 2
            grain = random.choice([1, 1, 2, 2, 3, 4, 6])
            draw.polygon([(x + random.randint(-grain, grain), y + random.randint(-grain, grain)) for _ in range(5)], fill=255)
        specks = np.asarray(specks.filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float32) / 255
        specks *= 1 - smooth(0.88, 1.0, radius)

        shade = 0.05 + 0.11 * fine + 0.2 * rim + 0.08 * bowl * coarse
        shade = shade * (1 - specks * 0.5)
        alpha = np.clip(scorch * (0.72 + 0.5 * fine) + rim * 0.8 + bowl + specks * 0.85, 0, 1)
        alpha *= 1 - smooth(0.84, 0.99, radius)
        channel = (np.clip(shade, 0, 1) * 255).astype(np.uint8)
        rgba = np.stack([channel, channel, channel, (alpha * 255).astype(np.uint8)], axis=2)
        Image.fromarray(rgba, "RGBA").save(OUT / f"crater_{variant}.png")

        height = rim * 0.65 - bowl * 1.3 + (fine - 0.5) * 0.14 + specks * 0.1
        height = np.asarray(Image.fromarray(((height + 1.5) / 3 * 255).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2)), dtype=np.float32) / 255
        slope_y, slope_x = np.gradient(height)
        strength = 34
        normal = np.stack([-slope_x * strength, slope_y * strength, np.ones_like(height)], axis=2)
        normal /= np.linalg.norm(normal, axis=2, keepdims=True)
        normal_pixels = ((normal * 0.5 + 0.5) * 255).astype(np.uint8)
        Image.fromarray(normal_pixels, "RGB").save(OUT / f"crater_{variant}_normal.png")


def build_contact_shadow():
    """A soft dark rectangle that grounds whatever stands on it."""
    size = 256
    ys, xs = np.mgrid[0:size, 0:size]
    edge = np.minimum.reduce([xs, ys, size - 1 - xs, size - 1 - ys]) / (size / 2)
    alpha = (smooth(0.0, 0.34, edge) * 215).astype(np.uint8)
    zero = np.zeros_like(alpha)
    Image.fromarray(np.stack([zero, zero, zero, alpha], axis=2), "RGBA").save(OUT / "contact_shadow.png")


def copy_maps():
    for name, target, size in [
        ("dry_ground_rocks_diff", "detail_ground.jpg", 1024),
        ("container_side_diff", "container.jpg", 1024),
        ("corrugated_iron_diff", "corrugated.jpg", 1024),
        ("concrete_floor_02_diff", "concrete.jpg", 1024),
        ("weathered_planks_diff", "planks.jpg", 1024),
    ]:
        grey(name, size).save(OUT / target, quality=86)
    for name, target, size in [
        ("dry_ground_rocks_nor_gl", "detail_ground_normal.jpg", 1024),
        ("rusty_metal_02_nor_gl", "metal_normal.jpg", 1024),
        ("corrugated_iron_nor_gl", "corrugated_normal.jpg", 1024),
        ("container_side_nor_gl", "container_normal.jpg", 1024),
    ]:
        Image.open(SOURCE / f"{name}.jpg").convert("RGB").resize((size, size), Image.LANCZOS).save(OUT / target, quality=90)


build_ground()
build_camo()
build_frond()
build_smoke_puffs()
build_craters()
build_contact_shadow()
copy_maps()
