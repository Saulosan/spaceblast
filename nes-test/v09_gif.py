#!/usr/bin/env python3
# v0.9 - GIF de demonstracao: gameplay com ondas rapidas + enemy4 velozes
import ctypes, sys, importlib
from PIL import Image
sys.path.insert(0, '/home/user/nes-test')
A = importlib.import_module('addrs_cb').ADDR
core = ctypes.CDLL('/tmp/cb/fceumm_libretro.so')
ENVF = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
VIDF = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)
AUDF = ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)
AUDB = ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
INPF = ctypes.CFUNCTYPE(None)
INSF = ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)
frames_raw = []
held = set()
def envf(cmd, data):
    if cmd == 10: ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value = 1; return True
    if cmd == 11: ctypes.cast(data, ctypes.POINTER(ctypes.c_bool)).contents.value = True; return True
    if cmd in (16,17): return True
    return False
def vidf(d, w, h, p): frames_raw.append((w, ctypes.string_at(d, w*h*4)))
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
        core.retro_run()
        ram[A['INV']] = 3
def u16(a): return ram[a] | (ram[a+1] << 8)
def img():
    w, buf = frames_raw[-1]
    return Image.frombytes('RGB', (w,240), buf, 'raw', 'BGRX').resize((512,480), Image.NEAREST)

def alvo_x():
    # primeiro enemy4 ativo, senao shard, senao small: retorna x alinhado
    for c in range(4):
        if ram[A['E4A']+c]:
            return ram[A['E4X']+c] + 4, u16(A['E4Y']+c*2)
    for c in range(4):
        if ram[A['SHA']+c]:
            return ram[A['SHX']+c] + 4, u16(A['SHY']+c*2)
    for c in range(4):
        if ram[A['SMA']+c]:
            return ram[A['SMX']+c] + 4, u16(A['SMY']+c*2)
    return 120, 0

giff = []
run(150)
for i in range(45):  # titulo
    run()
    if i % 3 == 0: giff.append(img())
held.add(BT['START']); run(6); held.discard(BT['START'])
run(30)
NF = 950
for f in range(NF):
    px = ram[A['PX']]
    tx, ty = alvo_x()
    held.discard(BT['LEFT']); held.discard(BT['RIGHT'])
    if abs(px - tx) > 6:
        held.add(BT['LEFT'] if px > tx else BT['RIGHT'])
    held.add(BT['B'])
    run()
    held.discard(BT['B'])
    if f % 3 == 0: giff.append(img())
giff[0].save('/home/user/caravanblast/docs/space_blast_v09_loop_estrelas.gif',
             save_all=True, append_images=giff[1:], duration=50, loop=0,
             optimize=True)
print('GIF salvo:', len(giff), 'frames')
