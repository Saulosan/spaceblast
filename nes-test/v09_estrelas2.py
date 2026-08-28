#!/usr/bin/env python3
# v0.9 - localiza ONDE o scroll quebra: testa a faixa NT2 em varios S.
import ctypes, sys, importlib
from PIL import Image
sys.path.insert(0, '/home/user/nes-test')
ROM, MOD, TAG = sys.argv[1], sys.argv[2], sys.argv[3]
A = importlib.import_module(MOD).ADDR
core = ctypes.CDLL('/tmp/cb/fceumm_libretro.so')
ENVF = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
VIDF = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)
AUDF = ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)
AUDB = ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
INPF = ctypes.CFUNCTYPE(None)
INSF = ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)
frames = []
held = set()
def envf(cmd, data):
    if cmd == 10: ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value = 1; return True
    if cmd == 11: ctypes.cast(data, ctypes.POINTER(ctypes.c_bool)).contents.value = True; return True
    if cmd in (16,17): return True
    return False
def vidf(d, w, h, p): frames.append((w, ctypes.string_at(d, w*h*4)))
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
gi = RGI(ROM.encode(), None, 0, None)
assert core.retro_load_game(ctypes.byref(gi))
ram = (ctypes.c_ubyte * 2048).from_address(core.retro_get_memory_data(2))
def run(n=1):
    for _ in range(n):
        core.retro_run()
        ram[A['WPAUSA']] = 200
def wait_scroll(v, lim=500):
    f = 0
    while ram[0x1A] != v and f < lim:
        run(); f += 1
    assert f < lim
    return frames[-1]
STAR = {(32,92,220), (76,160,255), (108,108,108)}
def star_mask(fr):
    w, buf = fr
    m = bytearray(w*240)
    for i in range(w*240):
        b,g,r = buf[i*4], buf[i*4+1], buf[i*4+2]
        if (r,g,b) in STAR: m[i] = 1
    return m
run(150)
held.add(3); run(6); held.discard(3)
run(120)
w, _ = frames[-1]
M0 = star_mask(wait_scroll(0))
for S in (100, 140, 180, 230):
    MS = star_mask(wait_scroll(S))
    r0 = 240 - S + 28
    tot = ok = mism_rows = 0
    starsF0 = starsFS = 0
    for r in range(r0, 186):
        src = (S + r) % 240
        rowok = True
        for x in range(w):
            b0, bS = M0[src*w+x], MS[r*w+x]
            tot += 1; ok += (b0 == bS)
            starsF0 += b0; starsFS += bS
            if b0 != bS: rowok = False
        mism_rows += (not rowok)
    print(f'{TAG}: scroll={S} faixaNT2 rows[{r0}..185]: match {100.0*ok/tot:6.2f}%  '
          f'linhas c/ diff {mism_rows}  estrelas F0={starsF0} FS={starsFS}')
