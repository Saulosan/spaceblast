#!/usr/bin/env python3
# GIF demo v0.12: cota small, laser do miniboss, BOSS (3 fases + morte)
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
frames_raw = []; held = set()
def envf(cmd, data):
    if cmd == 10: ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value = 1; return True
    if cmd == 11: ctypes.cast(data, ctypes.POINTER(ctypes.c_bool)).contents.value = True; return True
    if cmd in (16,17): return True
    return False
def vidf(d, w, h, p): frames_raw[:] = [(w, ctypes.string_at(d, w*h*4))]
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
def run(n=1):
    for _ in range(n):
        core.retro_run(); ram[A['INV']] = 3
def u16(a): return ram[a] | (ram[a+1] << 8)
def img():
    w, buf = frames_raw[-1]
    return Image.frombytes('RGB', (w,240), buf, 'raw', 'BGRX').resize((512,480), Image.NEAREST)
def alvo_x():
    if ram[A['BSA']]:
        return 116, 0                      # boss parado no centro
    if ram[A['MBA']]:
        # antecipacao: a bala voa 32 frames ate ele; ele anda 1px/f
        lead = 28 if ram[A['MBDIR']] == 0 else -28
        return ram[A['MBX']] + 12 + lead, u16(A['#MBY'])
    for c in range(8):
        if ram[A['E4A']+c]: return ram[A['E4X']+c] + 4, u16(A['#E4Y']+c*2)
    for c in range(4):
        if ram[A['SHA']+c]: return ram[A['SHX']+c] + 4, u16(A['#SHY']+c*2)
    for c in range(6):
        if ram[A['SMA']+c]: return ram[A['SMX']+c] + 4, u16(A['#SMY']+c*2)
    return 120, 0
def bot(rec, n):
    for f in range(n):
        px = ram[A['PX']]; tx, ty = alvo_x()
        held.discard(BT['LEFT']); held.discard(BT['RIGHT'])
        if abs(px - tx) > 6: held.add(BT['LEFT'] if px > tx else BT['RIGHT'])
        held.add(BT['B']); run(); held.discard(BT['B'])
        if rec and f % 4 == 0: giff.append(img())

giff = []
run(150)
for i in range(30):
    run()
    if i % 5 == 0: giff.append(img())
held.add(BT['START']); run(6); held.discard(BT['START'])
run(30)
bot(True, 420)                                # small 3+3 + cota em acao
while not ram[A['MBA']]: bot(False, 1)        # acelera ate o miniboss
print('miniboss chegou', flush=True)
morto_em = None
for f in range(2600):
    bot(False, 1)
    if f % 4 == 0: giff.append(img())
    if not ram[A['MBA']] and morto_em is None:
        morto_em = f
        print('miniboss MORREU frame %d' % f, flush=True)
    if morto_em is not None and f > morto_em + 100: break
    if morto_em is None and f == 1500: ram[A['MBHP']] = 3  # apressa 1x so!
# chama o BOSS (gatilho organico ja coberto na suite; aqui e demo)
for c in range(6): ram[A['SMA']+c] = 0
for c in range(8): ram[A['E4A']+c] = 0
for c in range(4): ram[A['SHA']+c] = 0
ram[A['NSMA']] = 4; ram[A['NSHA']] = 4; ram[A['NE4']] = 4
f = 0
while not ram[A['BSA']] and f < 900: bot(False, 1); f += 1
print('BOSS chegou (%df)' % f, flush=True)
ciclo = False; morto_em = None
for f in range(4200):
    bot(False, 1)
    if f % 4 == 0: giff.append(img())
    if ram[A['BSPH']] == 3: ciclo = True                    # mostrou as 3 fases
    if ciclo and ram[A['BSPH']] == 1 and ram[A['BSHP']] > 6: ram[A['BSHP']] = 6
    if not ram[A['BSA']] and morto_em is None:
        morto_em = f
        print('BOSS MORREU frame %d (score s1=%d)' % (f, ram[A['S1']]), flush=True)
    if morto_em is not None and f > morto_em + 150: break
giff[0].save('/home/user/caravanblast/docs/space_blast_v12_boss.gif',
             save_all=True, append_images=giff[1:], duration=50, loop=0, optimize=True)
print('GIF salvo:', len(giff), 'frames')
