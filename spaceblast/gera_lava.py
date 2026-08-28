#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gera_lava.py — v0.19 "Planeta de Lava": gera os includes da fase 2.

Saidas:
  lava_chr2.bas.inc    — CHRROM 2 (pagina de tiles da fase 2):
                         metade BG ($0000): 32-95  = FONTE DO SAULO (copia
                           byte-exata do que esta no ROM atual),
                           96+ = tiles da lava (metatiles 16x16 abertos em
                           4 subtiles 8x8, com dedup),
                           192-211 = pares de digitos do placar,
                           214-221 = GAMEOVER estilizado,
                           224-229 = mini-labels;
                         metade SPRITE ($1000): copia integral da metade
                           sprite da pagina 0 (nave, inimigos, tiros, HUD).
  lava_layout.bas.inc  — tabelas da fase 2 (na area do BANK 3):
                         lava_tiles: 72 BYTEs (18 metatiles x 4 subtiles)
                         lava_lay_a: 15 linhas x 16 colunas (metatiles) p/ $2000
                         lava_lay_b: idem p/ $2800/$2400 (2a metade do bloco)
                         lava_can: n canhoes + pares (col, linha-meta)
                         lava_palette: 32 cores (BG pal0 = lava, sprites = play)

Tileset: uploads/Lava Stage BG.png (96x48, 18 metatiles 16x16, cores que
batemm 1:1 com a paleta NES: $07/$16/$17/$0C/$1C — remapeamos $17->$16,
7 px do D3). Todos os metatiles usam pal0 -> attr todo zero.
"""
import random
from PIL import Image

ROM  = '/home/user/spaceblast/space-blast.nes'
PNG  = '/home/user/uploads/Lava Stage BG.png'
H_OFF = 16 + 29 * 16384          # inicio da CHRROM 0 no .nes

COLMAP = {(136,20,0):0, (248,56,0):1, (228,92,16):1, (0,136,136):2, (0,64,88):3}

# ---------- tileset ----------
im = Image.open(PNG).convert('RGB')
assert im.size == (96, 48)
def subtile(cx, cy):             # 8x8 comecando em (cx,cy) -> lista de 8 str
    out = []
    for y in range(8):
        ln = ''
        for x in range(8):
            ln += str(COLMAP[im.getpixel((cx + x, cy + y))])
        out.append(ln)
    return out
metas = []                       # 18 metatiles, cada um = 4 subtiles
for my in range(3):
    for mx in range(6):
        px, py = mx * 16, my * 16
        metas.append([subtile(px, py), subtile(px + 8, py),
                      subtile(px, py + 8), subtile(px + 8, py + 8)])
uniq, ids = [], []
for m in metas:
    row = []
    for st in m:
        if st not in uniq:
            uniq.append(st)
        row.append(uniq.index(st))
    ids.append(row)
print(f'lava: 18 metatiles -> {len(uniq)} subtiles unicos (de 72)')
assert 96 + len(uniq) <= 190, 'estourou area da lava (96..190)'

# ---------- extrai tiles do ROM atual ----------
def rom_tile(page, n):
    with open(ROM, 'rb') as f:
        f.seek(H_OFF + page * 8192 + n * 16)
        b = f.read(16)
    st = []
    for r in range(8):
        ln = ''
        for cbit in range(8):
            lo = (b[r] >> (7 - cbit)) & 1
            hi = (b[r + 8] >> (7 - cbit)) & 1
            ln += str(lo + hi * 2)
        st.append(ln)
    return st

def emit(fd, pattern, tiles, comentario=None):
    if comentario:
        fd.write("\n\t' %s\n" % comentario)
    fd.write('\tCHRROM PATTERN %d\n\n' % pattern)
    for t in tiles:
        for ln in t:
            fd.write('\tBITMAP "%s"\n' % ln)
        fd.write('\n')

with open('/home/user/spaceblast/lava_chr2.bas.inc', 'w') as fd:
    fd.write("\t' ==== gerado por gera_lava.py (v0.19): CHRROM 2 = fase 2 (lava) ====\n")
    fd.write('\tCHRROM 2\n')
    emit(fd, 32, [rom_tile(0, n) for n in range(32, 96)],
         'FONTE DO SAULO (32-95): copia byte-exata do ROM atual')
    emit(fd, 96, uniq, 'tiles da lava (dedup): metatiles 16x16 -> 4 subtiles 8x8')
    emit(fd, 192, [rom_tile(0, n) for n in range(192, 212)],
         'pares 8x16 dos digitos do placar (copia)')
    emit(fd, 214, [rom_tile(0, n) for n in range(214, 222)],
         'GAMEOVER estilizado (copia)')
    emit(fd, 224, [rom_tile(0, n) for n in range(224, 230)],
         'mini-labels BONUS/1UP (copia)')
    emit(fd, 256, [rom_tile(0, n) for n in range(256, 512)],
         'metade SPRITE: copia integral da pagina 0 (nave/inimigos/tiros/HUD)')
print('lava_chr2.bas.inc OK')

# ---------- layout da fase 2 ----------
random.seed(20260730)
A1, B1, DECOR = 0, 1, [3, 15, 16, 17]        # A1 base, B1 canhao, D1/D3/E3/F3
ILHA1 = [[6,7,8],[12,13,14]]                 # A2B2C2 / A3B3C3
ILHA2 = [[4,5,6],[9,10,11]]                  # E1,A1?? nao: A1,E1,F1 = [0,4,5] / D2,E2,F2=[9,10,11]
ILHA2 = [[0,4,5],[9,10,11]]
def gen_half(n_islands, n_cannons, used):
    n_cannons = 0  # v0.20: canhoes removidos (pedido do Saulo)
    grid = [[A1] * 16 for _ in range(15)]
    busy = [[False] * 16 for _ in range(15)] # celulas ocupadas (ilha/canhao)
    cans = []
    def free(r, c, w, h):
        return all(not busy[r+dy][c+dx] for dy in range(h) for dx in range(w))
    def occ(r, c, w, h):
        for dy in range(h):
            for dx in range(w):
                busy[r+dy][c+dx] = True
    for _ in range(n_islands):               # ilhas atomicas 3x2
        for t in range(40):
            il = ILHA1 if random.random() < 0.5 else ILHA2
            r, c = random.randint(0, 13), random.randint(0, 13)
            if free(r, c, 3, 2):
                for dy in range(2):
                    for dx in range(3):
                        grid[r+dy][c+dx] = il[dy][dx]
                occ(r, c, 3, 2)
                break
    for _ in range(n_cannons):               # canhoes (1 metatile cada)
        for t in range(60):
            r, c = random.randint(0, 14), random.randint(0, 15)
            if not busy[r][c]:
                grid[r][c] = B1
                busy[r][c] = True
                cans.append((c, r))
                break
    for r in range(15):                      # decor espalhada em base livre
        for c in range(16):
            if grid[r][c] == A1 and random.random() < 0.07:
                grid[r][c] = DECOR[random.randrange(4)]
    return grid, cans

lay_a, can_a = gen_half(2, 2, None)
lay_b, can_b = gen_half(2, 3, None)
# canhoes: guardar (col, meta-linha global 0..29)
cannons = [(c, r) for c, r in can_a] + [(c, r + 15) for c, r in can_b]
with open('/home/user/spaceblast/lava_layout.bas.inc', 'w') as fd:
    fd.write("\t' ==== gerado por gera_lava.py (v0.19): layout da fase 2 ====\n")
    fd.write("\t' mapas EXPANDIDOS: 30 tile-rows x 32 tiles por metade\n")
    fd.write("\t' (metatile mx*2,my*2 -> tiles 2x2 via tabela de ids dedup)\n")
    def tile_ids(m):
        return [96 + v for v in ids[m]]
    for name, lay in [('lava_map_a', lay_a), ('lava_map_b', lay_b)]:
        fd.write('%s:\n' % name)
        rows = []
        for mr in lay:                     # 15 metarows -> 30 tile-rows
            top, bot = [], []
            for mid in mr:
                t = tile_ids(mid)
                top += [t[0], t[1]]
                bot += [t[2], t[3]]
            rows.append(top); rows.append(bot)
        for r in rows:
            fd.write('\tDATA BYTE ' + ','.join(str(v) for v in r) + '\n')
    fd.write('lava_can:\n\tDATA BYTE %d\n' % len(cannons))
    for c, r in cannons:
        fd.write('\tDATA BYTE %d,%d\n' % (c, r))
    fd.write("lava_palette:\n"
             "\tDATA BYTE $07,$16,$1C,$0C\t' fundo 0: LAVA (fundo universal $07)\n"
             "\tDATA BYTE $07,$16,$1C,$0C\t' fundo 1 (idem: reserva)\n"
             "\tDATA BYTE $07,$16,$1C,$0C\t' fundo 2\n"
             "\tDATA BYTE $07,$16,$1C,$0C\t' fundo 3\n"
             "\tDATA BYTE $0F,$00,$10,$30\t' sprites 0: cinzas (nave, placar)\n"
             "\tDATA BYTE $0F,$16,$21,$12\t' sprites 1: vermelho/azuis\n"
             "\tDATA BYTE $0F,$19,$2A,$30\t' sprites 2: verdes (chama/shard)\n"
             "\tDATA BYTE $0F,$1C,$3C,$30\t' sprites 3: quentes (explosao/tiros)\n")
print('lava_layout.bas.inc OK —', len(cannons), 'canhoes:', cannons)
