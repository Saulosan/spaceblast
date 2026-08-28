#!/usr/bin/env python3
# miniboss-1.png (Saulo) -> tiles NES p/ 32x32, 2 frames (CHRROM PATTERN 396-427)
# PNG 64x32 = 2 frames 32x32 lado a lado. Preto (0,0,0) = transparente.
# Cores da arte (palette Lospec NES): (68,40,188)=$03 roxo, (152,120,248)=$23
# lilas, (248,216,120)=$38 dourado -> bits 1/2/3; renderizadas via pal2
# (VPOKE $3F19-1B no inicio da onda do miniboss, restaurada ao morrer).
# Cada frame = 8 sprites 8x16: fileira de cima PATTERN 396..402(+2),
# fileira de baixo 404..410(+2); frame B = 412..426. Byte OAM = 141+.
from PIL import Image

SRC = '/home/user/uploads/miniboss-1.png'

def classifica(r, g, b, a):
    if r < 40 and g < 40 and b < 40:
        return 0                    # preto = transparente
    if r > 200:                     # dourado claro
        return 3
    if r > 100:                     # lilas claro
        return 2
    return 1                        # roxo escuro

im = Image.open(SRC).convert('RGBA')
px = im.load()
frames = []
for f in range(2):
    grid = [[classifica(*px[f * 32 + x, y]) for x in range(32)]
            for y in range(32)]
    frames.append(grid)

# preview (cores da arte)
CH = {0: (16, 16, 24), 1: (68, 40, 188), 2: (152, 120, 248), 3: (248, 216, 120)}
prev = Image.new('RGB', (64, 32), CH[0])
for f in range(2):
    for y in range(32):
        for x in range(32):
            prev.putpixel((f * 32 + x, y), CH[frames[f][y][x]])
prev.resize((320, 160), Image.NEAREST).save('/tmp/miniboss_nes.png')

# gera bloco CVBasic
PL = {0: '.', 1: '1', 2: '2', 3: '3'}
out = []
out.append("\t' MINIBOSS do Saulo (miniboss-1.png: 32x32, 2 frames, pal2;\n")
out.append("\t' gera_miniboss.py). Onda a cada 4; o codigo troca pal2 p/\n")
out.append("\t' $03/$23/$38 (cores exatas da arte) e restaura ao morrer.\n")
out.append("\t' OAM: frame A = bytes 141-155, frame B = 157-171.\n")
for f in range(2):
    for fil in range(2):                    # 0 = metade de cima, 1 = baixo
        for col in range(4):
            tspr = 396 + f * 16 + fil * 8 + col * 2
            byte = 2 * ((tspr - 256) // 2) + 1
            out.append("\tCHRROM PATTERN %d\n" % tspr)
            out.append("\t' miniboss f%d %s col%d (byte OAM %d)\n"
                       % (f, 'top' if fil == 0 else 'bot', col, byte))
            for y in range(16):
                row = frames[f][fil * 16 + y]
                out.append('\tBITMAP "' + ''.join(PL[row[col * 8 + x]]
                           for x in range(8)) + '"\n')
open('/tmp/miniboss_tiles.bas', 'w').writelines(out)
print('tiles gerados: %d linhas' % len(out))
