#!/usr/bin/env python3
# SPACE BLAST: converte /home/user/uploads/title.png (128x48) p/ tiles NES
# e aplica o patch completo da nova tela de título no caravan-blast.bas.
# Cores: pal1 = ($0F,$1C,$3C,$30) [sombra teal, ciano, branco].
import re
import numpy as np
from PIL import Image

PNG = '/home/user/uploads/title.png'
BAS = '/home/user/caravanblast/caravan-blast.bas'

CORES = [None, (10,124,138), (0,228,255), (255,255,255)]   # idx 1,2,3
im = Image.open(PNG).convert('RGBA')
a = np.array(im).astype(int)
h, w = a.shape[:2]
assert (w, h) == (128, 48), f'PNG deve ser 128x48: {im.size}'

# quantiza: alpha<64 ou preto -> 0; senao mais proxima das cores 1-3
px = a[:, :, :3]
alfa = a[:, :, 3]
d = np.stack([((px - np.array(c))**2).sum(axis=2) for c in CORES[1:]], axis=2)
idx = d.argmin(axis=2) + 1
preto = (alfa < 64) | ((px[:,:,0] < 32) & (px[:,:,1] < 32) & (px[:,:,2] < 32))
idx[preto] = 0

def tile_txt(x0, y0):
    out = []
    for y in range(8):
        linha = ''.join('.' if idx[y0+y, x0+x] == 0 else str(idx[y0+y, x0+x]) for x in range(8))
        out.append(f'\tBITMAP "{linha}"')
    return '\n'.join(out)

tiles96, tiles148, mapa = [], [], []
for cell in range(96):
    col, row = cell % 16, cell // 16
    t = tile_txt(col*8, row*8)
    vazio = '1' not in t and '2' not in t and '3' not in t
    if row < 2:
        tiles96.append(t)
        mapa.append(255 if vazio else 96 + cell)
    else:
        tiles148.append(t)
        mapa.append(255 if vazio else 148 + cell - 32)

sec96  = '\tCHRROM PATTERN 96\n\n'  + '\n\n'.join(tiles96)  + '\n\n'
sec148 = '\tCHRROM PATTERN 148\n\n' + '\n\n'.join(tiles148) + '\n\n'
map_txt = 'logo_map:\n' + '\n'.join('\tDATA BYTE ' + ','.join(str(v) for v in mapa[i:i+8]) for i in range(0, 96, 8))

src = open(BAS).read()

def troca(antigo, novo, contar=1):
    global src
    assert src.count(antigo) >= contar, f'âncora não achada: {antigo[:60]!r}'
    src = src.replace(antigo, novo, contar)

# 1) secoes de tiles da logo
src = re.sub(r'\tCHRROM PATTERN 96\n.*?\tCHRROM PATTERN 148\n', sec96 + '\tCHRROM PATTERN 148\n', src, count=1, flags=re.S)
src = re.sub(r'\tCHRROM PATTERN 148\n.*?\tCHRROM PATTERN 128\n', sec148 + '\tCHRROM PATTERN 128\n', src, count=1, flags=re.S)

# 2) logo_map
src = re.sub(r'logo_map:\n(\tDATA BYTE .*\n)+', map_txt + '\n', src, count=1)

# 3) logo desce das linhas 1-6 p/ 6-11 (py 48-95, replica o mockup)
troca('\t\t\t#tw = i / 16 + 1', '\t\t\t#tw = i / 16 + 6')
troca("\t' Logo (128x48) centralizada: tiles linhas 1-6, colunas 8-23",
      "\t' Logo SPACE BLAST (128x48): tiles linhas 6-11, colunas 8-23")

# 4) atributos novos (logo pal1 / APERTE START branco pal2 / rodape ciano pal3)
attrs_old = src[src.index("\t' Atributos (quads 16x16)"):src.index('\tSCREEN ENABLE')]
attrs_new = """\t' Atributos (quads 16x16): pal1 = logo; pal2 = APERTE START branco;
\t' pal3 = rodape ciano; pal0 = estrelas no resto.
\tVPOKE $23CA,$50\t\t' logo rows 6-7 (py48-63, so quads inferiores) pal1
\tVPOKE $23CB,$50
\tVPOKE $23CC,$50
\tVPOKE $23CD,$50
\tVPOKE $23D2,$55\t\t' logo rows 8-11 (py64-95) pal1
\tVPOKE $23D3,$55
\tVPOKE $23D4,$55
\tVPOKE $23D5,$55
\tVPOKE $23EA,$80\t\t' \"APERTE START\" (py176-183) -> pal2 branco
\tVPOKE $23EB,$A0
\tVPOKE $23EC,$A0
\tVPOKE $23ED,$40
\tVPOKE $23F1,$C0\t\t' rodape (py216-223, quads inf.) -> pal3 ciano
\tVPOKE $23F2,$F0
\tVPOKE $23F3,$F0
\tVPOKE $23F4,$F0
\tVPOKE $23F5,$F0
\tVPOKE $23F6,$30
"""
src = src.replace(attrs_old, attrs_new, 1)

# 5) textos: APERTE START row 22 branco; rodape row 27 ciano com bullet
src = src.replace('PRINT AT 394,"APERTE START"', 'PRINT AT 714,"APERTE START"')
troca('\tPRINT AT 839,"2026 - FALCON SOFT"',
      '\tPRINT AT 871,"2026   FALCON SOFT"\n\tVPOKE $2876,212\t\t\' "•" central do rodape')
# game over tambem usava APERTE START em AT 458 - sem mudanca (estilo proprio)

# 6) paletas: pal1 = teal/ciano/branco (logo), pal2 = branco puro, pal3 = ciano
troca("""\tDATA BYTE $0F,$12,$1C,$30\t' fundo 1: azul/ciano/branco (logo e textos)
\tDATA BYTE $0F,$16,$25,$30\t' fundo 2: vermelho/rosa/branco (faixa)
\tDATA BYTE $0F,$16,$25,$30\t' fundo 3: igual (sobra)""",
"""\tDATA BYTE $0F,$1C,$3C,$30\t' fundo 1: teal/ciano/branco (logo Space Blast)
\tDATA BYTE $0F,$30,$30,$30\t' fundo 2: branco puro (APERTE START)
\tDATA BYTE $0F,$1C,$3C,$3C\t' fundo 3: ciano uniforme (rodape)""")

# 7) tile do bullet "•" no slot 212 (livre)
troca('\n\tCHRROM PATTERN 268',
'''\n\tCHRROM PATTERN 212
\t' bullet "•" do rodape (bits 3, sai ciano na regiao pal3)
\tBITMAP "........"
\tBITMAP "...33..."
\tBITMAP "..3333.."
\tBITMAP "..3333.."
\tBITMAP "...33..."
\tBITMAP "........"
\tBITMAP "........"
\tBITMAP "........"

\tCHRROM PATTERN 268''')

open(BAS, 'w').write(src)
print('patch aplicado. tiles não-vazios:', sum(1 for v in mapa if v != 255), 'de 96')
