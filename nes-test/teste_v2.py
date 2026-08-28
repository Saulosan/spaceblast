#!/usr/bin/env python3
# Validação completa da v2 no fceumm: tiros, split, kill, scroll, morte por meteoro pequeno.
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

def step(n, hold=(), poke=None):
    for _ in range(n):
        pressed.clear(); pressed.update(hold)
        if poke: poke()
        poll_c(); lr.retro_run()

def shot(name):
    w, h, p = last['w'], last['h'], last['p']
    a = np.frombuffer(last['buf'], dtype=np.uint8).reshape(h, p)[:, :w*4].reshape(h, w, 4)
    Image.fromarray(a[:,:,:3][:,:,::-1]).resize((w*2, h*2), Image.NEAREST).save(f'/home/user/nes-test/{name}.png')
    print('  [shot]', name)

B = {'B':0,'SELECT':2,'START':3,'UP':4,'DOWN':5,'LEFT':6,'RIGHT':7,'A':8}
# enderecos extraidos do .asm (regs. gerar com o script de addrs)
sys.path.insert(0, '/home/user/nes-test')
from addrs import *

print('== A: titulo')
step(150); shot('v2_1_titulo')

print('== B: inicia, fogo parado (scroll + placar em sprites)')
step(3, {B['START']})
step(60, {B['B']})
print('  bty:', [rd(BTY+i) for i in range(4)], ' score:', ri16(SCORE), ' scroll_y:', rd(SCROLLY))
shot('v2_2_tiros')

step(45, {B['B']}); shot('v2_3_scroll_depois')
print('  scroll_y:', rd(SCROLLY))

print('== D: split — mira num meteoro grande e mantém fogo')
alvo = -1
for t in range(1200):
    for c in range(4):
        y = ri16(MY + 2*c)
        if 40 < y < 120: alvo = c
    if alvo >= 0: break
    step(1, {B['B']})
mx0, my0 = rd(MX+alvo), ri16(MY+2*alvo)
print(f'  meteoro {alvo} em x={mx0} y={my0}')
wr(PX, max(16, min(224, mx0 - 2)))
ok_split = False
s0 = ri16(SCORE)
for f in range(120):
    step(1, {B['B']})
    if alvo >= 0 and sum(rd(SMA+i) for i in range(8)) >= 2:
        ok_split = True; frames_split = f; break
print('  split ok?', ok_split, 'em', frames_split if ok_split else '-', 'frames | score:', s0, '->', ri16(SCORE))
for i in range(8):
    if rd(SMA+i): print(f'   small {i}: x={rd(SMX+i)} y={ri16(SMY+2*i)}')
step(6, {B['B']}); shot('v2_4_split')

print('== E: matar um pequeno — alinha e atira')
z = next((i for i in range(8) if rd(SMA+i) and ri16(SMY+2*i) < 90), -1)
print('  pequeno alvo:', z, 'x=', rd(SMX+z) if z>=0 else '-', 'y=', ri16(SMY+2*z) if z>=0 else '-')
ok_kill = False
if z >= 0:
    wr(PX, max(16, min(224, rd(SMX+z) - 6 + 2)))
    s0 = ri16(SCORE)
    for f in range(150):
        step(1, {B['B']})
        if rd(SMA+z) == 0:
            ok_kill = True; fk = f; break
    print('  kill ok?', ok_kill, 'em', fk if ok_kill else '-', 'frames | score:', s0, '->', ri16(SCORE), '| #pop:', ri16(POP), '#bng:', ri16(BNG))
    if ok_kill: shot('v2_5_minexplosao')

print('== F: pequeno mata o jogador')
z2 = next((i for i in range(8) if rd(SMA+i) and ri16(SMY+2*i) < 100), -1)
print('  pequeno assassino:', z2)
shot('v2_6_antes_morte')
if z2 >= 0:
    wr(SMY + 2*z2, rd(PY)); wr(SMY + 2*z2 + 1, 0)
    wr(SMX + z2, (rd(PX) + 2) & 0xff)
step(2)
step(25); shot('v2_7_explosao')
step(130); shot('v2_8_gameover')
print('  score final na tela:', ri16(SCORE))
step(3, {B['START']})
step(60); shot('v2_9_volta_titulo')
print('FIM')
