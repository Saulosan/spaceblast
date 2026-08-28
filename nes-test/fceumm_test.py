#!/usr/bin/env python3
# Ground truth: roda o Cata-Estrelas no core libretro fceumm (preciso),
# captura telas e ainda testa input + leitura/escrita de RAM.
import ctypes, sys
import numpy as np
from PIL import Image

CORE = '/tmp/fceumm_libretro.so'
ROM = '/home/user/cata-estrelas/cata-estrelas.nes'

lr = ctypes.CDLL(CORE)

# --- tipos de callback ---
ENV_CB   = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
VIDEO_CB = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)
AUDIO_CB = ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)
AUDIOB_CB= ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
POLL_CB  = ctypes.CFUNCTYPE(None)
STATE_CB = ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)

last_frame = {'buf': None, 'w': 0, 'h': 0, 'pitch': 0}
input_state = set()   # ids pressionados

def env(cmd, data):
    if cmd == 10:  # SET_PIXEL_FORMAT -> pede XRGB8888 (enum valor 1)
        ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value = 1
        return True
    if cmd == 15:  # GET_VARIABLE -> deixa defaults
        return False
    if cmd == 17:  # GET_VARIABLE_UPDATE -> False
        ctypes.cast(data, ctypes.POINTER(ctypes.c_bool)).contents.value = False
        return True
    if cmd in (9, 19, 31):  # GET_SYSTEM_DIRECTORY / GET_LIBRETRO_PATH / GET_CORE_ASSETS_DIRECTORY
        s = ctypes.create_string_buffer(b'/tmp')
        ctypes.memmove(data, ctypes.cast(s, ctypes.c_void_p).value, ctypes.sizeof(ctypes.c_char_p)) if False else None
        # mais seguro: escrever o ponteiro na struct
        ctypes.cast(data, ctypes.POINTER(ctypes.c_char_p)).contents.value = b'/tmp'
        return True
    if cmd in (11, 16):  # SET_INPUT_DESCRIPTORS / SET_VARIABLES
        return True
    return False

def video(data, w, h, pitch):
    if data:
        last_frame['buf'] = ctypes.string_at(data, pitch * h)
        last_frame['w'], last_frame['h'], last_frame['pitch'] = w, h, pitch

def audio(l, r):
    pass

def audiob(data, frames):
    return frames

def poll():
    pass

def state(port, device, index, id):
    if port == 0 and id in input_state:
        return 1
    return 0

env_c, video_c, audio_c, audiob_c, poll_c, state_c = (
    ENV_CB(env), VIDEO_CB(video), AUDIO_CB(audio), AUDIOB_CB(audiob), POLL_CB(poll), STATE_CB(state))

lr.retro_set_environment(env_c)
lr.retro_set_video_refresh(video_c)
lr.retro_set_audio_sample(audio_c)
lr.retro_set_audio_sample_batch(audiob_c)
lr.retro_set_input_poll(poll_c)
lr.retro_set_input_state(state_c)

class RetroGameInfo(ctypes.Structure):
    _fields_ = [("path", ctypes.c_char_p), ("data", ctypes.c_void_p),
                ("size", ctypes.c_size_t), ("meta", ctypes.c_char_p)]

lr.retro_init()
gi = RetroGameInfo(ROM.encode(), None, 0, None)
if not lr.retro_load_game(ctypes.byref(gi)):
    print('falha ao carregar ROM'); sys.exit(1)
lr.retro_set_controller_port_device(0, 1)  # RETRO_DEVICE_JOYPAD

lr.retro_get_memory_data.restype = ctypes.c_void_p
lr.retro_get_memory_size.restype = ctypes.c_size_t
ram_size = lr.retro_get_memory_size(2)
ram_ptr = lr.retro_get_memory_data(2)
print('RAM:', ram_size, 'bytes @', hex(ram_ptr) if ram_ptr else None)
ram = (ctypes.c_ubyte * ram_size).from_address(ram_ptr) if ram_ptr else None

def run(n):
    for _ in range(n):
        poll_c()
        lr.retro_run()

def press(ids, n):
    input_state.update(ids)
    run(n)
    input_state.difference_update(ids)

BTN = {'B':0,'Y':1,'SELECT':2,'START':3,'UP':4,'DOWN':5,'LEFT':6,'RIGHT':7,'A':8,'X':9}

def shot(name):
    w, h, pitch = last_frame['w'], last_frame['h'], last_frame['pitch']
    arr = np.frombuffer(last_frame['buf'], dtype=np.uint8).reshape(h, pitch)[:, :w*4]
    arr = arr.reshape(h, w, 4)[:, :, :3][:, :, ::-1]  # XRGB8888 -> RGB
    Image.fromarray(arr).resize((w*2, h*2), Image.NEAREST).save(f'/home/user/nes-test/{name}.png')
    print('shot', name, w, 'x', h)

def rd(a): return ram[a]
def wr(a, v): ram[a] = v

# --- roteiro do teste ---
run(150)
shot('gt_1_titulo')

press({BTN['START']}, 3)
run(150)
shot('gt_2_jogo_hud')

run(250)
shot('gt_3_meteoros')

# move a nave (esquerda 40f, sobe 20f)
press({BTN['LEFT']}, 40)
press({BTN['UP']}, 20)
run(200)
shot('gt_4_moveu')

# força colisão: iguala px da nave ao x de um meteoro visível
# cvb_PX=$5d, cvb_PY=$5e, mx=$8c..$8f, #my=$60..$67 (16-bit)
best = -1
for c in range(4):
    my = rd(0x60 + 2*c) | (rd(0x61 + 2*c) << 8)
    if my > 32767: my -= 65536
    if 30 < my < 180:
        best = c; break
print('meteoro alvo:', best, 'mx:', rd(0x8c+best) if best >= 0 else None)
if best >= 0:
    wr(0x5d, rd(0x8c + best))   # px = mx(c)
run(30)
shot('gt_5_explosao')
run(150)
shot('gt_6_gameover')

press({BTN['START']}, 3)
run(90)
shot('gt_7_volta_titulo')
print('FIM')
