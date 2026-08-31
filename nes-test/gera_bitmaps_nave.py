#!/usr/bin/env python3
"""Gera os BITMAPs da nave 16x16 em camadas p/ cata-estrelas.bas (variante A16).
Slots (11): idle 0-4, transicao 5-6, loop segurando 10-13.
Cada slot = 4 metades 8x16: corpoE, corpoD, canopy (azul/verm), chama (verde).
Tile inicial: 276  ->  f = 21 + slot*8 + metade*2
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from mock_nave import NES, nearest_idx, im
from mock_nave3 import classifica, PAL_CINZA, PAL_CANOPY, PAL_CHAMA

SLOTS = [0, 1, 2, 3, 4, 5, 6, 10, 11, 12, 13]

def metade(px, x0, classes, pal):
    """16 linhas x 8 colunas -> chars .123 (0 = transparente)"""
    linhas = []
    for y in range(16):
        s = ''
        for x in range(8):
            c = px[x0 + x, y]
            if c[3] < 128 or classifica(c) not in classes:
                s += '.'
            else:
                s += str(nearest_idx(c, pal) + 1)
        linhas.append(s)
    return linhas

def frame16(fi):
    return im.crop((fi*32+4, 0, fi*32+28, 30)).resize((16, 16), __import__('PIL.Image', fromlist=['Image']).NEAREST)

out = []
out.append("\t'")
out.append("\t' Nave do jogador (16x16, 4 sprites em camadas):")
out.append("\t'   corpoE (pal 0) / corpoD (pal 0) / canopy (pal 1) / chama (pal 2)")
out.append("\t'   11 slots de animacao, metade 8x16 cada: f = 21 + slot*8 + metade*2")
out.append("\t'   slots 0-4 = idle, 5-6 = transicao esq, 7-10 = segurando esq (orig 10-13)")
out.append("\t'   (lado direito = mesmo desenho com H-FLIP, atributo +$40)")
out.append("\t'")
out.append("\tCHRROM PATTERN 276")

for si, fi in enumerate(SLOTS):
    px = frame16(fi).load()
    partes = [
        ("corpoE", 0, ('neutro', 'azul', 'vermelho', 'verde'), PAL_CINZA),
        ("corpoD", 8, ('neutro', 'azul', 'vermelho', 'verde'), PAL_CINZA),
        ("canopy", 4, ('azul', 'vermelho'), PAL_CANOPY),
        ("chama ", 4, ('verde',), PAL_CHAMA),
    ]
    out.append("\t' slot %d = frame original %d" % (si, fi))
    for nome, x0, classes, pal in partes:
        linhas = metade(px, x0, classes, pal)
        out.append("\t' %s f=%d" % (nome, 21 + si*8 + partes.index((nome, x0, classes, pal))*2))
        for s in linhas:
            out.append('\tBITMAP "%s"' % s)

with (HERE / 'nave_bitmaps.txt').open('w', encoding='utf-8') as f:
    f.write('\n'.join(out) + '\n')
print('linhas:', len(out), '= %d bitmaps' % (len(SLOTS)*4))
