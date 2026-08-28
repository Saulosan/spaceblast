#!/usr/bin/env python3
# Verificacao v0.6: titulo Space Blast (cores, blink, rodape) + vazamento de atributos no gameplay
import ctypes, sys
from PIL import Image

CORE = "/tmp/cb/fceumm_libretro.so"
ROM  = "/home/user/spaceblast/space-blast.nes"

lib = ctypes.CDLL(CORE)
for f in ("retro_init","retro_load_game","retro_run","retro_unload_game","retro_deinit"):
    getattr(lib, f).restype = None
lib.retro_get_region.restype = ctypes.c_int

FRAMES = []
AUD = []
def _video(data, w, h, pitch):
    if not data: return
    n = w*h*4
    buf = ctypes.string_at(data, n) if pitch == w*4 else b"".join(
        ctypes.string_at(data + r*pitch, w*4) for r in range(h))
    FRAMES.append((w, buf))
def _audio(l, r): AUD.append((l, r))
def _batch(data, frames): return frames
def _input_poll(): pass
PAD = [0]*16
def _input_state(port, dev, idx, i):
    return PAD[i] if port == 0 and i < 16 else 0

VID = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)(_video)
AUDC = ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)(_audio)
BAT = ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)(_batch)
INP = ctypes.CFUNCTYPE(None)(_input_poll)
INS = ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)(_input_state)
lib.retro_set_video_refresh(VID); lib.retro_set_audio_sample(AUDC)
lib.retro_set_audio_sample_batch(BAT); lib.retro_set_input_poll(INP); lib.retro_set_input_state(INS)

ENV = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
def _env(cmd, data):
    if cmd == 10:  # SET_PIXEL_FORMAT
        ctypes.cast(data, ctypes.POINTER(ctypes.c_int))[0] = 1  # XRGB8888
        return True
    if cmd in (11, 16, 17): return True
    return False
ENVC = ENV(_env)
lib.retro_set_environment(ENVC)

class GI(ctypes.Structure):
    _fields_ = [("path", ctypes.c_char_p), ("data", ctypes.c_void_p),
                ("size", ctypes.c_size_t), ("meta", ctypes.c_char_p)]
lib.retro_init()
lib.retro_load_game.argtypes = [ctypes.POINTER(GI)]
lib.retro_load_game.restype = ctypes.c_bool
gi = GI(ROM.encode(), None, 0, None)
assert lib.retro_load_game(ctypes.byref(gi)), "load falhou"

def run(n, start=False, b=False):
    PAD[3] = 1 if start else 0   # START id=3
    PAD[0] = 1 if b else 0
    for _ in range(n): lib.retro_run()
    PAD[3] = 0; PAD[0] = 0

def shot(path):
    w, buf = FRAMES[-1]
    im = Image.frombytes("RGB", (w, 240), buf, "raw", "BGRX")
    im.save(path)
    return im

def colors(im, box, topn=6):
    from collections import Counter
    return Counter(im.crop(box).getdata()).most_common(topn)

run(90)                                    # titulo estabilizada
t1 = shot("/home/user/caravanblast/docs/cb_v06_titulo.png")
# pisca: FRAME AND 16 -> captura em fases diferentes
fr = None
run(8);  shot("/tmp/cb/t blink_a.png")
run(16); shot("/tmp/cb/t blink_b.png")

im = Image.open("/home/user/caravanblast/docs/cb_v06_titulo.png").convert("RGB")
print("SPACE  :", colors(im, (64, 48, 200, 64)))
print("BLAST  :", colors(im, (60, 62, 200, 100)))
print("APERTE :", colors(im, (70, 172, 190, 188)))
print("rodape :", colors(im, (55, 214, 205, 226)))
# bala "•" no centro do rodape (col 12 -> px 96..103, y 216..223)
print("bala   :", colors(im, (96, 216, 104, 224)))

# blink: APERTE some em algum frame?
a = Image.open("/tmp/cb/t blink_a.png").convert("RGB")
b = Image.open("/tmp/cb/t blink_b.png").convert("RGB")
ca = colors(a, (70, 172, 190, 188)); cb = colors(b, (70, 172, 190, 188))
print("blink A:", ca[:2], " B:", cb[:2])

# start -> gameplay: estrelas nao podem estar na faixa teal/ciano do logo
run(2, start=True); run(120)
g = shot("/tmp/cb/t game.png")
print("game   :", colors(g, (64, 48, 200, 96)))  # zona onde estava a logo

lib.retro_unload_game(); lib.retro_deinit()
print("OK")
