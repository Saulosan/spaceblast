#!/usr/bin/env python3
# Diagnostico CB v0.1: (1) shard some no diag exit? (2) small movimento (3) tiros inimigos
import ctypes, sys
import numpy as np
from PIL import Image

CORE = '/tmp/fceumm_libretro.so'
ROM = '/home/user/spaceblast/space-blast.nes'
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
def ri16(a):
    v = rd(a) | (rd(a+1) << 8)
    return v - 65536 if v > 32767 else v

def step(n, hold=()):
    for _ in range(n):
        pressed.clear(); pressed.update(hold)
        poll_c(); lr.retro_run()

def shot(name, zoom=2):
    w, h, p = last['w'], last['h'], last['p']
    a = np.frombuffer(last['buf'], dtype=np.uint8).reshape(h, p)[:, :w*4].reshape(h, w, 4)
    Image.fromarray(a[:,:,:3][:,:,::-1]).resize((w*zoom, h*zoom), Image.NEAREST).save(f'/home/user/nes-test/{name}.png')

B = {'B':0,'SELECT':2,'START':3,'UP':4,'DOWN':5,'LEFT':6,'RIGHT':7,'A':8}
sys.path.insert(0, '/home/user/nes-test')
from addrs_cb import *

OAM = 0x200  # shadow OAM padrao CVBasic
def oam(s):
    return (rd(OAM + s*4), rd(OAM + s*4+1), rd(OAM + s*4+2), rd(OAM + s*4+3))  # y,tile,attr,x

step(150)
step(3, {B['START']}); step(40)

print('== rastreando 2400 frames (sem atirar; so anda) ==')
eb_seen = 0
sh_track = []
eb_first_frames = []
sm_first = None
ring_frames = []
hold = ()
for f in range(2400):
    # anda em circulos p/ simular jogador
    if f % 240 < 100: hold = {B['LEFT']}
    elif f % 240 < 220: hold = {B['RIGHT']}
    else: hold = ()
    if 900 < f < 1250: hold = hold | {B['B']}  # atira um pouco p/ testar anel do shard
    step(1, hold)
    if f == 60: shot('diag_a_jogo')
    nact = sum(rd(EBA+i) for i in range(8))
    if nact > 0:
        eb_seen += 1
        if len(eb_first_frames) < 6 and (not eb_first_frames or f > eb_first_frames[-1] + 30):
            eb_first_frames.append(f)
            print('  f%04d: %d ebalas ativas' % (f, nact))
            for i in range(8):
                if rd(EBA+i):
                    print('    eb%d pos=(%.1f,%.1f) vel=(%d,%d)' % (i, ri16(EBX+i*2)/16, ri16(EBY+i*2)/16, ctypes.c_int8(rd(EBXV+i)).value, ctypes.c_int8(rd(EBYV+i)).value))
            print('    OAM 23-30:', [oam(23+i) for i in range(8)])
            shot('diag_eb_%d' % f)
    # shards
    if f % 60 == 0:
        st = []
        for i in range(4):
            if rd(SHA+i):
                st.append((rd(SHX+i), round(ri16(SHY+i*2)/16,1), rd(SHF+i), ctypes.c_int8(rd(SHVX+i)).value))
        if st: sh_track.append((f, st))
if sh_track:
    print('== trajetoria shards (a cada 60f): x, y, fase, vx ==')
    for f, st in sh_track[:40]:
        print('  f%04d' % f, st)
print('ebalas vistas em', eb_seen, 'frames')
print('== OAM agora:', [oam(s) for s in range(0, 32, 2)])
