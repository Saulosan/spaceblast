#!/usr/bin/env python3
# v0.8 -> v0.11: suite e4/shard/HUD/small/miniboss
#   v0.11: small em onda 3+3 (lados opostos) + miniboss (4a onda)
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
def run(n=1):
    for _ in range(n):
        core.retro_run()
        ram[A['INV']] = 3
def shot(name):
    w, buf = frame[-1]
    Image.frombytes('RGB', (w, 240), buf, 'raw', 'BGRX').save(f'/tmp/cb/{name}.png')
def u16(a): return ram[a] | (ram[a+1] << 8)
def yc_da(vhi_lo): return u16(vhi_lo)/16 - 256
def hud_lit():
    w, buf = frame[-1]
    return sum(1 for y in range(16, 24) for x in range(0xb8, 0xe8)
               if buf[(y*w+x)*4+2] > 40)

fails = []
def check(cond, msg):
    print(('OK  ' if cond else 'FALHA') + ' ' + msg)
    if not cond: fails.append(msg)

run(120)
held.add(3); run(6); held.discard(3)
run(40)
held.add(3); run(6); held.discard(3)
run(40)
held.add(3); run(6); held.discard(3)   # v0.18: corta o cartao FASE 01
run(30)

# --- SMALL v0.11: onda 3+3, 2o grupo no lado OPOSTO ---
while not (ram[A['WTIPO']] == 0 and ram[A['WACT']] == 1):
    run()
prev = [0]*6; spawns_sm = []
qn0 = None
f = 0
while ram[A['WTIPO']] == 0 and ram[A['WACT']] and f < 600:
    run(); f += 1
    if qn0 is None and ram[A['QN']]: qn0 = ram[A['QN']]
    for c in range(6):
        a = ram[A['SMA']+c]
        if a and not prev[c]:
            spawns_sm.append((f, c, ram[A['SMP']+c]))
        prev[c] = a
print('spawns small:', spawns_sm, 'qn0:', qn0)
check(qn0 == 6, f'onda small: 6 naves (qn0={qn0})')
check(len(spawns_sm) == 6, f'6 spawns ({len(spawns_sm)})')
xsA = sorted(s2[2] for s2 in spawns_sm if s2[1] < 3)
xsB = sorted(s2[2] for s2 in spawns_sm if s2[1] >= 3)
check(len(xsA) == 3 and len(set(xsA)) == 1 and xsA[0] in (43, 213), f'grupo A num lado so: {xsA}')
check(len(xsB) == 3 and len(set(xsB)) == 1 and xsB[0] in (43, 213), f'grupo B num lado so: {xsB}')
check(xsA[0] != xsB[0], f'lados opostos: A={xsA[0]} B={xsB[0]}')
gaps = [spawns_sm[i+1][0]-spawns_sm[i][0] for i in range(len(spawns_sm)-1)]
check(len(gaps) == 5 and all(25 <= g <= 29 for g in gaps), f'cadencia ~27f: {gaps}')

while not (ram[A['WTIPO']] == 1 and ram[A['WACT']] == 1):
    run()

# --- SHARD: escondido enquanto yc<1 (guard anti-wrap) ---
hole = []
for f in range(70):
    run()
    for c in range(4):
        if ram[A['SHA']+c]:
            yc = yc_da(A['#SHY'] + c*2)
            q3 = ram[A['R16'] + (12 + c + ram[A['RR']]) % 16]  # v0.14: slot via anel
            yy = ram[0x200 + q3*4]
            if yc < 1 and yy != 0xF0:
                hole.append((f, c, round(yc), yy))
print('furos no guard do shard:', hole[:8], f'({len(hole)} total)')
check(len(hole) == 0, 'shard escondido enqto entra pelo alto')
shot('v08_shard')

# --- METEORO: passo unico ---
while not (ram[A['WTIPO']] == 2 and ram[A['WACT']] == 1):
    run()
prev = [0]*8; prev_eb = [0]*8
spawns, shots, track = [], [], {}
hud_vals, oam137 = [], set()
f = 0
while ram[A['WTIPO']] == 2 and f < 900:
    run(); f += 1
    if f % 40 == 0: hud_vals.append(hud_lit())
    for c in range(8):
        a = ram[A['E4A']+c]
        if a and not prev[c]:
            spawns.append((f, c, ram[A['E4X']+c], ram[A['E4W']+c]))
        prev[c] = a
    # OAM estatico (so com meteoro 0 ativo e dentro da tela)
    if ram[A['E4A']] and yc_da(A['#E4Y']) > 10:
        oam137.add(ram[0x200 + 41*4 + 1])
    live = [ram[A['EBA']+i] for i in range(8)]
    for i in range(8):
        if live[i] and not prev_eb[i]:
            shots.append([f, u16(A['#EBX'] + i*2), None])
            track[i] = len(shots) - 1
        if not live[i] and prev_eb[i]:
            track.pop(i, None)
    for i, j in list(track.items()):
        if shots[j][2] is None and f >= shots[j][0] + 20:
            shots[j][2] = u16(A['#EBX'] + i*2)
    prev_eb = live
print('spawns:', spawns)
xs = sorted(s[2] for s in spawns)
check(len(spawns) == 8 and xs == [32, 32, 88, 88, 144, 144, 200, 200], f'8 naves, 2x4 colunas: {xs}')
speeds = sorted(set(s[3] for s in spawns))
check(len(speeds) >= 3, f'velocidades variadas: {speeds}')
gaps = [spawns[i+1][0]-spawns[i][0] for i in range(len(spawns)-1)]
check(len(gaps) == 7 and all(28 <= g <= 32 for g in gaps), f'intervalos 0.5s: {gaps}')
seq = [s[2] for s in spawns]
check(not any(seq[i] == seq[i+1] for i in range(len(seq)-1)), 'coluna nunca repete seguida')
# v0.15 (mapper 30): margem <80. Pixels e' probe de wall-frame: o boot do
# v0.15 atrasa ~15 wall-frames (copia CHR->CHRRAM), entao o lfsr (seed =
# contador livre) nasce com fase diferente: spawns/amostras caem em offsets
# de --15f. Um Enemy4 da coluna 200 atravessa o topo por ~10f e pode cair
# numa amostra. Identidade logica provada: mesma seed -> mesmos streams
# (lfsr igual alinhado por game-frame), drops=0 nas duas builds.
check(max(hud_vals) - min(hud_vals) < 80, f'HUD estavel: {hud_vals}')
check(oam137 == {137}, f'frame estatico tile 137: {oam137}')
movs = [None if s[2] is None else round((s[2]-s[1])/16, 1) for s in shots]
print('tiros:', len(shots), 'movs px/20f:', movs)
check(len(shots) == 8, f'exatamente 8 tiros: {len(shots)}')
ordem = sorted(spawns)
away = 0
for j, s in enumerate(shots):
    if s[2] is None or j >= len(ordem): continue
    col = ordem[j][2]
    esp = 1 if col < 120 else -1
    if (s[2] - s[1]) * esp < -16: away += 1
check(away == 0, 'tiros miram pro player (nao p/ longe)')
shot('v08_meteoro_tiro')


# --- MINIBOSS (v0.11): interludio a cada 4 ondas (wnum=3) ---
while not ram[A['MBA']]:
    run()
check(ram[A['WNUM']] == 3, f'miniboss na 4a onda (wnum={ram[A["WNUM"]]})')
check(ram[A['MBW']] == 1, 'flag mbw: onda do miniboss')
ycs = []
while ram[A['MBS']] == 1:
    run()
    ycs.append(round(yc_da(A['#MBY'])))
check(len(ycs) > 80 and ycs[-1] > ycs[0], f'descida gradual ({len(ycs)}f: {ycs[:2]}...{ycs[-2:]})')
ytop = round(yc_da(A['#MBY']))
check(71 <= ytop <= 73, f'estacionou acima do meio (yc={ytop})')
dirs = []
for f in range(700):
    run()
    dirs.append(ram[A['MBDIR']])
check(0 in dirs and 1 in dirs, 'patrulha esq/dir (mbdir inverte)')
xs = []
for f in range(200):
    run(); xs.append(ram[A['MBX']])
check(min(xs) >= 8 and max(xs) <= 208, f'patrulha dentro da tela ({min(xs)}..{max(xs)})')
aneis = 0; ring_frames = []
prev_live = [ram[A['EBA']+i] for i in range(8)]
f = 0
while aneis < 2 and f < 1500:
    run(); f += 1
    live = [ram[A['EBA']+i] for i in range(8)]
    news = sum(1 for i in range(8) if live[i] and not prev_live[i])
    if news >= 6:
        aneis += 1
        ring_frames.append((f, news))
    prev_live = live
print('aneis:', ring_frames)
check(aneis >= 2, f'atira aneis periodicamente ({aneis})')
if len(ring_frames) > 1:
    gap = ring_frames[1][0] - ring_frames[0][0]
    check(gap >= 140, f'intervalo entre aneis respeita a trava ({gap}f)')
# 1 tiro = 1 de dano
while not ram[A['BTY']] == 0:
    run()
hp0 = ram[A['MBHP']]
ram[A['BTX']] = ram[A['MBX']] + 12
ram[A['BTY']] = 100   # janela de acerto do estacionamento (yc=72): 64..104
run(3)
check(ram[A['MBHP']] == hp0 - 1 and ram[A['MBA']] == 1, f'tiro tira 1 HP ({hp0}->{ram[A["MBHP"]]})')
# morte: +500, wave termina, proxima onda comeca
ram[A['MBHP']] = 1
slot = next(i for i in range(5) if ram[A['BTY']+i] == 0)
ram[A['BTX']+slot] = ram[A['MBX']] + 12
ram[A['BTY']+slot] = 100
s2_0 = ram[A['S2']]
run()
check(ram[A['MBA']] == 0, 'miniboss MORRE com o ultimo tiro')
check(ram[A['S2']] - s2_0 == 5, f'+500 pontos (s2 {s2_0}->{ram[A["S2"]]})')
while not (ram[A['WNUM']] == 4 and ram[A['WACT']] == 1):
    run()
check(True, 'onda seguinte (wnum=4) comeca apos a morte')
shot('v11_miniboss')

# morte do meteoro por tiro do player (injeta bala alinhada)
alvo = None
run(120)  # ja estamos na onda small seguinte; pula p/ proxima meteoro
while not (ram[A['WTIPO']] == 2 and ram[A['WACT']] == 1):
    run()
# v0.10: sai do laco assim que acha um alvo (a onda de 8 e mais curta)
for f in range(600):
    run()
    for c in range(8):
        if ram[A['E4A']+c]:
            yc = yc_da(A['#E4Y'] + c*2)
            if 100 < yc < 140: alvo = (c, int(yc))
    if alvo is not None: break
if alvo is None: raise SystemExit('nenhum enemy4 visado')
c, yc = alvo
s2_0 = ram[A['S2']]
ram[A['BTX']] = ram[A['E4X']+c] + 4
ram[A['BTY']] = yc + 8
run(3)  # v0.14: e4 processa janela a 30Hz (split), 1 frame pode nao bastar
check(ram[A['E4A']+c] == 0, 'meteoro morre com 1 tiro')
check(ram[A['S2']] - s2_0 == 3, f'+300 pontos (s2 {s2_0}->{ram[A["S2"]]})')
print('RESULTADO:', 'TUDO OK' if not fails else f'{len(fails)} FALHAS: {fails}')
