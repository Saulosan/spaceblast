#!/usr/bin/env python3
# Validacao v3: nave custom (idle anim, inclinacao esq/dir com h-flip), tiros, cores novas.
import ctypes, sys
import numpy as np
from PIL import Image

CORE = '/tmp/fceumm_libretro.so'
ROM = '/home/user/cata-estrelas/cata-estrelas.nes'
lr = ctypes.CDLL(CORE)

ENV_CB   = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
VIDEO_CB = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)
AUDIO_CB = ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)
AUDIOB_CB= ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
POLL_CB  = ctypes.CFUNCTYPE(None)
STATE_CB = ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)

last = {'buf': None, 'w': 0, 'h': 0, 'p': 0}
pressed = set()

def env(cmd, data):
    if cmd == 10:
        ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value = 1
        return True
    if cmd == 17:
        ctypes.cast(data, ctypes.POINTER(ctypes.c_bool)).contents.value = False
        return True
    if cmd in (11, 16): return True
    return False
def video(data, w, h, p):
    if data:
        last['buf'] = ctypes.string_at(data, p*h); last['w'], last['h'], last['p'] = w, h, p
def audio(l, r): pass
def audiob(d, f): return f
def poll(): pass
def state(port, dev, idx, id): return 1 if (port == 0 and id in pressed) else 0

env_c, video_c, audio_c, audiob_c, poll_c, state_c = (ENV_CB(env), VIDEO_CB(video), AUDIO_CB(audio), AUDIOB_CB(audiob), POLL_CB(poll), STATE_CB(state))
lr.retro_set_environment(env_c); lr.retro_set_video_refresh(video_c)
lr.retro_set_audio_sample(audio_c); lr.retro_set_audio_sample_batch(audiob_c)
lr.retro_set_input_poll(poll_c); lr.retro_set_input_state(state_c)

class RGI(ctypes.Structure):
    _fields_ = [("path", ctypes.c_char_p), ("data", ctypes.c_void_p), ("size", ctypes.c_size_t), ("meta", ctypes.c_char_p)]

lr.retro_init()
if not lr.retro_load_game(ctypes.byref(RGI(ROM.encode(), None, 0, None))): sys.exit('falha ROM')
lr.retro_set_controller_port_device(0, 1)
lr.retro_get_memory_data.restype = ctypes.c_void_p
ram = (ctypes.c_ubyte * 2048).from_address(lr.retro_get_memory_data(2))

def rd(a): return ram[a]
def wr(a, v): ram[a] = v & 0xff
def ri16(a):
    v = rd(a) | (rd(a+1) << 8)
    return v - 65536 if v > 32767 else v
def wr16(a, v):
    if v < 0: v += 65536
    ram[a] = v & 0xff; ram[a+1] = (v >> 8) & 0xff

def step(n, hold=(), poke=None):
    for _ in range(n):
        pressed.clear(); pressed.update(hold)
        if poke: poke()
        poll_c(); lr.retro_run()

def frame_img():
    w, h, p = last['w'], last['h'], last['p']
    a = np.frombuffer(last['buf'], dtype=np.uint8).reshape(h, p)[:, :w*4].reshape(h, w, 4)
    return a[:,:,:3][:,:,::-1]

def shot(name):
    w, h = last['w'], last['h']
    Image.fromarray(frame_img()).resize((w*2, h*2), Image.NEAREST).save(f'/home/user/nes-test/{name}.png')
    print('  [shot]', name)

B = {'B':0,'SELECT':2,'START':3,'UP':4,'DOWN':5,'LEFT':6,'RIGHT':7,'A':8}
sys.path.insert(0, '/home/user/nes-test')
from addrs import *

print('== 1: titulo')
step(150); shot('v3_1_titulo')

print('== 2: gameplay idle — animacao da chama')
step(3, {B['START']})
slots = []
for i in range(30):
    step(1)
    slots.append(rd(SLOT))
shot('v3_2_idle')
step(6)
slots.append(rd(SLOT))
shot('v3_3_idle_b')
print('  slots vistos:', sorted(set(slots)), '| dir:', rd(DIR), '| px,py:', rd(PX), rd(PY))
assert set(slots) and all(s <= 4 for s in slots), 'idle deve usar slots 0-4'
assert len(set(slots)) >= 3, 'chama deve variar'

print('== 3: segura ESQUERDA (inclinacao)')
step(40, {B['LEFT']})
print('  dir:', rd(DIR), 'slot:', rd(SLOT), 'an:', rd(AN), 'px:', rd(PX))
assert rd(DIR) == 1 and rd(SLOT) >= 7, 'esquerda: loop slots 7-10'
assert rd(PX) < 120, 'px deve ter diminuido'
shot('v3_4_esq')

print('== 4: solta -> idle, depois segura DIREITA')
step(30)
print('  dir:', rd(DIR), 'slot:', rd(SLOT))
assert rd(DIR) == 0
step(40, {B['RIGHT']})
print('  dir:', rd(DIR), 'slot:', rd(SLOT), 'px:', rd(PX))
assert rd(DIR) == 2 and rd(SLOT) >= 7 and rd(PX) > 30
shot('v3_5_dir')

print('== 5: tiros com B')
step(40, {B['B']})
b = [rd(BTY+i) for i in range(4)]
print('  bty:', b, '| cool:', rd(COOL))
assert any(v > 0 for v in b), 'deve haver tiro ativo'
shot('v3_6_tiros')

print('== 6: estrela laranja + meteoro cinza')
for t in range(1500):
    if ri16(MY) > 60 and ri16(SY) > 20: break
    step(1)
    if t % 200 == 199: wr16(SY, 40)
wr(PX, 60); wr(PY, 60)
wr16(SY, 40)
step(3)
print('  meteoro y:', ri16(MY), '| estrela y:', ri16(SY), 'x:', rd(SX))
shot('v3_7_cores')

print('== 7: morte -> game over -> volta ao titulo')
wr(PX, rd(MX)); wr16(MY, rd(PY))
step(12)
shot('v3_8_explosao')
print('  dt:', ri16(DT))
step(200)
shot('v3_9_gameover')
step(3, {B['START']})
step(120)
shot('v3_10_titulo_volta')
print('TUDO OK (v3)')
