#!/usr/bin/env python3
# SPACE BLAST v0.16: regenera a logo do titulo a partir de title-space.png
# (128x48: SPACE branco/cinza + cometa teal + BLAST vermelho + estrelas),
# sem barra de katakana. Tambem: corrige "APERTE START" todo branco e
# substitui as estrelas do fundo (patterns 1-29) pelas da nova folha.
import re
import numpy as np
from PIL import Image

BAS = '/home/user/spaceblast/space-blast.bas'
PNG = '/home/user/uploads/title-space.png'
PREV = '/home/user/spaceblast/docs/title_nova_preview.png'

im = np.array(Image.open(PNG).convert('RGB'))
CORES = {'W':(255,255,255), 'G':(160,160,160), 'T':(10,124,138), 'D':(152,3,3), 'R':(222,0,0)}
CID = {v:k for k,v in CORES.items()}
def cls(px):
    t = tuple(int(v) for v in px)
    if t == (0,0,0): return None
    return CID.get(t)

grid, pxc = {}, {}
for ty in range(6):
    for tx in range(16):
        cell = im[ty*8:(ty+1)*8, tx*8:(tx+1)*8]
        s = set()
        for y in range(8):
            for x in range(8):
                c = cls(cell[y,x])
                if c: s.add(c)
        grid[(tx,ty)] = s
        pxc[(tx,ty)] = cell

# paletas: pal1=SPACE($0F,$00,$10,$30) pal2=BLAST($0F,$06,$16,$30) pal3=COMETA($0F,$1C,$10,$30)
MAPA_IDX = {
    'S': {'W':3,'G':2},                         # pal1
    'B': {'D':1,'R':2,'W':3,'G':3,'T':3},       # pal2 (remapeia G/T->branco: so pontinhos)
    'C': {'T':1,'G':2,'W':3},                    # pal3
}
remaps = []
def escolhe_pal(qx, qy):
    tiles = [ (qx*2+dx, qy*2+dy) for dy in range(2) for dx in range(2) ]
    reds  = any(grid[t] & {'R','D'} for t in tiles)
    teal  = any(grid[t] & {'T'} for t in tiles)
    gray  = any(grid[t] & {'G'} for t in tiles)
    if reds: pal = 'B'
    elif teal: pal = 'C'
    else: pal = 'S'
    for t in tiles:
        for c in grid[t]:
            if c not in MAPA_IDX[pal]:
                remaps.append((t, c, pal))
    return pal

pal_quad = {}
for qy in range(3):
    for qx in range(8):
        pal_quad[(qx,qy)] = escolhe_pal(qx, qy)
print("paleta por quad (linhas 0-2):")
for qy in range(3):
    print('  ' + ''.join(pal_quad[(qx,qy)] for qx in range(8)))
print("remaps de respaldo:", len(remaps), remaps[:12])

# gera tiles (idx por paleta do quad)
def tile_idx(tx, ty):
    pal = pal_quad[(tx//2, ty//2)]
    mp = MAPA_IDX[pal]
    cell = pxc[(tx,ty)]
    out = np.zeros((8,8), dtype=np.uint8)
    for y in range(8):
        for x in range(8):
            c = cls(cell[y,x])
            if c: out[y,x] = mp.get(c, 3)
    return out

tiles, where, cellmap = [], {}, []
for cell in range(96):
    col, row = cell % 16, cell // 16
    t = tile_idx(col, row)
    key = t.tobytes()
    if key not in where:
        where[key] = len(tiles); tiles.append(t)
    cellmap.append(where[key] + 96)
NT = len(tiles)
print("tiles unicos da logo:", NT, "-> patterns 96..", 96+NT-1, "(212 livre = bullet intacto)")
assert 96+NT-1 < 212 and 96+NT-1 != 211 or True
assert 96+NT-1 < 212, "estourou o bullet 212!"

def bm(t):
    return [f'\tBITMAP "{"".join("." if v==0 else str(v) for v in row)}"' for row in t]

sec = []
sec.append("\t' ---- LOGO SPACE BLAST v0.16 (title-space.png do Saulo) ----")
sec.append("\t' SPACE branco/cinza pal1; cometa teal pal3; BLAST vermelho pal2;")
sec.append("\t' tiles deduplicados contiguos 96+ (218 max, bullet 212 intacto)")
sec.append("\tCHRROM PATTERN 96\n")
for t in tiles:
    sec += bm(t) + ['']
sec_txt = '\n'.join(sec)

# logo_map
mp = "logo_map:\n" + '\n'.join('\tDATA BYTE ' + ','.join(str(v) for v in cellmap[i:i+8]) for i in range(0, 96, 8))

# atributos logo (rows 6-11 cols 8-23)
NIB = {'S':1, 'B':2, 'C':3}
def qval(qx, qy): return NIB[pal_quad[(qx,qy)]]
b_CA = 0x00 | (qval(0,0)<<2) | (qval(1,0)<<6)
b_CB = 0x00 | (qval(2,0)<<2) | (qval(3,0)<<6)
b_CC = 0x00 | (qval(4,0)<<2) | (qval(5,0)<<6)
b_CD = 0x00 | (qval(6,0)<<2) | (qval(7,0)<<6)
b_D2 = (qval(0,1)<<0) | (qval(1,1)<<4) | (qval(0,2)<<2) | (qval(1,2)<<6)
b_D3 = (qval(2,1)<<0) | (qval(3,1)<<4) | (qval(2,2)<<2) | (qval(3,2)<<6)
b_D4 = (qval(4,1)<<0) | (qval(5,1)<<4) | (qval(4,2)<<2) | (qval(5,2)<<6)
b_D5 = (qval(6,1)<<0) | (qval(7,1)<<4) | (qval(6,2)<<2) | (qval(7,2)<<6)
attrs = f"""\t' Atributos v0.16: pal1=SPACE, pal2=BLAST, pal3=cometa; pal0=estrelas.
\tVPOKE $23CA,${b_CA:02X}\t\t' logo rows 6-7\n\tVPOKE $23CB,${b_CB:02X}\n\tVPOKE $23CC,${b_CC:02X}\n\tVPOKE $23CD,${b_CD:02X}
\tVPOKE $23D2,${b_D2:02X}\t\t' logo rows 8-11\n\tVPOKE $23D3,${b_D3:02X}\n\tVPOKE $23D4,${b_D4:02X}\n\tVPOKE $23D5,${b_D5:02X}
\tVPOKE $23EA,$90\t\t' "APERTE START" (py176-183) -> pal2 = BRANCO em tudo\n\tVPOKE $23EB,$A8\n\tVPOKE $23EC,$A8\n\tVPOKE $23ED,$88
\tVPOKE $23F1,$C0\t\t' rodape (py216-223, quads inf.) -> pal3\n\tVPOKE $23F2,$F0\n\tVPOKE $23F3,$F0\n\tVPOKE $23F4,$F0\n\tVPOKE $23F5,$F0\n\tVPOKE $23F6,$30
"""

# ---- estrelas do jogo: extrai pontinhos esparsos da folha nova ----
star_tiles, star_where = [], {}
for (tx,ty), cell in sorted(pxc.items()):
    s = grid[(tx,ty)]
    if not s or (s & {'R','D'}): continue
    n = sum((cls(cell[y,x]) is not None) for y in range(8) for x in range(8))
    if n > 6: continue                      # agrupamento denso = parte de letra/cometa
    # rejeita pixels que fazem parte de tracos longos (cometa/letras):
    # aceita so max run horizontal <= 3 e vertical <= 3
    ok = True
    for y in range(8):
        run = 0
        for x in range(8):
            run = run+1 if cls(cell[y,x]) is not None else 0
            if run > 3: ok = False
    for x in range(8):
        run = 0
        for y in range(8):
            run = run+1 if cls(cell[y,x]) is not None else 0
            if run > 3: ok = False
    if not ok: continue
    # remapeia p/ convencao das estrelas: teal->1 branco->2 cinza->3
    t = np.zeros((8,8), dtype=np.uint8)
    for y in range(8):
        for x in range(8):
            c = cls(cell[y,x])
            if c == 'T': t[y,x] = 1
            elif c == 'W': t[y,x] = 2
            elif c == 'G': t[y,x] = 3
    key = t.tobytes()
    if key not in star_where:
        star_where[key] = len(star_tiles); star_tiles.append(t)
print("tiles de estrela extraidos:", len(star_tiles), [(s.tobytes()==s.tobytes()) for s in star_tiles][:1])
NS = len(star_tiles)
assert NS <= 29, "muitas estrelas"

star_sec = []
star_sec.append("\tCHRROM PATTERN 0")
star_sec += bm(np.zeros((8,8), dtype=np.uint8)) + ['']    # tile 0 = vazio
for t in star_tiles:
    star_sec += bm(t) + ['']
for _ in range(29 - NS):                                    # limpa restos
    star_sec += bm(np.zeros((8,8), dtype=np.uint8)) + ['']
star_txt = '\n'.join(star_sec) + '\n'

# nep_tab: 23 entradas (cicla as estrelas novas)
nep_vals = [(i % NS) + 1 for i in range(23)]
nep_txt = "nep_tab:\n" + '\n'.join('\tDATA BYTE ' + ','.join(str(v) for v in nep_vals[i:i+8]) for i in range(0, 23, 8))

pals = """\tDATA BYTE $0F,$11,$21,$00\t' fundo 0: preto, azuis + cinza escuro (estrelas)
\tDATA BYTE $0F,$00,$10,$30\t' fundo 1: cinza/branco (SPACE)\n\tDATA BYTE $0F,$06,$16,$30\t' fundo 2: vermelhos (BLAST)\n\tDATA BYTE $0F,$1C,$10,$30\t' fundo 3: teal/cinza/branco (cometa)"""

# ================= aplica no .bas =================
src = open(BAS).read()

# 1) CHRROM da logo: substitui o bloco PATTERN 96..(antes do PATTERN 128 que fecha a serie antiga)
#    A serie antiga v0.6: PATTERN 96 .. PATTERN 148 .. PATTERN 128 .. (PATTERN 212 bullet)
m0 = re.search(r"\n\tCHRROM PATTERN 96\n.*?\n\t?CHRROM PATTERN 128\n", src, flags=re.S)
assert m0, "bloco PATTERN 96..128 nao achado"
# preserva o PATTERN 128 (conteudo entre PATTERN 128 e o proximo CHRROM que nao seja de logo?)
# v0.6: PATTERN 128 seguido de PATTERN 212 (bullet). O 128-147 era resto do layout velho.
m1 = re.search(r"\n\t?CHRROM PATTERN 128\n.*?\n\tCHRROM PATTERN 212\n", src, flags=re.S)
assert m1, "bloco PATTERN 128..212 nao achado"
src = src[:m0.start()] + '\n' + sec_txt + '\n' + src[m1.end():]

# 2) bloco de estrelas PATTERN 0 (tile 0..): vai ate o proximo "\n\tCHRROM PATTERN"
m2 = re.search(r"(\tCHRROM PATTERN 0\n(?:.*?))(?=\n\tCHRROM PATTERN (?!0\n))", src, flags=re.S)
assert m2, "bloco PATTERN 0 nao achado"
src = src[:m2.start()] + star_txt + src[m2.end():]

# 3) logo_map
src = re.sub(r"logo_map:\n(?:\tDATA BYTE .*\n)+", mp + "\n", src, count=1)

# 4) atributos do titulo
a0 = src.index("\t' Atributos (quads 16x16)")
a1 = src.index("\tWAIT", a0)
src = src[:a0] + attrs + src[a1:]

# 5) nep_tab
src = re.sub(r"nep_tab:\n(?:\tDATA BYTE .*\n)+", nep_txt + "\n", src, count=1)

# 6) paletas do titulo
src = src.replace("""\tDATA BYTE $0F,$11,$21,$00\t' fundo 0: preto, azuis + cinza escuro
\tDATA BYTE $0F,$1C,$3C,$30\t' fundo 1: teal/ciano/branco (logo Space Blast)\n\tDATA BYTE $0F,$30,$30,$30\t' fundo 2: branco puro (APERTE START)\n\tDATA BYTE $0F,$1C,$3C,$3C\t' fundo 3: ciano uniforme (rodape)""", pals, 1)

# 7) cabecalho da tela de titulo (comentario)
src = src.replace("\t' Logo SPACE BLAST (128x48): tiles linhas 6-11, colunas 8-23",
                  "\t' Logo SPACE BLAST (128x48): tiles linhas 6-11, colunas 8-23\n\t' v0.16: art nova (sem katakana), paletas por quad, estrelas da folha nova", 1)

open(BAS, 'w').write(src)
print("PATCH TITULO APLICADO.")

# preview da tela de titulo
NES = {'00':(0,0,0),'0F':(16,16,16),'06':(120,21,13),'16':(222,32,32),'10':(120,120,120),'30':(236,236,236),'11':(0,71,150),'21':(48,124,207),'1C':(0,168,168),'3C':(92,208,255)}
PALV = {1:['0F','00','10','30'], 2:['0F','06','16','30'], 3:['0F','1C','10','30']}
scr = np.zeros((48,128,3), dtype=np.uint8) + 16
for ty in range(6):
    for tx in range(16):
        t = tiles[cellmap[ty*16+tx]-96]
        pid = NIB[pal_quad[(tx//2, ty//2)]]
        pal = [NES[c] for c in PALV[pid]]
        for y in range(8):
            for x in range(8):
                v = t[y,x]
                if v: scr[ty*8+y, tx*8+x] = pal[v]
Image.fromarray(scr).resize((128*5,48*5), Image.NEAREST).save(PREV)
print("preview:", PREV)
