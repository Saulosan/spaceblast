# Capturas visuais v0.12a: titulo + scroll longo (bug da grade)
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
frame = []; held = set()
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
def run(n=1):
    for _ in range(n):
        core.retro_run()
        ram[A['INV']] = 3
def shot(name):
    w, buf = frame[-1]
    Image.frombytes('RGB', (w, 240), buf, 'raw', 'BGRX').save(f'/tmp/cb/{name}.png')

run(120); shot('v12a_titulo')
held.add(3); run(6); held.discard(3)   # START
run(30)
ram[A['WPAUSA']] = 200                 # congela ondas: so o cenario rola
run(600);  shot('v12a_scroll1')
run(1200); shot('v12a_scroll2')
run(1400); shot('v12a_scroll3')
print('capturas ok')
