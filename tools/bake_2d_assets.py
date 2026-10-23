#!/usr/bin/env python3
"""Original placeholder art. Never copies the supplied reference images."""
from pathlib import Path
import random, math
root=Path(__file__).resolve().parents[1]/'assets/illustrated';root.mkdir(exist_ok=True)
r=random.Random(4618)
s=['<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="800" viewBox="0 0 1280 800">','<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#b9d9e7"/><stop offset="1" stop-color="#f8ecda"/></linearGradient><linearGradient id="grass" x2="0" y2="1"><stop stop-color="#c4d3ae"/><stop offset="1" stop-color="#9cba91"/></linearGradient><radialGradient id="pink" cx=".35" cy=".25" r=".8"><stop stop-color="#fff3f4"/><stop offset=".65" stop-color="#f0cddd"/><stop offset="1" stop-color="#cea8c5"/></radialGradient></defs>','<rect width="1280" height="800" fill="url(#sky)"/>','<path d="M0 400 Q160 330 300 400 Q460 310 620 390 Q820 325 1000 385 Q1120 330 1280 380 V800 H0Z" fill="#b9cfbd"/>','<path d="M0 465 Q320 430 650 460 T1280 440 V800 H0Z" fill="url(#grass)"/>','<path d="M700 445 Q460 500 480 585 Q485 650 820 800 H180 Q100 640 310 540 Q425 480 700 445Z" fill="#ddd0bc"/>']
for x,y,k in [(155,440,1.1),(1110,438,1.15),(370,453,.68),(925,456,.65),(660,451,.45)]:
 s.append(f'<g transform="translate({x} {y}) scale({k})"><path d="M-18 0 Q-35 -140 -3 -220 Q12 -270 10 -310 M-8 -185 Q-90 -220 -110 -300 M0 -225 Q75 -230 112 -315" fill="none" stroke="#7b646e" stroke-width="24" stroke-linecap="round"/>')
 for j in range(18):
  cx=r.uniform(-150,150);cy=r.uniform(-350,-240);radius=r.uniform(38,75)
  s.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{radius:.1f}" fill="url(#pink)"/>')
 for j in range(400):
  px=r.uniform(-185,185);py=r.uniform(-390,-210)
  if ((px/185)**2+((py+300)/95)**2)>1:continue
  tone=r.choice(['#fff2f3','#f7dce9','#eabdd5'])
  s.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{r.uniform(2,5):.1f}" fill="{tone}"/>')
 s.append('</g>')
for _ in range(450):
 x=r.randrange(1280);y=r.randrange(475,800)
 s.append(f'<path d="M{x} {y} l3 -4 m-3 4 l-2 -3" stroke="#b0c79d" stroke-width="1.4" opacity=".7"/>')
s+=['<g fill="#a98c7a" stroke="#806e65" stroke-width="5"><path d="M110 523H290V572H110Z"/><path d="M100 582H300V600H100Z"/><path d="M120 598V638M280 598V638"/><path d="M110 546H290"/></g>','</svg>']
(root/'original_garden.svg').write_text('\n'.join(s))
(root/'shadow.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="64"><defs><radialGradient id="s"><stop stop-color="#353343" stop-opacity=".27"/><stop offset=".65" stop-color="#353343" stop-opacity=".10"/><stop offset="1" stop-color="#353343" stop-opacity="0"/></radialGradient></defs><ellipse cx="128" cy="32" rx="126" ry="30" fill="url(#s)"/></svg>')
(root/'petal.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><path d="M15 29C-7 13 11-3 16 6C23-6 39 12 15 29" fill="#f1c8dc"/><path d="M16 7Q11 16 15 27" fill="none" stroke="#ffe9f2" stroke-width="2"/></svg>')
s=['<svg xmlns="http://www.w3.org/2000/svg" width="400" height="250">','<path d="M-20 0Q110 8 215 115M70 19Q190 3 330 50M148 65Q170 142 285 181" fill="none" stroke="#826a7d" stroke-width="7" stroke-linecap="round"/>']
for _ in range(80):
 x=r.uniform(20,340);y=40+(x/340)*85+r.uniform(-30,60)
 s.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{r.uniform(4,10):.1f}" ry="{r.uniform(3,7):.1f}" fill="{r.choice(["#f8dbea","#eed0e3","#e7b7d2"])}"/>')
s.append('</svg>');(root/'branch.svg').write_text('\n'.join(s))
