#!/usr/bin/env python3
# v0.12/13/14: cota 3 tiros small + laser do miniboss em 3 pontos (v0.14)
#             + anel OAM anti-falha (flicker justo)         (boss -> v13_boss2.py)
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

run(120)
held.add(BT['START']); run(6); held.discard(BT['START'])   # v0.16: pula a splash
run(40)
held.add(BT['START']); run(6); held.discard(BT['START'])   # v0.16: start no titulo
run(40)
held.add(BT['START']); run(6); held.discard(BT['START'])   # v0.18: corta o cartao FASE 01
run(30)

# ============ 1) cota: MAX 3 tiros de small na tela ============
while not (ram[A['WTIPO']] == 0 and ram[A['WACT']] == 1):
    run()
nsm_max = 0
spawns_sm = 0
prev_act = [0]*6
f = 0
while ram[A['WTIPO']] == 0 and ram[A['WACT']] and f < 900:
    run(); f += 1
    nsm_max = max(nsm_max, ram[A['NSM']])
    for c in range(6):
        a = ram[A['SMA']+c]
        if a and not prev_act[c]: spawns_sm += 1
        prev_act[c] = a
check(nsm_max <= 3, f'cota de tiros do small respeitada (max={nsm_max})')
check(nsm_max >= 2, f'cota chegou a ser usada (max={nsm_max})')
check(spawns_sm == 6, f'onda ainda tem 6 smalls ({spawns_sm})')
shot('v12_small_cota')

# ============ 1b) anel OAM anti-falha (v0.14: flicker justo) ============
RING = [4,5,6,7,8,9,10,11,12,13,14,15,21,22,23,24]
r16 = [ram[A['R16']+i] for i in range(16)]
check(r16 == RING, 'anel de slots fisicos carregado no boot')
# forca o pior caso: 6 smalls vivos na MESMA faixa de scanline
ys = (122+256)*16
for c in range(6):
    ram[A['SMA']+c] = 1
    ram[A['SMP']+c] = 40 + c*30
    ram[A['SMC']+c] = 0
    ram[A['SMZ']+c] = 0
    ram[A['SNV']+c] = 0
    ram[A['#SMY']+c*2] = ys & 255
    ram[A['#SMY']+c*2+1] = ys >> 8
run(2)
# censo frame a frame (24 frames = 1 giro completo do rodizio)
slots0 = set()
ok12 = True
rrs = set()
for _ in range(32):
    run()
    rrs.add(ram[A['RR']])
    tiles = [(s, ram[0x200+s*4+1]) for s in range(4, 33)]	# OAM: +1 = TILE
    halves = [s for s, t in tiles if t in (113, 115)]
    if len(halves) != 12: ok12 = False
    for s, t in tiles:
        if t == 113 and abs(ram[0x200+s*4+3] - 40) <= 2:
            slots0.add(s)
check(ok12, '12 metades de small SEMPRE escritas (always-write, sem fantasma)')
check(len(rrs) >= 14, f'contador do rodizio gira ({len(rrs)} valores em 24f)')
check(len(slots0) >= 8, f'slot fisico do small-0 rodiza ({len(slots0)} slots em 32f)')
# mata todos: cada um esconde o proprio slot mapeado (senao sobra fantasma)
for c in range(6):
    ram[A['SMA']+c] = 0
run(2)
leftover = sum(1 for s in range(4, 33) if ram[0x200+s*4+1] in (113, 115))
check(leftover == 0, f'mortos escondem o slot mapeado (restaram {leftover})')

# ============ 2) miniboss: parque em y=72 + laser em 3 pontos (v0.14) ============
while not ram[A['MBA']]:
    run()
while ram[A['MBS']] == 1:
    run()
ytop = round(u16(A['#MBY'])/16 - 256)
check(71 <= ytop <= 73, f'miniboss estaciona acima do meio (y={ytop})')
# coleta os pontos de disparo por ~900 frames (2+ passeios completos: 368f cada)
pts = set()
f = 0
while f < 900 and len(pts) < 3:
    run(); f += 1
    if ram[A['MLR']] == 1:
        pts.add(ram[A['MLX']] - 8)      # mlx = mbx + 8
        while ram[A['MLR']]:
            run(); f += 1
        f += 1
check(pts <= {16, 112, 200}, f'laser so dispara no centro/extremos ({sorted(pts)})')
check(len(pts) >= 2, f'laser dispara em pontos variados do passeio ({sorted(pts)} em {f}f)')
shot('v12_mb_laser')
# velocidade do proximo laser: 6px/frame
while not ram[A['MLR']]:
    run()
check(ram[A['MLX']] - 8 in {16, 112, 200}, f'laser nasce num ponto do ciclo (mlx={ram[A["MLX"]]})')
y1 = u16(A['#MLY'])
run(4)
y2 = u16(A['#MLY'])
vel = (y2 - y1)/4/16
check(5.5 < vel < 6.5, f'laser desce rapido ({vel:.1f} px/frame)')
# sai da tela e desliga
f = 0
while ram[A['MLR']] and f < 120:
    run(); f += 1
check(ram[A['MLR']] == 0, 'laser desliga ao sair da tela')
run(2)	# o esconde (ELSE) so' roda no frame seguinte ao mlr=0
check(ram[0x200 + 57*4] == 0xF0, 'sprites do laser escondidos')
# colisao: proximo laser mata a nave
f = 0
while not ram[A['MLR']] and f < 500:
    run(); f += 1
check(f < 500, 'laser seguinte acontece (patrulha continua)')
ram[A['PX']] = ram[A['MLX']] + 4
ram[A['PY']] = 90
INV_MODE['on'] = False
ram[A['INV']] = 0
run(2)
check(ram[A['DED']] > 0, 'laser do miniboss MATA a nave')
INV_MODE['on'] = True
run(60)

# (o BOSS mudou de forma na v0.13: testes novos em v13_boss2.py)

print('RESULTADO:', 'TUDO OK' if not fails else f'{len(fails)} FALHAS: {fails}')
