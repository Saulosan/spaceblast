#!/usr/bin/env python3
"""Mocks da nave do usuario quantizada p/ NES (2C02), opcoes 16x16 e 24x32."""
from PIL import Image, ImageDraw

# paleta mestra 2C02 (blargg)
NES = [
 (84,84,84),(0,30,116),(8,16,144),(48,0,136),(68,0,100),(92,0,48),(84,4,0),(60,24,0),
 (32,42,0),(8,58,0),(0,64,0),(0,60,0),(0,50,60),(0,0,0),(0,0,0),(0,0,0),
 (152,150,152),(8,76,196),(48,50,236),(92,30,228),(136,20,176),(160,20,100),(152,34,32),(120,60,0),
 (84,90,0),(40,114,0),(8,144,0),(0,144,0),(0,130,60),(0,0,0),(0,0,0),(0,0,0),
 (236,238,236),(76,154,236),(120,124,236),(176,98,236),(228,84,236),(236,88,180),(236,106,100),(212,136,32),
 (160,170,0),(116,196,0),(76,208,32),(56,204,108),(56,180,204),(60,60,60),(0,0,0),(0,0,0),
 (236,238,236),(168,204,236),(188,188,236),(212,178,236),(236,174,236),(236,174,212),(236,180,176),(228,196,144),
 (204,210,120),(180,222,120),(168,226,144),(152,226,180),(160,214,228),(160,162,160),(0,0,0),(0,0,0)]

# paletas de sprite propostas (3 tons cada, entrada 0 = transparente)
PAL_CINZA = [0x00, 0x10, 0x30]   # cinza esc, prata, branco
PAL_AZUL  = [0x11, 0x21, 0x31]   # azul esc, azul, azul claro
PAL_VERDE = [0x19, 0x2A, 0x3A]   # verde esc, verde, verde claro
PALS = [PAL_CINZA, PAL_AZUL, PAL_VERDE]

def nearest_idx(c, pal):
    best, bd = 0, 1 << 62
    for i, p in enumerate(pal):
        r, g, b = NES[p]
        d = (c[0]-r)**2 + (c[1]-g)**2 + (c[2]-b)**2
        if d < bd: bd, best = d, i
    return best

def quant_cell(px, x0, y0, w, h):
    """quantiza uma celula w x h p/ a melhor das 3 paletas; devolve (pal_id, indices)"""
    dados = [(x, y, px[x0+x, y0+y]) for y in range(h) for x in range(w) if px[x0+x, y0+y][3] >= 128]
    if not dados: return 0, [[-1]*w for _ in range(h)]
    melhor, be = None, None
    for pid, pal in enumerate(PALS):
        e = 0
        for _, _, c in dados:
            bd = min(((c[0]-NES[p][0])**2 + (c[1]-NES[p][1])**2 + (c[2]-NES[p][2])**2) for p in pal)
            e += bd
        if be is None or e < be: be, melhor = e, pid
    pal = PALS[melhor]
    idx = [[-1]*w for _ in range(h)]
    for x, y, c in dados:
        idx[y][x] = nearest_idx(c, pal)
    return melhor, idx

def render_cell(idx, pal, escala):
    w, h = len(idx[0]), len(idx)
    out = Image.new('RGBA', (w*escala, h*escala), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    for y in range(h):
        for x in range(w):
            if idx[y][x] >= 0:
                r, g, b = NES[pal[idx[y][x]]]
                d.rectangle([x*escala, y*escala, x*escala+escala-1, y*escala+escala-1], fill=(r, g, b, 255))
    return out

def mock_frame(im, fi, modo):
    """modo '16' -> 16x16 (2 celulas 8x16); modo '24' -> 24x32 (6 celulas 8x16)"""
    fr = im.crop((fi*32, 0, fi*32+32, 32))
    if modo == '16':
        rs = fr.resize((16, 16), Image.NEAREST)
        px = rs.load()
        celulas = [quant_cell(px, 0, 0, 8, 16), quant_cell(px, 8, 0, 8, 16)]
        out = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
        for i, (pid, idx) in enumerate(celulas):
            out.paste(render_cell(idx, PALS[pid], 1), (i*8, 0))
        return out, [PALS[p] for p, _ in celulas]
    else:
        rs = fr.crop((4, 0, 28, 30)).resize((24, 32), Image.NEAREST)  # borda 4..27, enche 30->32
        px = rs.load()
        out = Image.new('RGBA', (24, 32), (0, 0, 0, 0))
        usadas = []
        for cy in range(2):
            for cx in range(3):
                pid, idx = quant_cell(px, cx*8, cy*16, 8, 16)
                out.paste(render_cell(idx, PALS[pid], 1), (cx*8, cy*16))
                usadas.append(PALS[pid])
        return out, usadas

im = Image.open('/home/user/uploads/player.png').convert('RGBA')
poses = [('IDLE', 0), ('ESQ', 6), ('DIR', 9), ('IDLE chama+', 3), ('ESQ chama', 12), ('DIR chama', 17)]
E = 5  # escala do zoom
larg = 3*40 + 30
sheet = Image.new('RGB', (len(poses)*larg + 70, 4*E*32 + 46), (24, 24, 36))
d = ImageDraw.Draw(sheet)
for col, (nome, fi) in enumerate(poses):
    x = 10 + col*larg
    d.text((x, 3), nome, fill=(255, 255, 0))
    orig = im.crop((fi*32, 0, fi*32+32, 32)).resize((32*E, 32*E), Image.NEAREST)
    m16, p16 = mock_frame(im, fi, '16'); m16z = m16.resize((16*E, 16*E), Image.NEAREST)
    m24, p24 = mock_frame(im, fi, '24'); m24z = m24.resize((24*E, 32*E), Image.NEAREST)
    sheet.paste(orig, (x, 16), orig)
    sheet.paste(m24z, (x + 38*E - 12*E, 16), m24z)
    sheet.paste(m16z, (x + 62*E + 8*E, 16 + 8*E), m16z)
d.text((10, 16 + 33*E), 'orig 32x32    NES 24x32    NES 16x16', fill=(200, 200, 200))
sheet.save('/home/user/cata-estrelas/docs/mock_nave.png')
print('mock_nave ok')

# --- mock in-game: substitui a nave na screenshot real do gameplay ---
jogo = Image.open('/home/user/cata-estrelas/docs/2_gameplay.png').convert('RGB')
m16, _ = mock_frame(im, 0, '16'); m24, _ = mock_frame(im, 0, '24')
a = jogo.copy(); a.paste(m16, (104, 184), m16)
b = jogo.copy(); b.paste(m24, (100, 176), m24)
comp = Image.new('RGB', (2*256 + 8, 240), (255, 255, 255))
comp.paste(a, (0, 0)); comp.paste(b, (256+8, 0))
comp.save('/home/user/cata-estrelas/docs/mock_jogo.png')
zx = comp.crop((60, 150, 170, 230)).resize((110*3, 80*3), Image.NEAREST)
zx2 = b.crop((60, 150, 170, 230)).resize((110*3, 80*3), Image.NEAREST)
zoom = Image.new('RGB', (zx.width, zx.height*2 + 6), (255, 255, 255))
zoom.paste(zx, (0, 0)); zoom.paste(zx2, (0, zx.height+6))
zoom.save('/home/user/cata-estrelas/docs/mock_jogo_zoom.png')
print('mock_jogo ok')
