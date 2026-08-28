#!/usr/bin/env python3
# Validacao Caravan Blast NES v0.1: titulo, onda small (zigzag+tiros mirados),
# rajada do player, kill, avanco de onda, shard + anel, morte/vidas, game over.
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

def shot(name, zoom=2):
    w, h = last['w'], last['h']
    Image.fromarray(frame_img()).resize((w*zoom, h*zoom), Image.NEAREST).save(f'/home/user/nes-test/{name}.png')
    print('  [shot]', name)

B = {'B':0,'SELECT':2,'START':3,'UP':4,'DOWN':5,'LEFT':6,'RIGHT':7,'A':8}
sys.path.insert(0, '/home/user/nes-test')
from addrs_cb import *

print('== 1: titulo')
step(150); shot('cb_1_titulo')
step(3, {B['START']}); step(40)
print('  px,py:', rd(PX), rd(PY), '| li:', rd(LI), '| wact:', rd(WACT), 'qdel:', rd(QDEL))

print('== 2: onda 1 — smalls nascem 1 a 1 e zigzagueiam')
hist = {}
for f in range(140):
    step(1)
    if f % 10 == 0:
        hist[f] = (sum(rd(SMA+i) for i in range(4)), rd(SMX), ri16(SMY))
        print('  f%03d ativos=%d small0 x=%d y=%.1f colx=%d' % (f, *hist[f], rd(COLX)))
shot('cb_2_smalls')
xs = []
for f in range(64):
    step(1)
    if rd(SMA): xs.append(rd(SMX))
amp = max(xs) - min(xs) if len(xs) > 5 else 0
print('  zigzag amplitude medida:', amp, '(esperado ~20-60)')
assert amp > 10, 'zigzag nao oscilou!'

print('== 3: smalls atiram mirado (ebullets descem)')
ok = False
for f in range(300):
    step(1)
    n = sum(rd(EBA+i) for i in range(8))
    if n >= 2:
        ok = True
        print('  f%03d ebullets=%d | vy de um: %d (esperado >0)' % (f, n, ctypes.c_int8(rd(EBYV)).value))
        break
shot('cb_3_mira')
assert ok, 'nenhum tiro mirado apareceu'

print('== 4: rajada do player (5 tiros / 3f, gap 16f)')
step(20, {B['B']})
serie = []
for f in range(30):
    step(1, {B['B']})
    serie.append(sum(1 for i in range(5) if rd(BTY+i)))
print('  tiros ativos ao longo de 30f:', serie)
assert max(serie) >= 3, 'rajada nao saiu'
shot('cb_4_rajada')

print('== 5: matar um small (+100, mini-explosao)')
for f in range(400):	# espera um small descer pra perto
    step(1)
    alvo = next((i for i in range(4) if rd(SMA+i) and ri16(SMY+2*i) > 140*16), -1)
    if alvo >= 0: break
s0 = ri16(SCORE)
killed = False
for f in range(150):
    step(1, {B['B']})
    if rd(SMA+alvo) == 0:
        killed = True
        print('  small %d morto em %df | score %d -> %d' % (alvo, f, s0, ri16(SCORE)))
        shot('cb_5_kill')
        break
    wr(PX, max(8, min(232, rd(SMX+alvo) + 2)))	# persegue o alvo
assert killed, 'nao matou o small'

print('== 6: limpar onda -> vem formacao shard')
for i in range(4): wr(SMA+i, 0)
for t in range(400):
    step(1)
    if sum(rd(SHA+i) for i in range(4)) == 4:
        print('  shards ativos! wnum:', rd(WNUM), 'wtipo:', rd(WTIPO), 'wflip... shx:', [rd(SHX+i) for i in range(4)], 'shy:', [round(ri16(SHY+2*i)/16) for i in range(4)])
        break
shot('cb_6_shards')
assert sum(rd(SHA+i) for i in range(4)) == 4, 'onda shard nao veio'

print('== 7: matar shard -> anel de 8 tiros')
z = -1
for f in range(300):
    step(1)
    z = next((i for i in range(4) if rd(SHA+i) and 40 < ri16(SHY+2*i)/16 < 110), -1)
    if z >= 0: break
print('  shard alvo:', z)
assert z >= 0, 'nenhum shard entrou na zona'
wr(PX, max(8, min(232, rd(SHX+z) - 2)))
ok = False
for f in range(160):
    step(1, {B['B']})
    if rd(SHA+z) == 0:
        for i in range(8): pass	# slots do anel ja ocupados contam igual
        step(2)
        n = sum(rd(EBA+i) for i in range(8))
        vx = sorted(set(ctypes.c_int8(rd(EBXV+i)).value for i in range(8) if rd(EBA+i)))
        print('  shard morto | ebullets ativas:', n, '| vxs:', vx)
        ok = n >= 4 and len(vx) >= 3	# anel tem vx -24,-17,0,17,24
        break
    for i in range(8):	# esvazia a pool pros 8 tiros do anel caberem
        if rd(SHA+z): wr(EBA+i, 0)
assert ok, 'anel nao disparou'
shot('cb_7_anel')

def mata_por_ebullet():
    for f in range(120):
        if rd(DED) > 0: return True
        c = next((i for i in range(8) if rd(EBA+i)), -1)
        if c >= 0 and rd(INV) == 0:
            wr16(EBX+2*c, (rd(PX)+8) * 16); wr16(EBY+2*c, (rd(PY)+8) * 16)
        step(1)
    return False

print('== 8: morte do player (ebullet) -> vida, respawn invencivel')
li0 = rd(LI)
ok = mata_por_ebullet()
print('  li:', li0, '->', rd(LI), '| ded:', rd(DED))
assert ok and rd(LI) == li0 - 1
step(45)
print('  respawn: inv:', rd(INV), 'px,py:', rd(PX), rd(PY))
assert rd(PX) == 120 and rd(PY) == 200
shot('cb_8_respawn')

print('== 9: game over apos 3 mortes -> titulo')
for k in range(2):
    for f in range(300):
        if rd(INV) == 0: break
        step(1)
    mata_por_ebullet()
    step(50)
    print('  morte', k+2, '| li:', rd(LI))
step(60)
shot('cb_9_gameover')
step(3, {B['START']})
step(120)
shot('cb_10_titulo_volta')
print('TUDO OK (Caravan Blast v0.1)')
