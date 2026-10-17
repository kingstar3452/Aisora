#!/usr/bin/env python3
"""Bake original SVG art with Python's standard library; Godot imports the SVGs.
No runtime generator/dependency, downloaded assets, or reference-image pixels.
"""
from pathlib import Path
import math
import random

ROOT = Path(__file__).resolve().parents[1] / 'assets/park'
ROOT.mkdir(parents=True, exist_ok=True)
rng = random.Random(31018)
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">',
         '<defs><radialGradient id="pink" cx="40%" cy="24%" r="80%"><stop stop-color="#fff2f2"/><stop offset=".5" stop-color="#f4cbdc"/><stop offset="1" stop-color="#c194b6"/></radialGradient></defs>']
lobes = [(143, 218, 93), (230, 143, 98), (324, 172, 106), (384, 258, 81), (294, 328, 114), (172, 329, 100), (103, 278, 69)]
for x, y, radius in lobes:
    parts.append(f'<circle cx="{x}" cy="{y}" r="{radius}" fill="url(#pink)"/>')
for flower in range(1000):
    cx, cy, radius = rng.choice(lobes)
    angle = rng.random() * math.tau
    distance = (math.sqrt(rng.random()) * .96 if flower < 650 else rng.uniform(.96,1.10)) * radius
    x, y = cx + math.cos(angle) * distance, cy + math.sin(angle) * distance
    size = rng.uniform(4, 9)
    tone = rng.choice(['#fff1f1', '#f8dbe8', '#efc0d6', '#e8b7d1', '#fce6ee'])
    if y > 300 and rng.random() < .55:
        tone = rng.choice(['#dba9c6', '#d6a3c1', '#e9bdd3'])
    for petal in range(5):
        a = petal * math.tau / 5
        px, py = x + math.cos(a) * size * .45, y + math.sin(a) * size * .45
        parts.append(f'<ellipse cx="{px:.1f}" cy="{py:.1f}" rx="{size*.55:.1f}" ry="{size*.42:.1f}" fill="{tone}" transform="rotate({a*180/math.pi:.0f} {px:.1f} {py:.1f})"/>')
    if rng.random() < .25:
        parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="1.1" fill="#d6a2b5"/>')
parts.append('</svg>')
(ROOT / 'blossom_cluster.svg').write_text('\n'.join(parts))
# A low-contrast tile of painted grass marks, not animated geometry.
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256">', '<rect width="256" height="256" fill="#a9c39a"/>']
for _ in range(650):
    x, y = rng.random() * 256, rng.random() * 256
    color = rng.choice(['#b4cc9d', '#a1bb90', '#b9cc9e', '#a7c097', '#b0c49c'])
    parts.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rng.uniform(1,5):.1f}" ry="{rng.uniform(.4,1.4):.1f}" fill="{color}"/>')
parts.append('</svg>')
(ROOT / 'grass_tile.svg').write_text('\n'.join(parts))
print('Baked original park SVG assets.')
