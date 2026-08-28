#!/usr/bin/env python3
# v0.9 - teste do loop do cenario (antes=v0.8 / depois=v0.9)
# Uso: python3 v09_estrelas.py <rom> <addrs_modulo> <tag>
# Ideia: com ondas suprimidas (wpausa re-pinned), em scroll_y=S o quadro
# DEVE ser o mapa de estrelas de scroll_y=0 deslocado de S linhas (mod 240).
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
        ram[A['WPAUSA']] = 200  # suprime ondas: so estrelas + nave parada

def scroll(): return ram[0x1A]

def wait_scroll(v, lim=400):
    f = 0
    while scroll() != v and f < lim:
        run(); f += 1
    assert f < lim, 'scroll nunca chegou a %d' % v
    return frames[-1]

STAR = {(32,92,220), (76,160,255), (108,108,108)}
def star_mask(fr):
    w, buf = fr
    m = bytearray(w*240)
    for i in range(w*240):
        b,g,r = buf[i*4], buf[i*4+1], buf[i*4+2]
        if (r,g,b) in STAR: m[i] = 1
    return w, m

def count_band(sm, y0, y1):
    w, m = sm
    return sum(m[y*w+x] for y in range(y0,y1) for x in range(w))

# boot -> titulo -> jogo
run(150)
held.add(3); run(6); held.discard(3)
run(120)
F0 = wait_scroll(0)
S = 100
FS = wait_scroll(S)
w, _ = F0
M0, MS = star_mask(F0), star_mask(FS)

# perfil: quantas estrelas na metade NT1 (linhas 0..S+40) vs faixa NT2 (linhas 140..239)
n_top = count_band(MS, 28, 140)
n_bot = count_band(MS, 140, 186)
print(f'{TAG}: estrelas na faixa $2000 (linhas 28-139): {n_top}')
print(f'{TAG}: estrelas na faixa $2400 (linhas 140-185): {n_bot}')

# comparacao deslocada: FS linha r  ==  F0 linha (S+r)%240
tot = ok = 0
w0, m0 = M0; wS, mS = MS
for r in range(28, 186):
    src = (S + r) % 240
    if src <= 26 or src >= 186: continue
    for x in range(0, w0):
        b0, bS = m0[src*w0+x], mS[r*wS+x]
        tot += 1; ok += (b0 == bS)
pct = 100.0*ok/tot
print(f'{TAG}: match deslocado scroll {S} vs 0: {ok}/{tot} = {pct:.2f}%')

def save(fr, name):
    w, buf = fr
    Image.frombytes('RGB', (w,240), buf, 'raw', 'BGRX').save(name)
save(F0, f'/tmp/cb/v09_{TAG}_scroll0.png')
save(FS, f'/tmp/cb/v09_{TAG}_scroll100.png')
print(f'{TAG}: RESULTADO:', 'LOOP PERFEITO' if pct > 99.9 else 'LOOP QUEBRADO')
