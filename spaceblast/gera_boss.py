#!/usr/bin/env python3
# BOSS do Saulo -- v0.13 (reescrita pos-feedback dele):
#
#   * boss.png 96x128 = SPRITESHEET DE 2 FRAMES (96x64 cada), NAO 2 naves!
#   * Boss = UMA nave 96x64, NO ALTO da tela (linhas NT 3-10, cols 9-20).
#   * Render 100% Background (dito do autor), tiles na tabela $1000 com
#     flip da ppu_ctrl (BG=$1000 so durante a luta; sprites 8x16 escolhem
#     a tabela pelo bit0 do byte OAM -> nao sao afetados).
#   * "Animacao" dos 2 quadros = PULSO DE PALETA (ideia do autor): a cor
#     clara $38 pulsa (38/28/18/28) a cada 14 frames no game_loop.
#   * Balanco lateral: ceu 100% preto na luta + SCROLL x fino (+-16px) =
#     o classico "chefe de BG que se mexe" dos jogos de NES.
#   * ONDE OS TILES MORAM (tabela $1000, 86 unicos medidos):
#       livres locais: 1-11 (11), 16-19 (4), 180-215 (36 = ex-asas!),
#       220-255 (36) = 88 slots >= 86. Laser (172-179) e tiro (216-219)
#       continuam intactos. A FONTE ($0000 32-95) NUNCA MAIS e tocada
#       (bug v0.12: PRINT = ASCII direto p/ tile - fonte virou arte!).
# Emite /tmp/chr_bossbg.bas /tmp/boss_procs.bas /tmp/boss_ingame.png
from PIL import Image

C3 = {(68, 40, 188): '1', (152, 120, 248): '2', (248, 216, 120): '3'}
CL = {(0, 120, 248): '1', (164, 228, 252): '2', (252, 252, 252): '3',
      (60, 188, 252): '2'}

def load(p, cmap):
    im = Image.open(p).convert('RGBA')
    px = im.load()
    def q(x, y):
        r, g, b, a = px[x, y]
        if a <= 100 or r < 40:
            return '.'
        return cmap.get((r, g, b), '2')
    return im.width, im.height, q

_, _, bq = load('/home/user/uploads/boss.png', C3)

def cell8(q, tx, ty):
    return tuple(''.join(q(tx * 8 + x, ty * 8 + y) for x in range(8))
                 for y in range(8))

# geometria: boss 96x64 no ALTO -> NT linhas 3-10, cols 9-20
BX, BY = 72, 24
NT = 0x2000

# ============ CHR $1000: corpo do boss (frame 0 do spritesheet) ============
cells = {}
for ty in range(8):
    for tx in range(12):
        cells[(tx, ty)] = cell8(bq, tx, ty)
VAZIO = tuple(['........'] * 8)
uniq = list(dict.fromkeys(t for t in cells.values() if t != VAZIO))

# slots livres na $1000 (globais): 257-267, 272-275, 436-471, 476-511.
# O 256 (tile local 0) FICA DE FORA: e o "vazio universal" do ceu preto
# - se tiver arte, o fundo vira grade (o MESMO bug do tile 32 na v0.12!)
LIVRES = (list(range(257, 268)) + list(range(272, 276))
          + list(range(436, 472)) + list(range(476, 512)))
print('tiles BG unicos:', len(uniq), '(slots:', len(LIVRES), ')')
assert len(uniq) <= len(LIVRES)
fis_map = {}
for i, t in enumerate(uniq):
    fis_map[t] = LIVRES[i]

out_bg = ["\t' BOSS em BG $1000 (gera_boss.py): 1 nave 96x64, frame 0\n"]
run = None
by_fis = {}
for t, f in fis_map.items():
    by_fis.setdefault(f, t)
for f in sorted(by_fis):
    if f != run:
        out_bg.append("\tCHRROM PATTERN %d\n" % f)
    for rowt in by_fis[f]:
        out_bg.append('\tBITMAP "' + ''.join(rowt) + '"\n')
    run = f + 1
open('/tmp/chr_bossbg.bas', 'w').writelines(out_bg)

# ============ codigo: sky_clear / boss_write / boss_erase ============
code = ["\t' === gerado por gera_boss.py (v0.13): ceu preto + boss BG $1000 ===\n"]
code.append("sky_clear:\tPROCEDURE\t' ceu 100% preto p/ luta (Saulo autorizou)\n")
code.append("\t' apaga as 960 celulas visiveis, 16 por frame (dreno do buffer)\n")
code.append("\t#bk = $2000\n")
code.append("\tgbc = 0\n")
code.append("sky_clear_loop:\n")
code.append("\tFOR i = 0 TO 15\n")
code.append("\t\tVPOKE #bk, 0\n")
code.append("\t\t#bk = #bk + 1\n")
code.append("\tNEXT i\n")
code.append("\tWAIT\n")
code.append("\tgbc = gbc + 1\n")
code.append("\tIF gbc < 60 THEN GOTO sky_clear_loop\n")
code.append("\tEND\n\n")

code.append("boss_write:\tPROCEDURE\t' desenha o corpo 96x64 (linhas 3-10)\n")
w = 0
def emit(s):
    global w
    code.append(s + "\n")
    w += 1
    if w % 19 == 0:
        code.append("\tWAIT\t' (gera_boss: drena buffer da PPU)\n")
# apaga o retangulo todo primeiro (inclusive celulas vazias: tiram restos)
for ty in range(8):
    for tx in range(12):
        emit("\tVPOKE $%04X,0" % (NT + (BY // 8 + ty) * 32 + (BX // 8) + tx))
# tiles (byte = slot LOCAL na $1000)
for (tx, ty), t in sorted(cells.items()):
    emit("\tVPOKE $%04X,%d" % (NT + (BY // 8 + ty) * 32 + (BX // 8) + tx,
                                fis_map.get(t, 0) - 256))
# atributos: linhas 3-10/cols 9-20 -> attr linhas 0-2, cols 2-5, tudo pal1
# (bordas parciais ficam pretas: tile 0 usa a cor universal $0F)
for ar in range(3):
    for ac in range(2, 6):
        emit("\tVPOKE $%04X,$55" % (0x23C0 + ar * 8 + ac))
code.append("\tEND\n\n")

code.append("boss_erase:\tPROCEDURE\t' remove o boss do BG (apos a morte)\n")
code.append("\t' retangulo cols 9-20, linhas 3-10 (1/2 linha por frame)\n")
for r in range(3, 11):
    code.append("\tFOR #j = $%04X TO $%04X\n" % (NT + r * 32 + 9, NT + r * 32 + 14))
    code.append("\t\tVPOKE #j,0\n\tNEXT #j\n")
    code.append("\tFOR #j = $%04X TO $%04X\n" % (NT + r * 32 + 15, NT + r * 32 + 20))
    code.append("\t\tVPOKE #j,0\n\tNEXT #j\n\tWAIT\n")
for ar in range(3):
    for ac in range(2, 6):
        code.append("\tVPOKE $%04X,0\n" % (0x23C0 + ar * 8 + ac))
code.append("\tWAIT\n\tEND\n")
open('/tmp/boss_procs.bas', 'w').writelines(code)

# ---- laser (Saulo, 16x32, pal3 ciano; bytes OAM 173/175/177/179) ----
_, _, lq = load('/home/user/uploads/laser.png', CL)
_, _, tq = load('/home/user/uploads/tiro player.png', CL)
out_extra = ["\t' Laser do Saulo (16x32, pal3 ciano; gera_boss.py)\n"]
for k, (col, half) in enumerate([(0, 0), (0, 1), (1, 0), (1, 1)]):
    f = 428 + k * 2
    out_extra.append("\tCHRROM PATTERN %d\n" % f)
    for y in range(16):
        out_extra.append('\tBITMAP "' + ''.join(lq(col*8+x, half*16+y)
                         for x in range(8)) + '"\n')
open('/tmp/chr_extra.bas', 'w').writelines(out_extra)

# ---- tiro novo do player (2 frames; bytes OAM 217/219) ----
out_t = []
for fno, base in ((0, 472), (1, 474)):
    out_t.append("\tCHRROM PATTERN %d\n" % base)
    for y in range(8):
        out_t.append('\tBITMAP "' + ''.join(tq(fno*8+x, y)
                     for x in range(8)) + '"\n')
    for y in range(8):
        out_t.append('\tBITMAP "........"\n')
open('/tmp/tiro_tiles.bas', 'w').writelines(out_t)

# ---- preview reconstruido (frame 0) ----
CHB = {'.': (8, 8, 16), '1': (68, 40, 188), '2': (152, 120, 248), '3': (248, 216, 120)}
im = Image.new('RGB', (96, 64), CHB['.'])
for ty in range(8):
    for tx in range(12):
        for y in range(8):
            for x in range(8):
                im.putpixel((tx*8+x, ty*8+y), CHB[bq(tx*8+x, ty*8+y)])
im.resize((384, 256), Image.NEAREST).save('/tmp/boss_ingame.png')
print('OK: boss 96x64 frame0 ->', len(uniq), 'tiles em $1000;',
      'attrs linhas 0-2 cols 2-5')
