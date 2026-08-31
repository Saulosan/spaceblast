#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gera_fonte.py — v0.17 "Fonte Saulo": instala a spritefont do Saulo
(uploads/Sprite_font.png, 16x6 cells de 8x8, 2 cores) como A fonte do jogo.

O que faz em space-blast.bas (idempotente, roda quantas vezes quiser):

1. Insere (ou substitui) o bloco marcado 'FONTE SAULO v0.17' ANTES do bloco
   da logo (primeiro 'CHRROM PATTERN 96'), contendo:
   - CHRROM PATTERN 32  : 64 glifos ASCII 32-95 a partir da spritefont
                          (last-write-wins sobre a fonte default do CVBasic,
                           que e' gravada antes dos blocos do usuario)
   - CHRROM PATTERN 192 : 10 pares de digitos 8x16 (tile par = glifo, impar =
                          vazio) p/ o placar/vidas em sprites. CORRIGE O HUD:
                          antes usava 128+2d, que caia nos tiles da LOGO
                          (score exibia fragmentos da logo como "blocos
                          brancos/caixinhas" — bug existia desde o v0.15).
   - CHRROM PATTERN 214 : 8 tiles GAMEOVER estilizados (cells 80-87)
   - CHRROM PATTERN 224 : 6 tiles decor/mini-labels (cells 72-76, 62)
2. Troca os bitmaps dos glifos do splash (patterns 182-188 do CHRROM 1)
   pelas versoes MAIUSCULAS da spritefont ("apresenta" -> "APRESENTA"):
   mapa de tiles do splash: a=182 e=183 s=184 p=185 r=186 n=187 t=188
   (linha DATA BYTE 182,185,186,183,187,183,184,188,182 = "apresenta").
3. Placar/vidas: 'sN * 2 + 128' -> 'sN * 2 + 192' e 'li * 2 + 128' ->
   'li * 2 + 192' (6 pontos), apontando p/ os novos pares 192-211.
   (sprites 8x16: byte OAM par -> tabela $0000; pares (T,T+1))
4. Game over: PRINT AT 331,"GAME OVER" -> 9 VPOKEs com os tiles
   estilizados 214-221 (sequencia G A M E _ O V E R com espaco no meio).

Pixels: folha e' 1-bit; emitimos pixel '3' (dois planos iguais), identico
a' fonte default do CVBasic -> comportamento de paleta INALTERADO.
"""
import os
import re
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
UPLOADS = Path(os.environ.get('SPACEBLAST_UPLOADS', HERE.parent / 'uploads'))
SHEET = UPLOADS / 'Sprite_font.png'
BAS   = HERE / 'space-blast.bas'
MARK_I = "\t' ===== FONTE SAULO v0.17 — INICIO (gera_fonte.py) ====="
MARK_F = "\t' ===== FONTE SAULO v0.17 — FIM ====="

# ---------- 1. le a folha ----------
im = Image.open(SHEET).convert('RGBA')
assert im.size == (128, 48), im.size
cells = []  # 96 x lista de 8 strings de 8 chars '3'/'.'
for c in range(96):
    col, row = (c % 16) * 8, (c // 16) * 8
    lines = []
    for y in range(8):
        ln = ''
        for x in range(8):
            r, g, b, a = im.getpixel((col + x, row + y))
            ln += '3' if (r + g + b) > 382 and a > 128 else '.'
        lines.append(ln)
    cells.append(lines)

def tile_bmps(cell_lines):
    return ['\tBITMAP "%s"' % l for l in cell_lines]

EMPTY8 = ['........'] * 8

# ---------- 2. mapa ASCII -> cell ----------
# linha 0 da folha: 0=vazio 1=v 2=> 3=^ 4=< 5-8=cantos 9=faisca 10-12=aspas
#                   13=4pontos 14=trema 15=Ç
# linha 1: 16-25 = 0-9 | 26-31 = A-F | linha 2: 32-47 = G-V
# linha 3: 48=W 49=X 50=Y 51=Z 52=. 53=; 54=: 55=? 56=! 57=, 58=" 59=- 60=...
#          61=bloco 62=<| 63=vazio
# linha 4: 64-65=runes 66=')' 67='(' 68=']' 69='[' 70-71=fino 72-76=mini
# linha 5: 80-87 = G A M E O V E R estilizados
MAP = {a: 0 for a in range(32, 96)}          # default: vazio (cell 0)
for d in range(10):  MAP[48 + d] = 16 + d    # 0-9
for l in range(26):  MAP[65 + l] = 26 + l    # A-Z
MAP.update({
    33: 56,  # !      34: 58,  # "
    35: 61,  # # = bloco solido      38: 9,   # & = faisca
    39: 10,  # '      40: 67,  # (   41: 66,  # )
    42: 9,   # * = faisca           43: 9,   # + = faisca
    44: 57,  # ,      45: 59,  # -   46: 52,  # .
    58: 54,  # :      59: 53,  # ;
    60: 4,   # < = seta esq         62: 2,   # > = seta dir
    63: 55,  # ?
    91: 69,  # [      93: 68,  # ]
    94: 3,   # ^ = seta cima        95: 59,  # _ = traco
    96: 15,  # ` = Ç (p/ "ESPAÇO" no futuro!)
    123: 5,  # { = canto sup-esq    125: 6,  # } = canto sup-dir
    126: 1,  # ~ = seta baixo
})

def build_font_section():
    L = [MARK_I,
         "\t' spritefont 16x6 do Saulo (uploads/Sprite_font.png). pixels '3' (2",
         "\t' planos) = mesmo estilo da fonte CVBasic -> paleta identica.",
         "\t' ASCII 32-95: digitos 0-9, A-Z e pontuacao mapeada.",
         "\tCHRROM PATTERN 32",
         ""]
    for a in range(32, 96):
        L += tile_bmps(cells[MAP[a]]) + [""]
    L += ["\t' --- digitos do placar (sprites 8x16): par = glifo, impar = vazio;",
          "\t'     T = 192 + 2*d (byte OAM par -> tabela $0000, pares T/T+1)",
          "\tCHRROM PATTERN 192", ""]
    for d in range(10):
        L += tile_bmps(cells[16 + d]) + [""]
        L += tile_bmps(EMPTY8) + [""]
    L += ["\t' --- GAME OVER estilizado (cells 80-87 da folha)",
          "\tCHRROM PATTERN 214", ""]
    for c in range(80, 88):
        L += tile_bmps(cells[c]) + [""]
    L += ["\t' --- decor/mini-labels reservados: BONUS parts, 1UP, <|",
          "\tCHRROM PATTERN 224", ""]
    for c in (72, 73, 74, 75, 76, 62):
        L += tile_bmps(cells[c]) + [""]
    L.append(MARK_F)
    return '\n'.join(L)

# ---------- 3. aplica no .bas ----------
src = open(BAS, encoding='utf-8').read()

# 3a. remove secao antiga (idempotencia)
pat = re.compile(re.escape(MARK_I) + r'.*?' + re.escape(MARK_F) + '\n?', re.S)
src, ncut = pat.subn('', src)

# 3b. insere antes do bloco da logo (primeiro CHRROM PATTERN 96)
i = src.index('\tCHRROM PATTERN 96')
src = src[:i] + build_font_section() + '\n\n' + src[i:]

# 3c. splash: substitui os 8 BITMAPs de cada glifo 182-188 pelos MAIUSCULOS
SPLASH = {182: 26, 183: 30, 184: 39, 185: 41, 186: 43, 187: 44, 188: 45}
#          a=A     e=E     n=N     p=P     r=R     s=S     t=T
# (ordem REAL lida da linha DATA BYTE 182,185,186,183,187,183,184,188,182:
#  a p r e s e n t a  =>  s=187, n=184 — verificado no emulador!)
lines = src.split('\n')
for tno, cellno in SPLASH.items():
    idx = [k for k, ln in enumerate(lines)
           if ln.strip() == 'CHRROM PATTERN %d' % tno]
    assert len(idx) == 1, (tno, idx)   # so existe na CHRROM 1
    k = idx[0]
    bm = [k + 1 + j for j in range(8)]
    for j, m in enumerate(bm):
        assert lines[m].lstrip().startswith('BITMAP'), (tno, j, lines[m])
        lines[m] = tile_bmps(cells[cellno])[j]
src = '\n'.join(lines)

# 3d. placar/vidas: novo base 192
subs = [(s, s.replace('+ 128', '+ 192'))
        for s in ('s0 * 2 + 128', 's1 * 2 + 128', 's2 * 2 + 128',
                  's3 * 2 + 128', 's4 * 2 + 128', 'li * 2 + 128')]
done = 0
for old, new in subs:
    if new in src:                      # ja aplicado (idempotente)
        done += 1
        continue
    assert old in src, old
    src = src.replace(old, new)
    done += 1
assert done == 6, done

# 3e. game over estilizado
old_go = '\tPRINT AT 331,"GAME OVER"'
new_go = ("\tVPOKE $214B,214\t' GAME OVER estilizado (tiles 214-221 do folha)\n"
          "\tVPOKE $214C,215\n"
          "\tVPOKE $214D,216\n"
          "\tVPOKE $214E,217\n"
          "\tVPOKE $214F,32\n"
          "\tVPOKE $2150,218\n"
          "\tVPOKE $2151,219\n"
          "\tVPOKE $2152,220\n"
          "\tVPOKE $2153,221")
if new_go.split('\n')[0] in src:
    pass                                # ja aplicado
else:
    assert old_go in src
    src = src.replace(old_go, new_go)

open(BAS, 'w', encoding='utf-8').write(src)
print('gera_fonte: OK (secao fonte %s, splash 182-188, placar base 192, GAMEOVER tiles)' %
      ('atualizada' if ncut else 'inserida'))
