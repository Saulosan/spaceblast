#!/usr/bin/env python3
# Validacao CB v0.2 FINAL: shards, smalls (3/onda, frame estatico, zigzag suave),
# balas miradas, anel, morte por bala, score.
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
def ru16(a): return rd(a) | (rd(a+1) << 8)
def s8(v): return v - 256 if v > 127 else v

def step(n, hold=frozenset()):
    for _ in range(n):
        pressed.clear(); pressed.update(hold)
        poll_c(); lr.retro_run()

def shot(name, zoom=2):
    w, h, p = last['w'], last['h'], last['p']
    a = np.frombuffer(last['buf'], dtype=np.uint8).reshape(h, p)[:, :w*4].reshape(h, w, 4)
    Image.fromarray(a[:,:,:3][:,:,::-1]).resize((w*zoom, h*zoom), Image.NEAREST).save(f'/home/user/nes-test/{name}.png')

B = {'B':0,'START':3,'UP':4,'DOWN':5,'LEFT':6,'RIGHT':7,'A':8}
sys.path.insert(0, '/home/user/nes-test')
from addrs_cb import *

OAM = 0x200
def oam_tile(s):
    return rd(OAM + s*4+1)

fails = []
def check(cond, msg):
    print(('  PASS ' if cond else '  FAIL ') + msg)
    if not cond: fails.append(msg)

print('== titulo ==')
step(150); shot('d2_1_titulo')
step(3, {B['START']}); step(20)

print('== onda 1: 3 smalls, frame estatico, zigzag suave ==')
max_active = 0
max_step = 0
prev = {}  # i -> (x, ativo_frame_anterior)
tiles_seen = set()
for f in range(560):
    hold = {B['LEFT']} if f % 200 < 90 else ({B['RIGHT']} if f % 200 < 180 else frozenset())
    step(1, hold)
    act = [i for i in range(4) if rd(SMA+i)]
    max_active = max(max_active, len(act))
    for i in range(4):
        x = rd(SMX+i)
        if rd(SMA+i):
            if i in prev and prev[i][1]:
                max_step = max(max_step, abs(x - prev[i][0]))
            prev[i] = (x, True)
            tiles_seen.add((oam_tile(4+i*2), oam_tile(5+i*2)))
        else:
            prev[i] = (x, False)
check(max_active == 3, 'onda 1 tem exatamente 3 smalls ativos (max visto: %d)' % max_active)
check(max_step <= 3, 'zigzag fluido: passo x max %d px/frame (<= 3)' % max_step)
check(tiles_seen == {(113, 115)}, 'frame estatico fr13: tiles OAM vistos %s' % tiles_seen)
shot('d2_2_smalls')

print('== balas miradas: nascem no inimigo, miram na nave, matam ==')
prev_act = [rd(EBA+i) for i in range(8)]  # seed p/ nao confundir balas velhas
births = []
li0 = rd(LI)
died_by_bullet = False
for f in range(1500):
    hold = {B['RIGHT']} if f % 300 < 140 else frozenset()
    step(1, hold)
    for i in range(8):
        a = rd(EBA+i)
        if a and not prev_act[i]:
            sm = [(rd(SMX+j), ru16(SMY+j*2)//16-256) for j in range(4) if rd(SMA+j)]
            births.append((ru16(EBX+i*2)/16-256, ru16(EBY+i*2)/16-256, s8(rd(EBXV+i)), s8(rd(EBYV+i)), rd(PX), rd(PY), sm))
        prev_act[i] = a
    if rd(LI) < li0:
        died_by_bullet = True
        print('   morreu! (bala ou contato) li %d -> %d' % (li0, rd(LI)))
        break
match = 0
for bx, by, vx, vy, px, py, sm in births:
    if any(abs(bx - (sx+4)) <= 10 and abs(by - (sy+8)) <= 12 for sx, sy in sm):
        match += 1
check(len(births) >= 4, 'houve %d nascimentos de balas miradas' % len(births))
check(match == len(births), 'balas nascem junto a um small: %d/%d' % (match, len(births)))
aim_ok = 0
for bx, by, vx, vy, px, py, _ in births:
    dx, dy = px - bx, py - by
    horiz_ok = (vx == 0 and abs(dx) < 24) or (vx != 0 and dx != 0 and ((vx > 0) == (dx > 0))) or (vx != 0 and dx == 0)
    vert_ok  = (vy == 0 and abs(dy) < 24) or (vy != 0 and dy != 0 and ((vy > 0) == (dy > 0)))
    if horiz_ok and vert_ok: aim_ok += 1
check(aim_ok == len(births), 'mira 8-dir aponta p/ a nave: %d/%d' % (aim_ok, len(births)))
shot('d2_3_balas')

print('== shards: saida diagonal completa ==')
deathlog = []
exitlog = {i: [] for i in range(4)}
preva = [rd(SHA+i) for i in range(4)]
midcross = 0
for f in range(2200):
    ram[INV] = 90
    step(1)
    for i in range(4):
        a = rd(SHA+i)
        if a and rd(SHF+i) == 1:
            x = rd(SHX+i)
            exitlog[i].append((x, round(ru16(SHY+i*2)/16-256, 1)))
            if 120 <= x <= 136: midcross += 1
        if preva[i] and not a:
            deathlog.append(exitlog[i][-1] if exitlog[i] else None)
            exitlog[i] = []
        preva[i] = a
    if len(deathlog) >= 8: break
ok_lim = all(d and (d[0] >= 240 or d[0] <= 8 or d[1] <= -8) for d in deathlog)
check(len(deathlog) == 8 and ok_lim, 'shards saem so pelos limites: %s' % deathlog)
check(midcross > 0, 'shards cruzam o meio vivos (%d amostras perto de x=128)' % midcross)
shot('d2_4_shards')

print('== anel de 8 ao matar shard + score ==')
ring_ok = False
for f in range(2400):
    ram[INV] = 90
    tgt = None
    for i in range(4):
        if rd(SHA+i): tgt = rd(SHX+i); break
    hold = {B['B']}
    if tgt is not None:
        if rd(PX) + 8 < tgt: hold.add(B['RIGHT'])
        elif rd(PX) + 8 > tgt: hold.add(B['LEFT'])
    step(1, hold)
    vxs = sorted({s8(rd(EBXV+i)) for i in range(8) if rd(EBA+i)})
    if len(vxs) >= 4 and -24 in vxs and 24 in vxs:
        n = sum(rd(EBA+i) for i in range(8))
        ring_pos = [(ru16(EBX+i*2)/16-256, ru16(EBY+i*2)/16-256) for i in range(8) if rd(EBA+i)]
        xs = [p[0] for p in ring_pos]; ys = [p[1] for p in ring_pos]
        spread_ok = max(xs)-min(xs) <= 10 and max(ys)-min(ys) <= 10
        ring_ok = (n == 8 and spread_ok)
        print('   anel: %d balas, centro ~(%.0f,%.0f)' % (n, sum(xs)/8, sum(ys)/8))
        break
check(ring_ok, 'anel de 8 tiros na posicao do shard morto')
shot('d2_5_anel')
sc = ru16(SCORE)
print('   score:', sc)
check(sc >= 120, 'score acumulou (%d)' % sc)

print('== morte por bala inimiga (sem inv) ==')
died = False
for f in range(1500):
    hold = {B['RIGHT']} if f % 250 < 120 else frozenset()
    step(1, hold)
    if rd(DED) > 0:
        died = True
        break
check(died, 'nave explode ao levar bala/contato (li=%d)' % rd(LI))
shot('d2_6_morte')

print()
print('RESULTADO:', 'TUDO OK ✔' if not fails else '%d FALHAS: %s' % (len(fails), fails))
