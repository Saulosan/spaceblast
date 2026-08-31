#!/usr/bin/env python3
# SPACE BLAST v0.16: logo da Falcon Soft (splash) -> CHRROM 1 (CHRRAM pagina 1)
# Entrada : ../uploads/Falconsoft-montado.png (128x78, preto/cinza/branco)
# Saida   : falcon_chr.bas.inc (fragmento p/ patch)
#           + preview p/ conferencia visual
import os
import re
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
UPLOADS = Path(os.environ.get('SPACEBLAST_UPLOADS', HERE.parent / 'uploads'))
UP  = UPLOADS / 'Falconsoft-montado.png'
OUT = HERE / 'falcon_chr.bas.inc'
PREV = HERE / 'docs' / 'falcon_chr_preview.png'

def norm(a):
    out = np.zeros_like(a, dtype=np.uint8)
    out[a >= 100] = 2     # cinza
    out[a >= 200] = 3     # branco
    return out

mon = norm(np.array(Image.open(UP).convert('L'), dtype=np.uint8))
full = np.zeros((80, 128), dtype=np.uint8)
full[:mon.shape[0], :] = mon            # pad p/ 128x80 (16x10 cells)

# extrai tiles unicos preservando ordem de aparecimento
tiles, where = [], {}
cellmap = []
for cell in range(160):
    col, row = cell % 16, cell // 16
    t = full[row*8:(row+1)*8, col*8:(col+1)*8]
    key = t.tobytes()
    if key not in where:
        where[key] = len(tiles)
        tiles.append(t)
    cellmap.append(where[key] + 96)     # patterns a partir de 96
NT = len(tiles)
print("tiles unicos:", NT, "-> patterns", 96, "a", 96+NT-1)

# fonte CVBasic (cvbasic.c) p/ 'apresenta' (8x8, plano duplo = idx 3)
cfont_path = Path(os.environ.get('CVBASIC_SRC', HERE.parent / 'cvbasic-repo')) / 'cvbasic.c'
cfont = cfont_path.read_text(encoding='utf-8')
m = re.search(r'unsigned char font\[\] = \{(.*?)\};', cfont, re.S)
corpo = re.sub(r'//[^\n]*', '', m.group(1))   # remove comentarios inline
bytes_font = [int(v, 16) for v in re.findall(r'0x([0-9a-fA-F]{2})', corpo)]
print("font bytes:", len(bytes_font), "->", len(bytes_font)//8, "glifos")
LETRAS = "apresenta"
glifos = {}
for ch in sorted(set(LETRAS)):
    base = (ord(ch) - 32) * 8
    g = bytes_font[base:base+8]
    glifos[ch] = g
    print(f"  '{ch}' (tile {ord(ch)}):", [hex(b) for b in g])

# tiles das letras: patterns apos a logo
let_pat = {}
np_ = 96 + NT
for ch in sorted(set(LETRAS)):
    let_pat[ch] = np_; np_ += 1
print("letras em:", let_pat)
txt_tiles = [let_pat[ch] for ch in LETRAS]

def bm(t):
    return [f'\tBITMAP "{"".join("." if v==0 else str(v) for v in row)}"' for row in t]

def bm_font(g):
    return [f'\tBITMAP "{"".join("3" if (b >> (7-x)) & 1 else "." for x in range(8))}"' for b in g]

lines = []
lines.append("\t' ---- LOGO FALCON SOFT (v0.16) ----")
lines.append("\t' splash inicial: CHRROM 1 = CHRRAM pagina 1 (POKE $1C,$20)")
lines.append("\t' cinza=idx2 branco=idx3; fade por palette cycling ($3F02/$3F03)")
lines.append("\tCHRROM 1")
lines.append(f"\tCHRROM PATTERN 96\n")
for t in tiles:
    lines += bm(t) + ['']
for ch in sorted(set(LETRAS)):
    lines.append(f"\t' letra '{ch}' (fonte CVBasic) p/ \"apresenta\"")
    lines.append(f"\tCHRROM PATTERN {let_pat[ch]}")
    lines += bm_font(glifos[ch]) + ['']
open(OUT, 'w').write('\n'.join(lines))

# mapa da nametable (160 cells; 0 = vazio)
vals = []
for v in cellmap:
    vals.append(v)
mp = "falcon_map:\n" + '\n'.join(
    '\tDATA BYTE ' + ','.join(str(v) for v in vals[i:i+16]) for i in range(0, 160, 16))
open(OUT, 'a').write('\n\n' + mp + '\n\n' +
    "falcon_txt:\n\tDATA BYTE " + ','.join(str(v) for v in txt_tiles) + "\n")

# preview: renderiza como ficaria (cinza $10, branco $30 aprox)
vis = np.zeros((80,128,3), dtype=np.uint8)
vis[full==2] = (100,100,100)
vis[full==3] = (236,236,236)
Image.fromarray(vis).resize((128*5,80*5), Image.NEAREST).save(PREV)
print("fragmento:", OUT, "| preview:", PREV)
EOF_MARKER = None
