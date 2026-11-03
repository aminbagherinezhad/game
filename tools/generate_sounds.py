"""Synthesises the game's sounds to assets/sounds, so no recordings are needed."""
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 44100
rng = np.random.default_rng(5)


def low_pass(signal, strength):
    result = np.zeros_like(signal)
    level = 0.0
    for i, sample in enumerate(signal):
        level += (sample - level) * strength
        result[i] = level
    return result


def save(signal, name):
    signal = signal / np.max(np.abs(signal)) * 0.9
    with wave.open(str(OUT / name), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes((signal * 32767).astype(np.int16).tobytes())


def autocannon_round():
    """A sharp crack, a falling low thump and a short rumbling tail."""
    t = np.arange(int(RATE * 0.5)) / RATE
    crack = rng.normal(0, 1, t.size) * np.exp(-t * 180)
    pitch = 55 + 95 * np.exp(-t * 28)
    thump = np.sin(2 * np.pi * np.cumsum(pitch) / RATE) * np.exp(-t * 15)
    tail = low_pass(rng.normal(0, 1, t.size), 0.05) * np.exp(-t * 9) * 3.0
    return crack * 0.55 + thump * 1.0 + tail * 0.6


def rocket_launch():
    """A hard ignition, then a roar that thins out as the rocket leaves."""
    t = np.arange(int(RATE * 1.1)) / RATE
    ignition = rng.normal(0, 1, t.size) * np.exp(-t * 60)
    roar = low_pass(rng.normal(0, 1, t.size), 0.16) * np.minimum(t * 30, 1) * np.exp(-t * 3.2) * 2.4
    thump = np.sin(2 * np.pi * np.cumsum(70 + 60 * np.exp(-t * 20)) / RATE) * np.exp(-t * 14)
    return ignition * 0.4 + roar + thump * 0.6


def explosion():
    """A crack, a deep falling boom and a long rumble of settling debris."""
    t = np.arange(int(RATE * 2.4)) / RATE
    crack = rng.normal(0, 1, t.size) * np.exp(-t * 70)
    boom = np.sin(2 * np.pi * np.cumsum(32 + 80 * np.exp(-t * 11)) / RATE) * np.exp(-t * 3.4)
    rumble = low_pass(rng.normal(0, 1, t.size), 0.025) * np.exp(-t * 2.2) * 7.0
    return crack * 0.7 + boom * 1.2 + rumble


save(autocannon_round(), "gun_shot.wav")
save(rocket_launch(), "rocket_launch.wav")
save(explosion(), "explosion.wav")
