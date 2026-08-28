import ctypes, os, sys
import numpy as np

sys.path.insert(0, '/home/user/nes-test')
from addrs_cb import ADDR as A

core = ctypes.CDLL('/tmp/fceumm_libretro.so')
ENVF = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
VIDF = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)
AUDF = ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)
AUDB = ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
INPF = ctypes.CFUNCTYPE(None)
INSF = ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)

pcm = []
held = set()
IDS = {'B':0,'SEL':2,'START':3,'UP':4,'DOWN':5,'LEFT':6,'RIGHT':7,'A':8}
def envf(cmd, data):
    if cmd == 10: ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value = 1; return True
    if cmd == 11: ctypes.cast(data, ctypes.POINTER(ctypes.c_bool)).contents.value = True; return True
    if cmd in (16,17): return True
    return False
def vidf(d,w,h,p): pass
def audf(l,r): pass
def audb(d,n):
    arr = np.ctypeslib.as_array(ctypes.cast(d, ctypes.POINTER(ctypes.c_int16)), shape=(n*2,))
    pcm.append(arr.copy())
    return n
def inpf(): pass
def insf(port, dev, idx, id_):
    return 1 if (port == 0 and id_ in held) else 0
_cb = ENVF(envf), VIDF(vidf), AUDF(audf), AUDB(audb), INPF(inpf), INSF(insf)
class RGI(ctypes.Structure):
    _fields_ = [('path', ctypes.c_char_p), ('data', ctypes.c_void_p), ('size', ctypes.c_size_t), ('meta', ctypes.c_char_p)]
core.retro_set_environment(_cb[0]); core.retro_set_video_refresh(_cb[1])
core.retro_set_audio_sample(_cb[2]); core.retro_set_audio_sample_batch(_cb[3])
core.retro_set_input_poll(_cb[4]); core.retro_set_input_state(_cb[5])
core.retro_init()
gi = RGI(os.path.abspath('/home/user/spaceblast/space-blast.nes').encode(), None, 0, None)
assert core.retro_load_game(ctypes.byref(gi))
core.retro_get_memory_data.restype = ctypes.c_void_p
ram = (ctypes.c_ubyte * 2048).from_address(core.retro_get_memory_data(2))

marks = {}
def run(n, tag=None):
    for _ in range(n): core.retro_run()
    if tag: marks[tag] = sum(len(c) for c in pcm)//2

# FASE 1: titulo (musica mus_title)
run(180, 'boot')
run(420, 'title_end')
# FASE 2: start -> jogo (mus_stage1) com tiros
held.add(IDS['START']); run(12); held.discard(IDS['START'])
run(160, 'game_start')
held.add(IDS['B']); run(30); held.discard(IDS['B'])
run(120, 'fired')
# FASE 3: performance com musica (conta scroll decrements / frames)
run(200)
sx = A['SCROLL_Y']
prev = ram[sx]; downs = 0
nperf = 600
for f in range(nperf):
    core.retro_run()
    v = ram[sx]
    if v == (prev - 1) & 0xff: downs += 1
    prev = v
print(f'PERF: game-loop rate = {100.0*downs/nperf:.1f}% (600 frames, musica ON)')
marks['perf_end'] = sum(len(c) for c in pcm)//2
# FASE 4: morte forcada (li=1, inv=0, tiro inimigo em cima do player)
ram[A['LI']] = 1
ram[A['INV']] = 0
ram[A['EBA']] = 1
px, py = ram[A['PX']], ram[A['PY']]
v16 = (px + 256)*16
ram[A['EBX']] = v16 & 0xff; ram[A['EBX']+1] = (v16 >> 8) & 0xff
v16 = (py + 256)*16 - 16
ram[A['EBY']] = v16 & 0xff; ram[A['EBY']+1] = (v16 >> 8) & 0xff
run(120, 'dead')
run(240, 'gameover')
run(200, 'end')

allp = np.concatenate(pcm)
import wave
w = wave.open('/tmp/cb_integra.wav','wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000)
w.writeframes(allp.astype('<i2').tobytes()); w.close()
for k, v in marks.items(): print(k, f'{v/48000:.2f}s')
print('total', f'{len(allp)//2/48000:.2f}s', 'LI=', ram[A['LI']], 'DED=', ram[A['DED']])
