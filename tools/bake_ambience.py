#!/usr/bin/env python3
"""Original quiet synthetic ambience. Standard library; no recordings or downloads."""
import math
from pathlib import Path
import random
import struct
import wave

RATE = 16000
SECONDS = 6
ROOT = Path(__file__).resolve().parents[1] / 'assets/ambience'
ROOT.mkdir(exist_ok=True)
for name in ['wind', 'morning', 'nighttime']:
    rng = random.Random(5182026)
    samples = []
    noise = 0.0
    for i in range(RATE * SECONDS):
        t = i / RATE
        noise = noise * 0.96 + rng.uniform(-1, 1) * 0.04
        value = noise * (0.08 + 0.03 * math.sin(2 * math.pi * t / SECONDS))
        if name == 'morning':
            for start in [0.5, 0.76, 2.6, 2.87, 4.4, 4.7]:
                u = t - start
                if 0 <= u < 0.18:
                    env = math.sin(math.pi * u / 0.18) ** 2
                    value += 0.045 * env * math.sin(2 * math.pi * (2200 * u + 2200 * u * u))
        if name == 'nighttime':
            u = t % 1.5
            if u < 0.45:
                pulse = math.sin(math.pi * min(1, u / 0.45)) ** 2
                value += 0.024 * pulse * max(0, math.sin(2 * math.pi * 22 * u)) * math.sin(2 * math.pi * 3100 * t)
        edge = min(1, t / 0.06, (SECONDS - t) / 0.06)
        samples.append(round(max(-1, min(1, value * edge)) * 32767))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
