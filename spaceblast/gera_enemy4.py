#!/usr/bin/env python3
# Enemy4.gif (32x32, 4 frames) -> tiles NES 16x16 (CHRROM PATTERN 392-395)
# v0.8: SPRITE ESTATICO - so o frame 0 (economiza 12 tiles CHR).
# Cada frame = 16x16 = 2 metades 8x16 (esq = tiles par/impar consecutivos).
# Bits: 1 = corpo (roxo escuro), 2 = asas (ouro), 3 = brilhos (claros/verde).
# Com pal0 (cinzas $00/$10/$30) vira meteoro rochoso: corpo escuro,
# asas medias, brilhos brancos. Trocar de paleta = mudar o attr no SPRITE.
from pathlib import Path
import os
from PIL import Image

HERE = Path(__file__).resolve().parent
SRC = HERE / 'assets' / 'sprites' / 'Enemy4.gif'
OUTDIR = Path(os.environ.get('SPACEBLAST_GENERATED', '/tmp'))
OUTDIR.mkdir(parents=True, exist_ok=True)

def classifica(r, g, b, a):
    if a <= 100:
        return 0
    lum = (r + g + b) / 3.0
    if lum > 175:            # realces claros (ouro claro, lilas claro)
        return 3
    if g > 120 and r < 120:  # luz verde do topo -> brilho
        return 3
    if r > g and g > b:      # familia ouro (asas) -> medio
        return 2
    if b >= r:               # familia roxa (corpo/nucleo) -> escuro
        return 1
    return 2 if lum > 110 else 1

frames = []
im = Image.open(SRC)
im.seek(0)
rgba = im.convert('RGBA').crop((2, 5, 30, 32))   # bbox do conteudo (28x27)
small = rgba.resize((16, 16), Image.LANCZOS)
px = small.load()
frames = [[[classifica(*px[x, y]) for x in range(16)] for y in range(16)]]

# preview (cores aproximadas da pal0)
CH = {0: (10, 10, 10), 1: (108, 108, 108), 2: (190, 190, 190), 3: (255, 255, 255)}
prev = Image.new('RGB', (16, 16), CH[0])
for y in range(16):
    for x in range(16):
        prev.putpixel((x, y), CH[frames[0][y][x]])
prev.resize((128, 128), Image.NEAREST).save(OUTDIR / 'enemy4_nes.png')

# gera bloco CVBasic: PATTERN 392/394, metade esq (2 tiles) + dir (2 tiles)
out = []
PL = {0: '.', 1: '1', 2: '2', 3: '3'}
out.append("\t' Enemy4 (meteoro roxo/ouro do Saulo, frame estatico, 16x16; gera_enemy4.py)\n")
for k, g in enumerate(frames):
    base = 392 + k * 4
    for metade, xo in ((0, 0), (1, 8)):
        # byte OAM (sprite 8x16) = 2T+1 com T = (fis-256)/2 -> TEM que ser impar!
        tspr = base + metade * 2
        out.append("\tCHRROM PATTERN %d\n" % tspr)
        out.append("\t' enemy4 metade%d (byte OAM %d)\n"
                   % (metade, 2 * ((tspr - 256) // 2) + 1))
        for y in range(16):
            out.append('\tBITMAP "' + ''.join(PL[g[y][xo + x]] for x in range(8)) + '"\n')
(OUTDIR / 'enemy4_tiles.bas').write_text(''.join(out))
print(''.join(out))

