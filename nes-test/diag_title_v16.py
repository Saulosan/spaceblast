#!/usr/bin/env python3
"""Diagnostico v2: simula o title_screen do .bas com attrs REAIS (so as linhas
do title_screen) + patterns sequenciais do CHRROM 0. Compara com o PNG."""
import re
from PIL import Image, ImageDraw

BAS = "/home/user/spaceblast/space-blast.bas"
PNG = "/home/user/uploads/title-space.png"
OUT = "/home/user/spaceblast/docs/title_attr_diag.png"

src = open(BAS).read().splitlines()

# ---- patterns do CHRROM 0 (bitmaps sequenciais incrementam o padrao) ----
patterns = {}
cur = None
in_chr0 = False
for ln in src:
    s = ln.strip()
    m = re.match(r"CHRROM (\d+)", s)
    if m:
        in_chr0 = (int(m.group(1)) == 0)
        cur = None
        continue
    if not in_chr0:
        continue
    m = re.match(r"CHRROM PATTERN (\d+)", s)
    if m:
        cur = int(m.group(1)); rows = 0
        continue
    m = re.match(r'BITMAP "([.0123]{8})"', s)
    if m and cur is not None:
        patterns.setdefault(cur, []).append([0 if c == "." else int(c) for c in m.group(1)])
        if len(patterns[cur]) == 8:
            cur += 1
print("patterns CHRROM0:", min(patterns), "..", max(patterns), "total", len(patterns))

# ---- logo_map ----
lm = next(i for i, ln in enumerate(src) if ln.strip() == "logo_map:")
logo_map = []
for ln in src[lm + 1:]:
    m = re.match(r"\s*DATA BYTE (.*)", ln)
    if not m: break
    logo_map += [int(v.strip()) for v in m.group(1).split(",")]
print("logo_map:", len(logo_map), "usados:", sorted(set(e for e in logo_map if e != 255))[:8], "...")

# ---- attrs SOMENTE do title_screen (entre 'title_screen:' e 'title_wait:') ----
a0 = next(i for i, ln in enumerate(src) if ln.strip() == "title_screen:")
a1 = next(i for i, ln in enumerate(src) if ln.strip().startswith("title_wait:"))
attr = {}
for ln in src[a0:a1]:
    m = re.match(r"\s*VPOKE \$(23[0-9A-F]{2}),\$([0-9A-F]{2})", ln)
    if m:
        addr = int(m.group(1), 16)
        if 0x23C0 <= addr < 0x2400:
            attr[addr] = int(m.group(2), 16)
print("attrs title_screen:", {hex(k): hex(v) for k, v in sorted(attr.items())})

pals = [[0x0F,0x11,0x21,0x00],[0x0F,0x00,0x10,0x30],[0x0F,0x06,0x16,0x30],[0x0F,0x1C,0x10,0x30]]
NES_RGB = {0x0F:(10,10,10),0x30:(255,255,255),0x10:(160,160,160),0x00:(98,98,98),
           0x1C:(10,124,138),0x06:(152,3,3),0x16:(222,0,0),0x11:(30,30,180),0x21:(110,110,255)}

def pal_at(tx, ty, table):
    addr = 0x23C0 + (ty // 4) * 8 + (tx // 4)
    v = table.get(addr, 0)
    sq = ((tx % 4) // 2) + ((ty % 4) // 2) * 2   # 0=TL 1=TR 2=BL 3=BR
    return (v >> (sq * 2)) & 3

def render(table):
    sim = Image.new("RGB", (128, 48), (10, 10, 10))
    for i in range(96):
        e = logo_map[i]
        if e == 255: continue
        gx, gy = (i % 16) + 8, (i // 16) + 6
        pal = pals[pal_at(gx, gy, table)]
        pat = patterns.get(e)
        if pat is None:
            print("padrao ausente:", e); continue
        for y in range(8):
            for x in range(8):
                sim.putpixel(((i % 16) * 8 + x, (i // 16) * 8 + y), NES_RGB[pal[pat[y][x]]])
    return sim

def unswap(table):
    """troca nibbles TR<->BL de cada byte (teste da hipotese de empacotamento errado)"""
    out = {}
    for a, v in table.items():
        TL = v & 3; TR = (v >> 2) & 3; BL = (v >> 4) & 3; BR = (v >> 6) & 3
        out[a] = TL | (BL << 2) | (TR << 4) | (BR << 6)
    return out

im = Image.open(PNG).convert("RGB")
simA = render(attr)          # o que o ROM faz hoje
simB = render(unswap(attr))  # hipotese: nibble swap no empacotamento do attr

Z = 5
pw, ph = 128 * Z, 48 * Z
img = Image.new("RGB", (pw * 2 + 40, ph * 2 + 150), (24, 24, 28))
d = ImageDraw.Draw(img)
def panel(src_im, ox, oy, title, label_quads=None):
    img.paste(src_im.resize((pw, ph), Image.NEAREST), (ox, oy))
    for gx in range(9):
        x = ox + gx * 16 * Z
        d.line([(x, oy), (x, oy + ph)], fill=(180, 40, 40), width=1)
    for gy in range(4):
        y = oy + gy * 16 * Z
        d.line([(ox, y), (ox + pw, y)], fill=(180, 40, 40), width=1)
    d.text((ox, oy - 14), title, fill=(255, 255, 255))
    if label_quads:
        for qy in range(3):
            for qx in range(8):
                p = pal_at(qx * 2 + 8, qy * 2 + 6, attr)
                d.text((ox + qx * 16 * Z + 3, oy + qy * 16 * Z + 3), str(p), fill=(255, 220, 60))
panel(im, 10, 60, "REFERENCIA (sua arte)")
panel(simA, 10 + pw + 20, 60, "SIMULACAO do ROM v0.16 (amarelo = paleta recebida por quad)", label_quads=True)
panel(simB, 10, 60 + ph + 44, "TESTE: se trocarmos os nibbles TR/BL de cada byte de atributo")
img.save(OUT)

# tabela texto: paleta entregue por quad (tile-global row 6-11, col 8-23)
print("\nquad (qx,qy) logo-local -> paleta NES aplicada hoje:")
for qy in range(3):
    row = []
    for qx in range(8):
        row.append(str(pal_at(qx * 2 + 8, qy * 2 + 6, attr)))
    print(f"  linha {qy}: " + " ".join(row))
print("salvo:", OUT)
