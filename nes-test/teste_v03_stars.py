#!/usr/bin/env python3
# Teste v0.3: parallax das estrelas cinza + paleta + sem cintilacao
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
gif_frames = []

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

def frame_img():
    w, h, p = last['w'], last['h'], last['p']
    a = np.frombuffer(last['buf'], dtype=np.uint8).reshape(h, p)[:, :w*4].reshape(h, w, 4)
    return a[:,:,:3][:,:,::-1]

def step(n, hold=(), capture=False):
    for _ in range(n):
        pressed.clear(); pressed.update(hold)
        poll_c(); lr.retro_run()
        if capture: gif_frames.append(frame_img())

def shot(name, zoom=2):
    Image.fromarray(frame_img()).resize((256*zoom, 240*zoom), Image.NEAREST).save(f'/home/user/nes-test/{name}.png')

B = {'B':0,'SELECT':2,'START':3,'UP':4,'DOWN':5,'LEFT':6,'RIGHT':7,'A':8}
sys.path.insert(0, '/home/user/nes-test')
import addrs_cb
A = addrs_cb.A

step(150)
shot('v03_1_title')
step(3, {B['START']}); step(50)

print('paleta de gameplay ativa? checar cor das estrelas cinza na tela')
img = frame_img()
# colunas esperadas das cinza: (1+4c)*8+4 = 12,44,76,108,140,172,204,236
cols = [12+32*i for i in range(8)]
gray_px = {}
for x in cols:
    colpx = img[:, max(0,x-1):x+2, :]
    nz = np.argwhere(np.any(colpx > 8, axis=2))
    gray_px[x] = len(nz)
print('pixels nao-pretos perto das colunas cinza:', gray_px)

# coleta estados do parallax por 64 frames; invencivel para nao morrer
print()
print('== parallax: wgp deve decrementar 1 a cada 2 frames; wgr a cada 16 ==')
wgp0 = [rd(A['WGP']+c) for c in range(8)]
wgr0 = [rd(A['WGR']+c) for c in range(8)]
print('fase inicial:', wgp0)
print('linha inicial:', wgr0)

snap_p = {c: [] for c in range(8)}
snap_r = {c: [] for c in range(8)}
for f in range(64):
    ram[A['INV']] = 90
    step(1)
    for c in range(8):
        snap_p[c].append(rd(A['WGP']+c))
        snap_r[c].append(rd(A['WGR']+c))

ok = True
for c in range(8):
    p_seq = snap_p[c]
    r_seq = snap_r[c]
    # a cada update (2 frames), fase decrementa 1 (mod 8)
    expect_p = [(wgp0[c] - (i//2)) % 8 for i in range(64)]
    # linha decrementa 1 a cada wrap de fase
    expect_r = [(wgr0[c] - len([1 for i in range(64) if i >= (wgp0[c]%8)*2 == 0 and False])) for _ in range(1)] # simplificado abaixo
    if p_seq != expect_p:
        print(f'  estrela {c}: FASE ERRADA esperado {expect_p[:12]} obtido {p_seq[:12]}')
        ok = False
    # linha: decrementa quando fase volta a 7
    wraps = sum(1 for i in range(1,64) if p_seq[i] == 7 and p_seq[i-1] == 0)
    r_expect = (wgr0[c] - wraps) % 60
    if r_seq[-1] != r_expect:
        print(f'  estrela {c}: LINHA esperada {r_expect} obtida {r_seq[-1]} (wraps {wraps})')
        ok = False
print('fases finais:', [snap_p[c][-1] for c in range(8)])
print('linhas finais:', [snap_r[c][-1] for c in range(8)])
print('PARALLAX OK' if ok else 'PARALLAX FALHOU')

shot('v03_2_game')

# verifica que estrelas azuis nao ocupam colunas das cinza: varre nametable? nao temos VRAM.
# proxy: pixels azuis claros em x das colunas cinza nao devem existir... sprite pode passar la. ok, visual no gif.

# GIF de gameplay
print()
print('== gravando gif 320 frames ==')
for f in range(320):
    ram[A['INV']] = 90
    h = set()
    if 20 < f < 60: h = {B['RIGHT']}
    elif 60 <= f < 100: h = {B['LEFT']}
    elif 100 <= f < 300: h = {B['B']}
    pressed.clear(); pressed.update(h); poll_c(); lr.retro_run()
    gif_frames.append(frame_img())

shot('v03_3_game_late')

imgs = [Image.fromarray(g).resize((256,240), Image.NEAREST) for g in gif_frames]
imgs[0].save('/home/user/spaceblast/docs/caravan_v03_stars.gif', save_all=True, append_images=imgs[1:], duration=33, loop=0)
print('gif salvo:', len(imgs), 'frames')
print()
print('pixels cinza encontrados/estrelas (amostra):', gray_px)
