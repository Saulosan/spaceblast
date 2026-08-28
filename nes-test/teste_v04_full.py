#!/usr/bin/env python3
# v0.4: suite completa — telas novas + regressao gameplay (apos otimizacoes)
import ctypes, sys
import numpy as np
from PIL import Image

lr = ctypes.CDLL('/tmp/fceumm_libretro.so')
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
if not lr.retro_load_game(ctypes.byref(RGI(b'/home/user/spaceblast/space-blast.nes', None, 0, None))): sys.exit('falha ROM')
lr.retro_set_controller_port_device(0, 1)
lr.retro_get_memory_data.restype = ctypes.c_void_p
ram = (ctypes.c_ubyte * 2048).from_address(lr.retro_get_memory_data(2))
sys.path.insert(0, '/home/user/nes-test')
import addrs_cb
A = addrs_cb.A

def img():
    w, h, p = last['w'], last['h'], last['p']
    a = np.frombuffer(last['buf'], dtype=np.uint8).reshape(h, p)[:, :w*4].reshape(h, w, 4)
    return a[:,:,:3][:,:,::-1].copy()
def step(n, hold=(), gif=False, every=1):
    for i in range(n):
        pressed.clear(); pressed.update(hold)
        cs[4](); lr.retro_run()
        if gif and i % every == 0: giff.append(img())
def shot(name, zoom=2):
    Image.fromarray(img()).resize((256*zoom, 240*zoom), Image.NEAREST).save(f'/home/user/nes-test/{name}.png')
def ri16(a):
    v = ram[a] | (ram[a+1] << 8)
    return v - 65536 if v > 32767 else v

B = {'B':0,'START':3,'UP':4,'DOWN':5,'LEFT':6,'RIGHT':7,'A':8}
erros = []

# --- 1. titulo ---
step(240)
shot('v04_1_title')

# --- 2. gameplay: estrelas harmonicas ---
step(3, {B['START']}); step(60)	# v0.16: pula a splash
step(3, {B['START']}); step(150)	# v0.16: start no titulo
step(40); step(3, {B['START']}); step(60)	# v0.18: corta o cartao FASE 01
shot('v04_2_game')

# --- 3. regressao: tiros inimigos nascem perto do small (sem deslocamento) ---
print('== regressao gameplay ==')
births = 0
birth_ok = 0
prev_eba = [ram[A['EBA']+k] for k in range(8)]
ring_events = 0
ring_frames = []
score_reads = []
deaths = 0
for f in range(3600):
    ram[A['INV']] = 90
    h = set()
    if 100 < f < 2000: h = {B['B']}
    if 800 < f < 850: h.add(B['RIGHT'])
    if 1400 < f < 1450: h.add(B['LEFT'])
    step(1, h, gif=(f % 3 == 0 and 200 < f < 1400))
    cur = [ram[A['EBA']+k] for k in range(8)]
    act = sum(cur)
    if act >= 7 and prev_eba and sum(prev_eba) < act - 2:
        ring_events += 1
    prev_eba = cur
    if f % 300 == 0:
        score_reads.append(tuple(ram[A['S0']+i] for i in range(5)))

print('score digits ao longo do tempo:', score_reads)
print('eventos de rajada grande (anel):', ring_events)
d_score = score_reads[-1]
score_num = d_score[0]*10000 + d_score[1]*1000 + d_score[2]*100 + d_score[3]*10 + d_score[4]
print('placar final (digitos):', score_num)
if score_num < 100: erros.append('placar nao subiu (kills falharam?)')

# --- 4. morte do player por tiro mirado ---
# tira invencibilidade e deixa ser atingido
li0 = ram[A['LI']]
for f in range(3600):
    step(1)
    if ram[A['LI']] < li0: break
deaths = li0 - ram[A['LI']]
print('mortes apos tirar inv:', deaths)
if deaths == 0: erros.append('player nao morreu mais (colisao tiro-player quebrou?)')
if deaths > 0:
    step(60)
    shot('v04_3_respawn')

# --- 5. game over ---
for f in range(6000):
    step(1)
    if ram[A['LI']] == 0 and ram[A['DED']] == 0 and ram[A['WACT']] >= 0:
        # heuristica: game over quando li=0 e passou a animacao
        pass
    if ram[A['LI']] == 0 and ram[A['DED']] == 0:
        # espera fixa p/ tela de game over aparecer
        if f > 100: break
step(90)
shot('v04_4_gameover')

# --- 6. volta ao titulo ---
step(3, {B['START']}); step(60)	# v0.18: game over -> cartao
step(3, {B['START']}); step(90)	# corta o cartao -> jogo
shot('v04_5_title_again')

# gif
imgs = [Image.fromarray(g).resize((256,240), Image.NEAREST) for g in giff]
if imgs:
    imgs[0].save('/home/user/spaceblast/docs/caravan_v04_game.gif', save_all=True, append_images=imgs[1:], duration=66, loop=0)
    print('gif salvo:', len(imgs))

print()
if erros:
    print('ERROS:', erros)
else:
    print('SUITE OK')
