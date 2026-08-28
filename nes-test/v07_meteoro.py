#!/usr/bin/env python3
# v0.7: teste da onda Enemy4 (meteoro). Mata ondas anteriores via RAM p/
# acelerar o rodizio ate wtipo=2. Verifica: 4 spawns em colunas distintas
# {32,88,144,200}, intervalo ~90f, travessia lenta, kill 300pts, e o ciclo
# de ondas (2 -> 0).
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
def vidf(d, w, h, p): frame.append((w, ctypes.string_at(d, w*h*4)))
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
IDS = {'B': 0, 'START': 3, 'LEFT': 6, 'RIGHT': 7}
def run(n):
    for _ in range(n): core.retro_run()
def shot(name):
    w, buf = frame[-1]
    Image.frombytes('RGB', (w, 240), buf, 'raw', 'BGRX').save(f'/tmp/cb/{name}.png')
def u16(a): return ram[a] | (ram[a+1] << 8)

fails = []
def check(cond, msg):
    print(('OK  ' if cond else 'FALHA') + ' ' + msg)
    if not cond: fails.append(msg)

run(120)                                   # titulo
held.add(IDS['START']); run(6); held.discard(IDS['START'])
run(120)

# deixa as ondas small/shard terminarem sozinhas (sem atirar, nave parada
# em x=120 fora das colunas do meteoro) ate o rodizio chegar em wtipo=2
gf = 0
while not (ram[A['WTIPO']] == 2 and ram[A['WACT']] == 1):
    run(1); gf += 1
    if gf > 4000: break
print('frames ate onda meteoro:', gf, '| wtipo =', ram[A['WTIPO']])
check(ram[A['WTIPO']] == 2, 'rodizio chegou na onda enemy4 (wtipo=2)')

# espioes de spawn: registra (frame, slot, x) quando e4a liga
prev = [0]*4
spawns = []
for f in range(400):
    run(1)
    for c in range(4):
        a = ram[A['E4A']+c]
        if a and not prev[c]:
            spawns.append((f, c, ram[A['E4X']+c], ram[A['E4V']]))
        prev[c] = a
    if len(spawns) == 4: break
print('spawns:', spawns)
xs = sorted(s[2] for s in spawns)
check(len(spawns) == 4, '4 meteoros spawnaram')
check(xs == [32, 88, 144, 200], f'colunas embaralhadas sem repeticao: {xs}')
if len(spawns) >= 2:
    gaps = [spawns[i+1][0]-spawns[i][0] for i in range(len(spawns)-1)]
    check(all(85 <= g <= 95 for g in gaps), f'intervalo ~90f (1.5s): {gaps}')
check(spawns[0][0] < 40, f'primeiro meteoro rapido (~30f): {spawns[0][0]}f')

# travessia: velocidade em px/frame medida
run(30)
y0 = [u16(A['E4Y']+c*2) for c in range(4)]
run(60)
y1 = [u16(A['E4Y']+c*2) for c in range(4)]
vel = [(y1[c]-y0[c])/60/16 for c in range(4)]
print('velocidade px/frame:', [round(v, 2) for v in vel])
check(all(0.4 < v < 1.2 and abs(vel[0]-v) < 0.01 for v in vel), 'descida lenta e uniforme')
w, buf = frame[-1]
shot('meteoro_meio')

# kill: injeta bala alinhada no meteoro mais recente visivel (testa colisao+pontos)
s2_0, s3_0 = ram[A['S2']], ram[A['S3']]
alvo = -1
for c in range(4):
    if ram[A['E4A']+c]:
        yc = u16(A['E4Y']+c*2)/16 - 256
        if 8 < yc < 160: alvo = (c, int(yc))
check(alvo != -1, 'meteoro alvo na faixa p/ teste de tiro')
c, yc = alvo
x0 = ram[A['E4X']+c]
ram[A['BTX']] = x0 + 4
ram[A['BTY']] = yc + 8          # dentro da janela (yc-8 .. yc+16): a bala
run(1)                          # sobe 4px/frame ANTES da checagem!
check(ram[A['E4A']+c] == 0, 'meteoro morreu com o tiro')
check(ram[A['S2']] - s2_0 == 3 or (ram[A['S2']] != s2_0 and ram[A['S3']] != s3_0),
      f'pontuou +300 (s2 {s2_0}->{ram[A["S2"]]}, s3 {s3_0}->{ram[A["S3"]]})')
check(ram[A['MPT']] >= 8, 'mini-explosao disparada')
run(12)
shot('meteoro_explosao')

# travessia completa: demais escapam por baixo -> onda termina -> wtipo volta p/ 0
escaped = 0
for f in range(900):
    run(1)
    if ram[A['WACT']] == 0: break
check(ram[A['WACT']] == 0, 'onda terminou (meteoros escaparam/morreram)')
check(ram[A['WTIPO']] == 0, f'rodizio continuou p/ small (wtipo={ram[A["WTIPO"]]})')
run(200)
shot('meteoro_depois')

print()
print('RESULTADO:', 'TUDO OK' if not fails else f'{len(fails)} FALHAS: {fails}')
