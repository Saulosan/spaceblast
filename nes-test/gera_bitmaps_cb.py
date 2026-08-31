#!/usr/bin/env python3
"""Caravan Blast -> NES: gera BITMAPs de small(13,15,18), shard, tiro03, bullet.
Tiles a partir de 364:
  tiro03  364-365   (f 109, 111)        2 fr 8x8
  small   366-377   (f 111+4i, 113+4i)  3 fr 16x16 (direita; esq = H-FLIP)
  shard   378-381   (f 123+i)           4 fr 8x8
  ebullet 382-383   (f 127, 128)        2 fr 8x8
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent
sys.path.insert(0, str(HERE))
from mock_nave import NES, nearest_idx
from PIL import Image
import PIL.ImageSequence as seq

SP = Path(os.environ.get('SPACEBLAST_SPRITES',
                        PROJECT / 'spaceblast' / 'assets' / 'sprites'))
PRETO = (28, 28, 28)   # abaixo disso vira transparente (contorno se dissolve)

def esc(mapa, pal):
    def f(c):
        if all(v < PRETO[0] for v in c[:3]): return 0
        return nearest_idx(c, [i and 0 or p for p in pal]) + 1 if pal[0] == -1 else nearest_idx(c, pal) + 1
    def g(c):
        if all(v < PRETO[0] for v in c[:3]): return 0
        if pal[0] == -1:  # forca paleta reduzida (indices do array completo)
            real = pal[1:]
            return real[nearest_idx(c, real)] > -1 and (pal.index(real[nearest_idx(c, real)]) + 1) or 0
        return nearest_idx(c, pal) + 1
    return g if pal[0] == -1 else f

def bmp(im, x0, y0, w, h, pal, subsample=1):
    q = esc(None, pal)
    linhas = []
    for y in range(0, h, subsample):
        s = ''
        for x in range(0, w, subsample):
            c = im.load()[x0 + x, y0 + y]
            if c[3] < 128:
                s += '.'
            else:
                v = q(c)
                s += '.' if v == 0 else str(v)
        linhas.append(s)
    return linhas

out = []
out.append("\t' ======= CARAVAN BLAST: arte convertida do jogo HTML5 =======")
out.append("\t' tiro03 (tiro do player, 2 fr 8x8) f=109,111 | small (3 fr 16x16)")
out.append("\t' f=111/113,115/117,119/121 (esquerda =H-FLIP) | shard (4 fr 8x8)")
out.append("\t' f=123..126 | tiro inimigo (2 fr 8x8) f=127,128")
out.append("\tCHRROM PATTERN 364")

# tiro03: 2 frames 16x16 -> 8x8 (subsample 2)
im = Image.open(SP / 'tiro-03.gif')
for fi in range(2):
    im.seek(fi)
    t = im.convert('RGBA')
    out.append("\t' tiro03 fr%d f=%d" % (fi, 109 + fi * 2))
    for s in bmp(t, 0, 0, 16, 16, [0x16, 0x27, 0x30], 2):
        out.append('\tBITMAP "%s"' % s)

# small: frames 13, 15, 18 (direita) -> 16x16, duas metades 8x16
im = Image.open(SP / 'Enemy1.png').convert('RGBA')
for i, fr in enumerate([13, 15, 18]):
    for half, x0 in enumerate([0, 8]):
        out.append("\t' small fr%d metade%d f=%d" % (fr, half, 111 + i * 4 + half * 2))
        for s in bmp(im, fr * 32 + x0, 0, 8, 32, None or [0x12, 0x21, 0x16], 2):
            out.append('\tBITMAP "%s"' % s)

# shard: frames 0,2,5,7 -> 8x8 (subsample 4)
im = Image.open(SP / 'Enemy5.gif')
for i, fr in enumerate([0, 2, 5, 7]):
    im.seek(fr)
    t = im.convert('RGBA')
    out.append("\t' shard fr%d f=%d" % (fr, 123 + i))
    for s in bmp(t, 0, 0, 32, 32, [0x19, 0x2A, 0x30], 4):
        out.append('\tBITMAP "%s"' % s)

# bullet inimigo: frames 0,2 -> 8x8 (subsample 1 == 8x8 nativo, paleta forçada [16,30])
im = Image.open(SP / 'bullet.gif')
for i, fr in enumerate([0, 2]):
    im.seek(fr)
    t = im.convert('RGBA')
    out.append("\t' ebullet fr%d f=%d" % (fr, 127 + i))
    for s in bmp(t, 0, 0, 8, 8, [0x16, 0x30], 1):
        out.append('\tBITMAP "%s"' % s)

with (HERE / 'cb_bitmaps.txt').open('w', encoding='utf-8') as f:
    f.write('\n'.join(out) + '\n')
print('linhas:', len(out))
