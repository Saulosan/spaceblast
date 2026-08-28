#!/usr/bin/env python3
# Captura audio do fceumm via libretro -> WAV. Uso: cap_audio.py jogo.nes saida.wav frames
import ctypes, sys, os
import numpy as np

core_path = '/tmp/fceumm_libretro.so'
rom = sys.argv[1]; out = sys.argv[2]; nframes = int(sys.argv[3]) if len(sys.argv) > 3 else 600

core = ctypes.CDLL(core_path)

ENV_SET_PIXEL_FORMAT = 10
ENV_GET_CAN_DUPE = 11
ENV_SET_INPUT_DESCRIPTORS = 16
ENV_SET_SUPPORT_NO_GAME = 17

av_info_holder = {}

class retro_game_geometry(ctypes.Structure):
    _fields_ = [('base_width', ctypes.c_uint), ('base_height', ctypes.c_uint),
                ('max_width', ctypes.c_uint), ('max_height', ctypes.c_uint),
                ('aspect_ratio', ctypes.c_float)]
class retro_system_timing(ctypes.Structure):
    _fields_ = [('fps', ctypes.c_double), ('sample_rate', ctypes.c_double)]
class retro_system_av_info(ctypes.Structure):
    _fields_ = [('geometry', retro_game_geometry), ('timing', retro_system_timing)]
class retro_game_info(ctypes.Structure):
    _fields_ = [('path', ctypes.c_char_p), ('data', ctypes.c_void_p),
                ('size', ctypes.c_size_t), ('meta', ctypes.c_char_p)]

ENVFUNC = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
VIDFUNC = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)
AUDFUNC = ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)
AUDIVFUNC = ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
INPOLLFUNC = ctypes.CFUNCTYPE(None)
INSTATEFUNC = ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)

pcm = []

def env_cb(cmd, data):
    if cmd == ENV_SET_PIXEL_FORMAT:
        ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value = 1  # XRGB8888
        return True
    if cmd == ENV_GET_CAN_DUPE:
        ctypes.cast(data, ctypes.POINTER(ctypes.c_bool)).contents.value = True
        return True
    if cmd in (ENV_SET_INPUT_DESCRIPTORS, ENV_SET_SUPPORT_NO_GAME):
        return True
    return False

def vid_cb(data, w, h, pitch):
    pass

def aud_cb(l, r):
    pcm.append(np.array([l, r], dtype=np.int16))

def audb_cb(data, frames):
    arr = np.ctypeslib.as_array(ctypes.cast(data, ctypes.POINTER(ctypes.c_int16)), shape=(frames*2,))
    pcm.append(arr.copy())
    return frames

def inp_cb():
    pass

def inst_cb(port, dev, idx, id_):
    return 0

env = ENVFUNC(env_cb); vid = VIDFUNC(vid_cb); aud = AUDFUNC(aud_cb)
audb = AUDIVFUNC(audb_cb); ipoll = INPOLLFUNC(inp_cb); istate = INSTATEFUNC(inst_cb)

core.retro_set_environment.restype = None
core.retro_set_environment(env)
core.retro_set_video_refresh(vid)
core.retro_set_audio_sample(aud)
core.retro_set_audio_sample_batch(audb)
core.retro_set_input_poll(ipoll)
core.retro_set_input_state(istate)
core.retro_init()

gi = retro_game_info(os.path.abspath(rom).encode(), None, 0, None)
if not core.retro_load_game(ctypes.byref(gi)):
    print('falha ao carregar ROM'); sys.exit(1)

av = retro_system_av_info()
core.retro_get_system_av_info(ctypes.byref(av))
print(f'fps={av.timing.fps:.4f} sr={av.timing.sample_rate:.0f}')

for i in range(nframes):
    core.retro_run()

core.retro_unload_game()
core.retro_deinit()

if pcm:
    allp = np.concatenate(pcm)
    sr = int(av.timing.sample_rate)
    import wave
    w = wave.open(out, 'wb')
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
    w.writeframes(allp.astype('<i2').tobytes()); w.close()
    print(f'WAV: {out}  {len(allp)/sr:.2f}s')
else:
    print('sem audio capturado!')
