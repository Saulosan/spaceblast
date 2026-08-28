#!/usr/bin/env python3
# v0.4: titulo/logo/rodape + estrelas sheet + medicao de slowdown
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
giff = []

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
cs = (ENV_CB(env), VIDEO_CB(video), AUDIO_CB(audio), AUDIOB_CB(audiob), POLL_CB(poll), STATE_CB(state))
lr.retro_set_environment(cs[0]); lr.retro_set_video_refresh(cs[1])
lr.retro_set_audio_sample(cs[2]); lr.retro_set_audio_sample_batch(cs[3])
lr.retro_set_input_poll(cs[4]); lr.retro_set_input_state(cs[5])
class RGI(ctypes.Structure):
    _fields_ = [("path", ctypes.c_char_p), ("data", ctypes.c_void_p), ("size", ctypes.c_size_t), ("meta", ctypes.c_char_p)]
lr.retro_init()
if not lr.retro_load_game(ctypes.byref(RGI(ROM.encode(), None, 0, None))): sys.exit('falha ROM')
lr.retro_set_controller_port_device(0, 1)
lr.retro_get_memory_data.restype = ctypes.c_void_p
ram = (ctypes.c_ubyte * 2048).from_address(lr.retro_get_memory_data(2))
sys.path.insert(0, '/home/user/nes-test')
import addrs_cb
FRAME_ZP = 0x12  # variavel 'frame' do prologo

def img():
    w, h, p = last['w'], last['h'], last['p']
    a = np.frombuffer(last['buf'], dtype=np.uint8).reshape(h, p)[:, :w*4].reshape(h, w, 4)
    return a[:,:,:3][:,:,::-1].copy()

def step(n, hold=(), gif=False):
    for _ in range(n):
        pressed.clear(); pressed.update(hold)
        cs[4](); lr.retro_run()
        if gif: giff.append(img())

def shot(name, zoom=2):
    Image.fromarray(img()).resize((256*zoom, 240*zoom), Image.NEAREST).save(f'/home/user/nes-test/{name}.png')

B = {'B':0,'SELECT':2,'START':3,'UP':4,'DOWN':5,'LEFT':6,'RIGHT':7,'A':8}
SCROLLY = None  # descobrir abaixo

# --- titulo ---
step(210)
shot('v04_1_title')

# --- comeca o jogo ---
step(3, {B['START']}); step(120)
shot('v04_2_game_start')

# scroll_y: procurar var que decrementa 1/frame
# vamos medir wraps do scroll lendo scroll_y do prologo? usar FRAME e contagem de loops:
# metrica: ler frame (zp 0x12) a cada run; o jogo decrementa scroll a cada loop.
# Melhor: achar scroll_y no asm gerado
import re
asm = open('/home/user/spaceblast/space-blast.asm').read()
m = re.search(r'^scroll_y:\s*equ \$(\w+)', asm, re.M|re.I)
print('scroll_y:', m.group(1) if m else 'N/A')
SCROLLY = int(m.group(1), 16) if m else None

# --- medicao 1: leve (sem tiros, no inicio) ---
def mede(nframes, label, poke_inv=True, hold_fire=False):
    wraps = 0
    prev = ram[SCROLLY] if SCROLLY else 0
    f0 = ram[FRAME_ZP]
    for f in range(nframes):
        if poke_inv: ram[addrs_cb.A['INV']] = 90
        h = {B['B']} if hold_fire else set()
        pressed.clear(); pressed.update(h); cs[4](); lr.retro_run()
        v = ram[SCROLLY]
        if v == 0xEF: wraps += 1  # wrap $ff -> $ef indica 1 ciclo completo descendo
        prev = v
    df = ram[FRAME_ZP] - f0
    print(f'{label}: {wraps} wraps em {nframes} frames emu (frame zp andou {df})')
    return wraps

w_leve = mede(1200, 'LEVE (inicio, parado)')

# --- medicao 2: pesado (atirando pra gerar tiros/anéis, ondas avancadas) ---
# forca dificuldade: pula wnum
ram[addrs_cb.A['WNUM']] = 6
w_pesado = mede(1200, 'PESADO (atirando, wnum=6)', hold_fire=True)

# screenshots & gif
for f in range(400):
    ram[addrs_cb.A['INV']] = 90
    h = {B['B']} if f<300 else set()
    pressed.clear(); pressed.update(h); cs[4](); lr.retro_run()
    if f % 2 == 0: giff.append(img())
shot('v04_3_game_pesado')
imgs = [Image.fromarray(g).resize((256,240), Image.NEAREST) for g in giff]
imgs[0].save('/home/user/spaceblast/docs/caravan_v04_game.gif', save_all=True, append_images=imgs[1:], duration=66, loop=0)
print('gif salvo')

# --- game over ---
for f in range(4000):
    step(1)
    if ram[addrs_cb.A['LI']] == 0 and ram[addrs_cb.A['DED']] == 0: break
step(90)
shot('v04_4_gameover')
print('li:', ram[addrs_cb.A['LI']])

# volta ao titulo (screenshot final da titulo ja feita)
step(3, {B['START']}); step(90)
shot('v04_5_title_again')
print('fim')
