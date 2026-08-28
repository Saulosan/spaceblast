#!/usr/bin/env python3
# v0.13: BOSS 100% BG ($1000, flip ppu_ctrl), ceu preto, balanco +-16px,
#        pulso de paleta, 3 fases com origens acompanhando o balanco,
#        +5000, restaura tudo; game-over durante o boss legivel.
import ctypes, sys
from PIL import Image
sys.path.insert(0, '/home/user/nes-test')
from addrs_cb import ADDR as A

core = ctypes.CDLL('/tmp/cb/fceumm_libretro.so')
ENVF = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
VIDF = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)
AUDF = ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)
AUDB = ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
INPF = ctypes.CFUNCTYPE(None)
INSF = ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)
frame = []
held = set()
def envf(cmd, data):
    if cmd == 10: ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value = 1; return True
    if cmd == 11: ctypes.cast(data, ctypes.POINTER(ctypes.c_bool)).contents.value = True; return True
    if cmd in (16,17): return True
    return False
def vidf(d, w, h, p): frame[:] = [(w, ctypes.string_at(d, w*h*4))]
def audf(l, r): pass
def audb(d, n): return n
def inpf(): pass
def insf(port, dev, idx, i): return 1 if (port == 0 and i in held) else 0
_cb = ENVF(envf), VIDF(vidf), AUDF(audf), AUDB(audb), INPF(inpf), INSF(insf)
class RGI(ctypes.Structure):
    _fields_ = [('path', ctypes.c_char_p), ('data', ctypes.c_void_p), ('size', ctypes.c_size_t), ('meta', ctypes.c_char_p)]
core.retro_set_environment(_cb[0]); core.retro_set_video_refresh(_cb[1])
core.retro_set_audio_sample(_cb[2]); core.retro_set_audio_sample_batch(_cb[3])
core.retro_set_input_poll(_cb[4]); core.retro_set_input_state(_cb[5])
core.retro_load_game.argtypes = [ctypes.POINTER(RGI)]; core.retro_load_game.restype = ctypes.c_bool
core.retro_get_memory_data.restype = ctypes.c_void_p
core.retro_init()
gi = RGI(b'/home/user/spaceblast/space-blast.nes', None, 0, None)
assert core.retro_load_game(ctypes.byref(gi))
ram = (ctypes.c_ubyte * 2048).from_address(core.retro_get_memory_data(2))
BT = {'B':0, 'SEL':2, 'START':3, 'UP':4, 'DOWN':5, 'LEFT':6, 'RIGHT':7}
INV_MODE = {'on': True}
def run(n=1):
    for _ in range(n):
        core.retro_run()
        if INV_MODE['on']:
            ram[A['INV']] = 3
def u16(a): return ram[a] | (ram[a+1] << 8)
def shot(name):
    w, buf = frame[-1]
    Image.frombytes('RGB', (w, 240), buf, 'raw', 'BGRX').save(f'/tmp/cb/{name}.png')
fails = []
def check(cond, msg):
    print(('OK  ' if cond else 'FALHA') + ' ' + msg)
    if not cond: fails.append(msg)
def img_rgb():
    w, buf = frame[-1]
    return Image.frombytes('RGB', (w,240), buf, 'raw', 'BGRX')

run(120)
held.add(BT['START']); run(6); held.discard(BT['START'])   # v0.16: pula a splash
run(40)
held.add(BT['START']); run(6); held.discard(BT['START'])   # v0.16: start no titulo
run(40)
held.add(BT['START']); run(6); held.discard(BT['START'])   # v0.18: corta o cartao FASE 01
run(30)

# ============ BOSS: warp-in ceu preto + flip p/ $1000 ============
ram[A['NSMA']] = 4; ram[A['NSHA']] = 4; ram[A['NE4']] = 4
for c in range(6): ram[A['SMA']+c] = 0
for c in range(4): ram[A['SHA']+c] = 0
for c in range(8): ram[A['E4A']+c] = 0
f = 0
while not ram[A['BSA']] and f < 300:
    run(); f += 1
check(ram[A['BSA']] == 1, f'BOSS chega com 4 de cada onda ({f}f)')
check(ram[A['BSHP']] == 120, 'HP do boss = 120')
run(80)   # sky_clear (60f) + boss_write (~6f) + folga
check(ram[0x16] == 0xB8, 'ppu_ctrl=$B8: BG lendo a tabela $1000')
# ceu preto fora do boss (amostra: canto inferior esquerdo e direito)
im = img_rgb()
pretos = 0; total = 0
for y in (150, 200):
    for x in range(8, 56, 8):
        total += 1
        if im.getpixel((x, y)) in ((16,16,16),(0,0,0)): pretos += 1
check(pretos == total, f'ceu 100% preto na luta ({pretos}/{total})')
# balanco: coluna mais a esquerda do corpo muda com o tempo
def col_esq():
    im = img_rgb()
    for y in range(28, 84, 4):
        for x in range(48, 208):
            if im.getpixel((x, y)) not in ((16,16,16),(0,0,0)): return x
    return -1
run(8)
x0 = col_esq()
run(64)
x1 = col_esq()
check(x0 != -1 and x1 != -1 and x0 != x1, f'boss BALANCA lateralmente ({x0}->{x1})')
check(x0 != -1 and 56 <= x0 <= 88, f'boss no alto e centrado (esq={x0})')
shot('v13_boss_chegada')

# fase 1: leques alternados acompanhando o balanco (~84/~156 +-16)
fans = []   # 1 entrada POR leque (rafe de 3 tiros no mesmo frame)
prev_live = [ram[A['EBA']+i] for i in range(8)]
f = 0
while len(fans) < 8 and f < 2500:
    run(); f += 1
    live = [ram[A['EBA']+i] for i in range(8)]
    news = [i for i in range(8) if live[i] and not prev_live[i]]
    prev_live = live
    if len(news) >= 2 and ram[A['BSPH']] == 1:
        xs = [round(u16(A['#EBX']+i*2)/16 - 256) for i in news]
        fans.append(round(sum(xs)/len(xs)))
    if ram[A['BSPH']] == 2 and len(fans) < 8:
        break
print('leques da fase 1:', fans)
lados = [1 if x > 120 else 0 for x in fans]
alterna = len(fans) >= 2 and all(lados[i] != lados[i+1] for i in range(len(lados)-1))
perto = all(min(abs(x-84), abs(x-156)) <= 19 for x in fans)
check(alterna, 'leques alternam as asas')
check(perto, 'leques nascem nas asas (acompanham o balanco)')

fase2_em = None
f = 0
while f < 3000:
    run(); f += 1
    if ram[A['BSPH']] == 2 and fase2_em is None: fase2_em = f
    if ram[A['BSPH']] == 3:
        break
check(fase2_em is not None, 'ENTROU na fase 2 (saraivada)')
check(ram[A['BSPH']] == 3, 'ENTROU na fase 3 (lasers)')
# laser gemeo do meio: sprites 61/62 na base dele, acompanhando o balanco
f = 0
while not ram[A['BOL']] and f < 300:
    run(); f += 1
check(ram[A['BOL']] == 1, 'fase 3 dispara o laser gemeo')
ox1 = ram[0x200 + 61*4 + 3]; ox2 = ram[0x200 + 62*4 + 3]
bo = ram[A['BOFF']]
b_bo = bo if bo < 128 else bo - 256
check(ox2 - ox1 == 8, f'lasers gemeos 8px apart ({ox1},{ox2})')
check(abs(ox1 - ((112 + bo) % 256)) <= 1, f'laser acompanha o balanco ({ox1} vs 112{b_bo:+d})')
y1 = u16(A['#BOY'])
run(4)
y2 = u16(A['#BOY'])
check((y2 - y1)/4/16 > 5.5, f'laser do boss desce rapido ({(y2-y1)/4/16:.1f} px/f)')
lasers = 0; prev_bol = 0; f = 0; volta1 = None
while f < 2000:
    run(); f += 1
    if ram[A['BOL']] and not prev_bol: lasers += 1
    prev_bol = ram[A['BOL']]
    if ram[A['BSPH']] == 1:
        volta1 = f
        break
check(lasers == 3, f'fase 3 dispara 3 lasers ({lasers})')
check(volta1 is not None, 'ciclo volta para a fase 1')
shot('v13_boss_fases')

# dano por tiro do jogador (janela 24..88 + balanco)
hp0 = ram[A['BSHP']]
slot = next(i for i in range(5) if ram[A['BTY']+i] == 0)
ram[A['BTX']+slot] = 116
ram[A['BTY']+slot] = 92
f = 0
while ram[A['BSHP']] == hp0 and f < 12:
    run(); f += 1
check(ram[A['BSHP']] == hp0 - 1, f'tiro tira 1 HP do boss ({hp0}->{ram[A["BSHP"]]})')
# morte: +5000, ppu_ctrl volta, restaura cenario, zera contadores
ram[A['BSHP']] = 1
slot = next(i for i in range(5) if ram[A['BTY']+i] == 0)
ram[A['BTX']+slot] = 116
ram[A['BTY']+slot] = 92
s1_0 = ram[A['S1']]
f = 0
while ram[A['BSA']] and f < 12:
    run(); f += 1
check(ram[A['BSA']] == 0, 'boss MORRE')
check(ram[0x16] == 0xA8, 'ppu_ctrl=$A8: BG volta p/ $0000 ao morrer')
f = 0
while ram[A['S1']] == s1_0 and f < 80:
    run(); f += 1
check((ram[A['S1']] - s1_0) % 10 == 5, f'+5000 pontos (s1 {s1_0}->{ram[A["S1"]]})')
check(ram[A['NSMA']] == 0 and ram[A['NSHA']] == 0 and ram[A['NE4']] == 0,
      f'contadores zerados (esperou {f}f pelo fim da cerimonia)')
run(90)
check(ram[A['WACT']] == 1, 'onda seguinte comeca apos o boss')
scroll_depois = ram[0x1A]
run(30)
check(ram[0x1A] != scroll_depois, 'scroll VOLTA a rolar')
shot('v13_boss_morto')

print('RESULTADO:', 'TUDO OK' if not fails else f'{len(fails)} FALHAS: {fails}')
