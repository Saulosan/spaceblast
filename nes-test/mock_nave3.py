#!/usr/bin/env python3
"""Mock v3: nave em 'camadas' (body cinza + canopy azul + chama verde/laranja)."""
from PIL import Image, ImageDraw
import sys
sys.path.insert(0, '/home/user/nes-test')
from mock_nave import NES, nearest_idx, im

PAL_CINZA = [0x00, 0x10, 0x30]
PAL_CANOPY = [0x16, 0x21, 0x30]   # luzes vermelhas + vidro azul + brilho branco
PAL_CHAMA  = [0x19, 0x2A, 0x30]   # verdes + nucleo branco
PAL_WARM   = [0x16, 0x27, 0x30]   # chama laranja (mesma da explosao)

def classifica(c):
    r, g, b = c[0], c[1], c[2]
    if g > r + 25 and g > b + 25: return 'verde'
    if b > r + 25 and b > g + 10: return 'azul'
    if r > g + 20 and r > b + 20: return 'vermelho'
    return 'neutro'

def camada(px, w, h, regiao, alvo, pal):
    """devolve imagem RGBA com os pixels da classe alvo dentro da regiao, quantizados p/ pal"""
    x0, y0, x1, y1 = regiao
    out = Image.new('RGBA', (x1-x0, y1-y0), (0, 0, 0, 0))
    o = out.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = px[x, y]
            if c[3] >= 128 and classifica(c) in alvo:
                o[x-x0, y-y0] = NES[pal[nearest_idx(c, pal)]] + (255,)
    return out

def nave(fi, tam, variante):
    if tam == 24:
        base = im.crop((fi*32+4, 0, fi*32+28, 30)).resize((24, 32), Image.NEAREST)
        w, h = 24, 32
        reg_c, reg_f = (8, 0, 16, 16), (8, 16, 16, 32)
    else:
        base = im.crop((fi*32+4, 0, fi*32+28, 30)).resize((16, 16), Image.NEAREST)
        w, h = 16, 16
        reg_c = reg_f = (4, 0, 12, 16)
    px = base.load()
    # corpo: tudo quantizado p/ cinzas
    body = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    b = body.load()
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] >= 128:
                b[x, y] = NES[PAL_CINZA[nearest_idx(c, PAL_CINZA)]] + (255,)
    out = body
    if variante == 'A':
        can = camada(px, w, h, reg_c, ('azul', 'vermelho'), PAL_CANOPY)
        fla = camada(px, w, h, reg_f, ('verde',), PAL_CHAMA)
    else:
        can = camada(px, w, h, reg_c, ('vermelho',), PAL_WARM)
        fla = camada(px, w, h, reg_f, ('verde',), PAL_WARM)
    out.paste(can, (reg_c[0], reg_c[1]), can)
    out.paste(fla, (reg_f[0], reg_f[1]), fla)
    return out

if __name__ == '__main__':
    poses = [('IDLE', 0), ('ESQ', 6), ('DIR', 9)]
    variantes = [('A24', 24, 'A'), ('B24', 24, 'B'), ('A16', 16, 'A'), ('B16', 16, 'B')]
    E = 6
    rowh = 32*E + 30
    colw = 200
    sheet = Image.new('RGB', (40 + len(variantes)*colw, rowh*len(poses) + 26), (24, 24, 36))
    d = ImageDraw.Draw(sheet)
    for r, (nome, fi) in enumerate(poses):
        y = 10 + r*rowh
        d.text((10, y), nome, fill=(255, 255, 0))
        orig = im.crop((fi*32, 0, fi*32+32, 32)).resize((32*E, 32*E), Image.NEAREST)
        sheet.paste(orig, (30, y+14), orig)
        for k, (vnome, tam, va) in enumerate(variantes):
            m = nave(fi, tam, va)
            mz = m.resize((tam*E, (32 if tam == 24 else 16)*E), Image.NEAREST)
            x = 30 + 36*E + k*colw
            d.text((x, y), vnome, fill=(120, 220, 255))
            sheet.paste(mz, (x, y+14), mz)
    txt = 'original 32x32   A24: azul+verde (5-8 sprites)   B24: cinza+laranja (idem)   A16: azul+verde (4 sp)   B16: cinza+laranja (3 sp)'
    d.text((30, rowh*len(poses) + 6), txt, fill=(220, 220, 220))
    sheet.save('/home/user/cata-estrelas/docs/mock_nave.png')
    print('ok mock_nave v3')

    jogo = Image.open('/home/user/cata-estrelas/docs/2_gameplay.png').convert('RGB')
    a = jogo.copy(); m16 = nave(0, 16, 'A'); a.paste(m16, (104, 184), m16)
    b = jogo.copy(); m24 = nave(0, 24, 'A'); b.paste(m24, (100, 176), m24)
    comp = Image.new('RGB', (2*256+10, 240+26), (255, 255, 255))
    dd = ImageDraw.Draw(comp)
    comp.paste(a, (0, 22)); comp.paste(b, (256+10, 22))
    dd.text((100, 4), 'A16 no jogo', fill=(0, 0, 0)); dd.text((256+100, 4), 'A24 no jogo', fill=(0, 0, 0))
    comp.save('/home/user/cata-estrelas/docs/mock_jogo.png')
    print('ok mock_jogo v3')
