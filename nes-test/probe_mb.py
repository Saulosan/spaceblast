import ctypes, sys
sys.path.insert(0, '/home/user/nes-test')
from addrs_cb import ADDR as A
core = ctypes.CDLL('/tmp/cb/fceumm_libretro.so')
ENVF = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
VIDF = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)
AUDF = ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)
AUDB = ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
INPF = ctypes.CFUNCTYPE(None)
INSF = ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)
fr = []; held = set()
def envf(c, d):
    if c == 10: ctypes.cast(d, ctypes.POINTER(ctypes.c_int)).contents.value = 1; return True
    if c == 11: ctypes.cast(d, ctypes.POINTER(ctypes.c_bool)).contents.value = True; return True
    if c in (16,17): return True
    return False
def vidf(d, w, h, p): fr[:] = [1]
def audf(l, r): pass
def audb(d, n): return n
def inpf(): pass
def insf(p, de, i, j): return 1 if (p == 0 and j in held) else 0
_cb = ENVF(envf), VIDF(vidf), AUDF(audf), AUDB(audb), INPF(inpf), INSF(insf)
class RGI(ctypes.Structure):
    _fields_ = [('p', ctypes.c_char_p), ('d', ctypes.c_void_p), ('s', ctypes.c_size_t), ('m', ctypes.c_char_p)]
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
        core.retro_run(); ram[A['INV']] = 3
def u16(a): return ram[a] | (ram[a+1] << 8)

run(150); held.add(3); run(6); held.discard(3); run(30)
while not ram[A['MBA']]: run()
print('miniboss ativo; MBX=%d MBY=%d MBHP=%d' % (ram[A['MBX']], u16(A['#MBY'])//16-256, ram[A['MBHP']]))
# espera estacionar e o laser disparar, e observa acertos de bala
while ram[A['MBS']] == 1: run()
print('estacionou yc=%d mbx=%d' % ((u16(A['#MBY'])//16)-256, ram[A['MBX']]))
# injeta bala no slot 0 a cada 8 frames e conta de dano
hp0 = ram[A['MBHP']]
for k in range(10):
    if ram[A['BTY']] == 0:
        ram[A['BTX']] = ram[A['MBX']] + 12
        ram[A['BTY']] = 100
    run(8)
    print('k=%d MBHP=%d (era %d)' % (k, ram[A['MBHP']], hp0))
