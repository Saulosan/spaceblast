#!/usr/bin/env python3
"""Mock v2: nave 24x32 com paletas forcadas por regiao (canopy azul / chama verde)."""
from PIL import Image, ImageDraw
import sys
sys.path.insert(0, '/home/user/nes-test')
from mock_nave import NES, nearest_idx, im

PAL_CINZA  = [0x00, 0x10, 0x30]   # pal0: casco
PAL_CANOPY = [0x11, 0x21, 0x30]   # pal1: vidro azul c/ branco  (contorno sai no azul esc)
PAL_CHAMA  = [0x19, 0x2A, 0x30]   # pal2: verdes c/ branco

def quant_com_pal(px, x0, y0, w, h, pal):
    idx = [[-1]*w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            c = px[x0+x, y0+y]
            if c[3] >= 128:
                idx[y][x] = nearest_idx(c, pal)
    return idx

def render(idx, pal, escala):
    w, h = len(idx[0]), len(idx)
    out = Image.new('RGBA', (w*escala, h*escala), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    for y in range(h):
        for x in range(w):
            if idx[y][x] >= 0:
                r, g, b = NES[pal[idx[y][x]]]
                d.rectangle([x*escala, y*escala, (x+1)*escala-1, (y+1)*escala-1], fill=(r, g, b, 255))
    return out

def mock24(fi):
    fr = im.crop((fi*32, 0, fi*32+32, 32))
    rs = fr.crop((4, 0, 28, 30)).resize((24, 32), Image.NEAREST)
    px = rs.load()
    # grade 3 col x 2 linhas de celulas 8x16; coluna do meio = canopy (cima) / chama (baixo)
    mapa = [[PAL_CINZA, PAL_CANOPY, PAL_CINZA], [PAL_CINZA, PAL_CHAMA, PAL_CINZA]]
    out = Image.new('RGBA', (24, 32), (0, 0, 0, 0))
    for cy in range(2):
        for cx in range(3):
            pal = mapa[cy][cx]
            idx = quant_com_pal(px, cx*8, cy*16, 8, 16, pal)
            out.paste(render(idx, pal, 1), (cx*8, cy*16))
    return out

def mock16(fi):
    fr = im.crop((fi*32, 0, fi*32+32, 32))
    conteudo = fr.crop((4, 0, 28, 30))
    rs = conteudo.resize((16, 16), Image.NEAREST)
    px = rs.load()
    out = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for cx in range(2):
        idx = quant_com_pal(px, cx*8, 0, 8, 16, PAL_CINZA)
        out.paste(render(idx, PAL_CINZA, 1), (cx*8, 0))
    return out

poses = [('IDLE', 0), ('ESQ', 6), ('DIR', 9), ('IDLE chama', 3)]
E = 6
rowh = 32*E + 30
sheet = Image.new('RGB', (620, rowh*len(poses) + 26), (24, 24, 36))
d = ImageDraw.Draw(sheet)
for r, (nome, fi) in enumerate(poses):
    y = 10 + r*rowh
    d.text((10, y), nome, fill=(255, 255, 0))
    orig = im.crop((fi*32, 0, fi*32+32, 32)).resize((32*E, 32*E), Image.NEAREST)
    m24 = mock24(fi); m16 = mock16(fi)
    sheet.paste(orig, (30, y+14), orig)
    sheet.paste(m24.resize((24*E, 32*E), Image.NEAREST), (30 + 36*E, y+14), m24.resize((24*E, 32*E), Image.NEAREST))
    sheet.paste(m16.resize((16*E, 16*E), Image.NEAREST), (30 + 64*E, y+14 + 8*E), m16.resize((16*E, 16*E), Image.NEAREST))
d.text((30, rowh*len(poses) + 6), '    original 32x32        NES 24x32 (canopy azul, chama verde)      NES 16x16', fill=(220, 220, 220))
sheet.save('/home/user/cata-estrelas/docs/mock_nave.png')
print('ok')
