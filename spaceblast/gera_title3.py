#!/usr/bin/env python3
"""SPACE BLAST v0.16b: regenera a logo do titulo SEM as estrelas decorativas
(sao tiles para o cenario, nao parte da logo) e grava os atributos com o
MAPA DO SAULO na ordem correta de nibble NES (TL|TR<<2|BL<<4|BR<<6).

Mapa de paletas por quad 16x16 (logo-local, 8x3 quads):
  linha 0:  3 1 1 1 1 3 3 3    (SPACE cinzas pal1 / cometa pal3)
  linha 1:  3 2 2 2 2 2 2 3    (BLAST vermelhos pal2 / laterais pal3)
  linha 2:  3 2 2 2 2 2 2 3
Bits extra: corrige $23ED (RT cinza) e mantem bullet 212 / boss 213-251 intactos.
"""
import os
import re
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
UPLOADS = Path(os.environ.get('SPACEBLAST_UPLOADS', HERE.parent / 'uploads'))
BAS = HERE / 'space-blast.bas'
PNG = UPLOADS / 'title-space.png'
PREV = HERE / 'docs' / 'title_v16b_preview.png'

# ---------- 1) classificacao de pixels (6 cores exatas) ----------
def cls(px):
    r, g, b, *_ = px
    mx, mn = max(r, g, b), min(r, g, b)
    if mx < 60: return "K"
    if mn > 220: return "W"
    if mx - mn < 20 and 120 < (r + g + b) // 3 < 200: return "g"
    if b > 100 and g > 80 and r < 60: return "T"
    if r > 180 and g < 60: return "R"
    if 100 < r < 180 and g < 40: return "d"
    return "?"

PAL_RGB = {0: (34, 34, 34), 1: (10, 124, 138), 2: (158, 158, 158), 3: (255, 255, 255)}

# indice por classe em cada paleta (garante a cor certa por design)
# pal1 = $0F,$00,$10,$30 (cinzas SPACE)  pal2 = $0F,$06,$16,$30 (vermelhos)  pal3 = $0F,$1C,$10,$30 (cometa)
CLASS2IDX = {1: {"K": 0, "g": 2, "W": 3},
             2: {"K": 0, "d": 1, "R": 2, "W": 3},
             3: {"K": 0, "T": 1, "g": 2, "W": 3}}
QUADPAL = [[3, 1, 1, 1, 1, 3, 3, 3],
           [3, 2, 2, 2, 2, 2, 2, 3],
           [3, 2, 2, 2, 2, 2, 2, 3]]

im = Image.open(PNG).convert("RGB")
W, H = im.size
pix = im.load()
classes = sorted({cls(pix[x, y]) for y in range(H) for x in range(W)})
print("classes distintas na folha:", classes)
assert set(classes) <= set("KWgTRd"), f"cor fora do esperado: {classes}"

# ---------- 2) componentes conexos: ARTE vs BRILHO ----------
seen = [[False] * W for _ in range(H)]
comps = []
for y in range(H):
    for x in range(W):
        if seen[y][x] or cls(pix[x, y]) == "K": continue
        st = [(x, y)]; seen[y][x] = True; pts = []
        while st:
            a, b = st.pop(); pts.append((a, b))
            for da in (-1, 0, 1):
                for db in (-1, 0, 1):
                    na, nb = a + da, b + db
                    if 0 <= na < W and 0 <= nb < H and not seen[nb][na] and cls(pix[na, nb]) != "K":
                        seen[nb][na] = True; st.append((na, nb))
        comps.append(pts)
print(f"componentes: {len(comps)}")

big = []
for pts in comps:
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    cs = [cls(pix[p[0], p[1]]) for p in pts]
    box = (min(xs), min(ys), max(xs), max(ys))
    big.append((len(pts), box, set(cs)))

arte_boxes = [b for sz, b, cs in big if sz >= 24]
drop = []
for i, (sz, box, cs) in enumerate(big):
    if sz >= 24: continue
    cx = (box[0] + box[2]) / 2; cy = (box[1] + box[3]) / 2
    comet_zone = cx >= 80 and cy < 16              # poeira da cauda do cometa
    letter_bit = any(box[2] >= ab[0] - 1 and box[0] <= ab[2] + 1 and box[3] >= ab[1] and box[1] <= ab[3]
                     for ab in arte_boxes)          # pedaco de letra (ex.: ponto do '!')
    if comet_zone or letter_bit: continue
    drop.append((box, sz, sorted(cs)))
print(f"descartados (brilhos/estrelas): {len(drop)}")
for box, sz, cs in drop:
    print(f"   - bbox={box} size={sz} cores={cs}")

drop_px = set()
for box, sz, cs in drop:
    x0, y0, x1, y1 = box
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if cls(pix[x, y]) != "K" and any(p == (x, y) for p in []):
                pass
# marca drop por componente (re-id pelo bbox)
seen2 = [[False] * W for _ in range(H)]
remaining = Image.new("RGB", (W, H), (34, 34, 34))
rp = remaining.load()
kept = 0
for y in range(H):
    for x in range(W):
        if seen2[y][x] or cls(pix[x, y]) == "K": continue
        st = [(x, y)]; seen2[y][x] = True; pts = []
        while st:
            a, b = st.pop(); pts.append((a, b))
            for da in (-1, 0, 1):
                for db in (-1, 0, 1):
                    na, nb = a + da, b + db
                    if 0 <= na < W and 0 <= nb < H and not seen2[nb][na] and cls(pix[na, nb]) != "K":
                        seen2[nb][na] = True; st.append((na, nb))
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        box = (min(xs), min(ys), max(xs), max(ys))
        sz = len(pts); cs = {cls(pix[p[0], p[1]]) for p in pts}
        cx = (box[0] + box[2]) / 2; cy = (box[1] + box[3]) / 2
        keep = sz >= 24 or (cx >= 80 and cy < 16) or any(
            box[2] >= ab[0] - 1 and box[0] <= ab[2] + 1 and box[3] >= ab[1] and box[1] <= ab[3] for ab in arte_boxes)
        if keep:
            kept += 1
            for a, b in pts:
                c = cls(pix[a, b])
                rp[a, b] = {"K": (34, 34, 34), "T": (10, 124, 138), "g": (158, 158, 158),
                            "W": (255, 255, 255), "d": (152, 3, 3), "R": (222, 0, 0)}[c]
print(f"componentes mantidos (arte): {kept}")

# ---------- 3) extrai tiles 8x8 da imagem limpa ----------
tiles = []           # lista de 8x8 indices
tindex = {}          # chave -> pattern
cellmap = []
for i in range(96):
    tx, ty = i % 16, i // 16
    qx, qy = tx // 2, ty // 2
    pal = QUADPAL[qy][qx]
    c2i = CLASS2IDX[pal]
    tile = [[0] * 8 for _ in range(8)]
    empty = True
    for y in range(8):
        for x in range(8):
            px = rp[tx * 8 + x, ty * 8 + y]
            if max(px) > 60:
                empty = False
            tile[y][x] = c2i[cls((px[0], px[1], px[2]))] if max(px) > 60 else 0
    if empty:
        cellmap.append(255); continue
    key = tuple(tuple(r) for r in tile)
    if key not in tindex:
        tindex[key] = len(tiles); tiles.append(tile)
    cellmap.append(96 + tindex[key])
NT = len(tiles)
print(f"tiles unicos (sem estrelas): {NT} -> patterns 96..{96 + NT - 1}")
assert NT <= 92, "vazou p/ bullet 212!"

# ---------- 4) validacao: render simulado com atributos novos ----------
pals = [[0x0F,0x11,0x21,0x00],[0x0F,0x00,0x10,0x30],[0x0F,0x06,0x16,0x30],[0x0F,0x1C,0x10,0x30]]
NES_RGB = {0x0F: (10,10,10), 0x30:(255,255,255), 0x10:(160,160,160), 0x00:(98,98,98),
           0x1C:(10,124,138), 0x06:(152,3,3), 0x16:(222,0,0), 0x11:(30,30,180), 0x21:(110,110,255)}
# attrs NES (corretos): rows 4-7 -> $23CA-CD; rows 8-11 -> $23D2-D5
attr = {0x23CA: 0x70, 0x23CB: 0x50, 0x23CC: 0xD0, 0x23CD: 0xF0,
        0x23D2: 0xBB, 0x23D3: 0xAA, 0x23D4: 0xAA, 0x23D5: 0xEE}
for a, v in attr.items():
    TL = v & 3; TR = (v >> 2) & 3; BL = (v >> 4) & 3; BR = (v >> 6) & 3
    row = "4-7" if a < 0x23D0 else "8-11"
    print(f"  ${a:04X} = ${v:02X}  (tile rows {row}: TL={TL} TR={TR} BL={BL} BR={BR})")

def pal_at(tx, ty):
    a = 0x23C0 + (ty // 4) * 8 + (tx // 4)
    v = attr.get(a, 0)
    sq = ((tx % 4) // 2) + ((ty % 4) // 2) * 2
    return (v >> (sq * 2)) & 3

sim = Image.new("RGB", (128, 48), (10, 10, 10))
for i in range(96):
    e = cellmap[i]
    if e == 255: continue
    gx, gy = (i % 16) + 8, (i // 16) + 6
    pal = pals[pal_at(gx, gy)]
    tile = tiles[e - 96]
    for y in range(8):
        for x in range(8):
            sim.putpixel(((i % 16) * 8 + x, (i // 16) * 8 + y), NES_RGB[pal[tile[y][x]]])

Z = 5
pw, ph = 128 * Z, 48 * Z
img = Image.new("RGB", (pw, ph * 2 + 70), (24, 24, 28))
img.paste(im.resize((pw, ph), Image.NEAREST), (0, 20))
img.paste(sim.resize((pw, ph), Image.NEAREST), (0, 20 + ph + 30))
d = ImageDraw.Draw(img)
d.text((4, 4), "REFERENCIA (sua folha, com as estrelas)", fill=(255, 255, 255))
d.text((4, 20 + ph + 14), "COMO O ROM FICA AGORA (sem estrelas na logo, paletas do seu mapa)", fill=(255, 255, 255))
img.save(PREV)
print("preview:", PREV)

# ---------- 5) grava no .bas ----------
src = open(BAS).read()

# 5a) logo_map
mp = "logo_map:\n" + "\n".join(
    "\tDATA BYTE " + ",".join(str(v) for v in cellmap[i:i + 8]) for i in range(0, 96, 8)) + "\n"
src2, n = re.subn(r"logo_map:\n(?:\tDATA BYTE .*\n)+", mp, src, count=1)
assert n == 1, "logo_map nao achado"

# 5b) tiles 96..: substitui os primeiros NT tiles do bloco PATTERN 96 do CHRROM 0.
# O bloco tem 93 tiles (96..188): NT novos (logo) + vazios ate 187 + bullet 188 intacto.
lines = src2.split("\n")
i96 = next(i for i, ln in enumerate(lines) if re.match(r"\s*CHRROM PATTERN 96\s*$", ln))
i268 = next(i for i, ln in enumerate(lines) if re.match(r"\s*CHRROM PATTERN 268\s*$", ln))
# primeiro: descobre o indice do bullet (ultimo tile do bloco, marcado por comentario)
block = lines[i96 + 1:i268]
tile_starts = []
acc = []
for li, ln in enumerate(block):
    if re.match(r'\s*BITMAP "([.0123]{8})"\s*$', ln):
        acc.append(li)
        if len(acc) == 8:
            tile_starts.append(acc[0]); acc = []
NBLK = len(tile_starts)
print(f"tiles no bloco 96..268: {NBLK} (patterns 96..{95 + NBLK})")
bullet_i = NBLK - 1
print(f"bullet = pattern {96 + bullet_i} (ultimo do bloco)")
assert 96 + bullet_i == 188
# reescreve: tiles[0..NT-1] novos, NT..bullet_i-1 vazios, bullet_i preservado
EMPTY = ['\tBITMAP "........"'] * 8
acc = []
ti = -1
out = lines[:i96 + 1]
for ln in block:
    m = re.match(r'\s*BITMAP "([.0123]{8})"\s*$', ln)
    if m:
        acc.append(ln)
        if len(acc) == 8:
            ti += 1
            if ti < NT:
                tile = tiles[ti]
                for r in tile:
                    out.append('\tBITMAP "' + "".join("." if c == 0 else str(c) for c in r) + '"')
            elif ti == bullet_i:
                out.extend(acc)   # bullet preservado bit a bit
            else:
                out.extend(EMPTY)
            acc = []
    else:
        out.append(ln)
out.extend(lines[i268:])
assert ti == NBLK - 1
src2 = "\n".join(out)
print(f"CHRROM 0 reescrito: {NT} tiles logo + {bullet_i - NT} vazios + bullet")

# 5b2) bug v0.16: VPOKE do rodape apontava tile 212 (vazio!); bullet esta em 188
assert "VPOKE $236C,212" in src2
src2 = src2.replace("VPOKE $236C,212", "VPOKE $236C,188", 1)
print("VPOKE rodape: 212 -> 188 (bullet invisivel -> visivel)")

# 5c) atributos (valores corrigidos do mapa do Saulo) + fix RT ($23ED=$A8)
repl = [("$23CA,$44", "$23CA,$70"), ("$23CB,$44", "$23CB,$50"),
        ("$23CC,$C4", "$23CC,$D0"), ("$23CD,$CC", "$23CD,$F0"),
        ("$23D2,$AF", "$23D2,$BB"), ("$23D3,$AA", "$23D3,$AA"),
        ("$23D4,$AA", "$23D4,$AA"), ("$23D5,$FA", "$23D5,$EE"),
        ("$23ED,$88", "$23ED,$A8")]
for old, new in repl:
    if old != new:
        assert f"VPOKE {old}" in src2, f"attr {old} nao achado"
        src2 = src2.replace(f"VPOKE {old}", f"VPOKE {new}", 1)
        print(f"  attr {old} -> {new}")
open(BAS, "w").write(src2)
print("space-blast.bas atualizado!")
