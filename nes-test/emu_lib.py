#!/usr/bin/env python3
"""Small, path-independent libretro harness for Space Blast tests."""
from pathlib import Path
import ctypes
import os

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent
BT = {
    0: 0, 1: 1, 'B': 0, 'Y': 1, 'SEL': 2, 'SELECT': 2, 'START': 3,
    'UP': 4, 'DOWN': 5, 'LEFT': 6, 'RIGHT': 7, 'A': 8,
}


def _default_core():
    configured = os.environ.get('FCEUMM_CORE')
    if configured:
        return Path(configured)
    for candidate in ('/tmp/fceumm_libretro.so', '/tmp/cb/fceumm_libretro.so'):
        path = Path(candidate)
        if path.is_file():
            return path
    return Path('/tmp/fceumm_libretro.so')


class RGI(ctypes.Structure):
    # libretro_game_info: path, data, size, meta
    _fields_ = [
        ('path', ctypes.c_char_p),
        ('data', ctypes.c_void_p),
        ('size', ctypes.c_size_t),
        ('meta', ctypes.c_char_p),
    ]


class Emu:
    def __init__(self, so=None, rom=None):
        core_path = Path(so) if so else _default_core()
        rom_path = Path(rom) if rom else PROJECT / 'spaceblast' / 'space-blast.nes'
        self.L = ctypes.CDLL(str(core_path))
        self.L.retro_get_memory_data.restype = ctypes.c_void_p
        self.L.retro_get_memory_size.restype = ctypes.c_size_t
        self.L.retro_load_game.argtypes = [ctypes.POINTER(RGI)]
        self.L.retro_load_game.restype = ctypes.c_bool
        self.fw, self.fh = 256, 240
        self.frames = []
        self.held = set()

        CF = ctypes.CFUNCTYPE
        self._ve = CF(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint,
                      ctypes.c_size_t)(self._video)
        self._ae = CF(ctypes.c_size_t, ctypes.POINTER(ctypes.c_int16),
                      ctypes.c_size_t)(self._audio)
        self._ie = CF(None)(lambda: None)
        self._ip = CF(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint,
                      ctypes.c_uint, ctypes.c_uint)(self._input)
        self._env = CF(ctypes.c_bool, ctypes.c_uint,
                       ctypes.c_void_p)(self._envcb)
        self.L.retro_set_environment(self._env)
        self.L.retro_set_video_refresh(self._ve)
        self.L.retro_set_audio_sample_batch(self._ae)
        self.L.retro_set_input_poll(self._ie)
        self.L.retro_set_input_state(self._ip)
        self.L.retro_init()
        info = RGI(os.fspath(rom_path).encode(), None, 0, None)
        if not self.L.retro_load_game(ctypes.byref(info)):
            raise RuntimeError(f'cannot load ROM: {rom_path}')

    def _envcb(self, cmd, data):
        # RETRO_ENVIRONMENT_SET_PIXEL_FORMAT = 10, XRGB8888 = 1.
        if cmd == 10:
            ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value = 1
            return True
        if cmd == 11:  # SET_INPUT_DESCRIPTORS
            return True
        if cmd in (16, 17):  # SYSTEM_DIRECTORY / SAVE_DIRECTORY
            return True
        return False

    def _video(self, buf, w, h, pitch):
        if not buf:
            return
        raw = ctypes.string_at(buf, pitch * h)
        a = np.frombuffer(raw, dtype=np.uint8).reshape(h, pitch)
        a = a[:, :w * 4].reshape(h, w, 4)
        # XRGB8888 on little-endian hosts is B,G,R,X.
        self.frames.append(a[:, :, [2, 1, 0]].copy())
        if len(self.frames) > 4:
            self.frames.pop(0)

    @staticmethod
    def _audio(buf, n):
        return n

    def _input(self, port, dev, idx, button):
        return 1 if port == 0 and button in self.held else 0

    def run(self, n=1, keys=()):
        pressed = {BT[k] if isinstance(k, str) else k for k in keys}
        self.held = pressed
        for _ in range(n):
            self.L.retro_run()
        self.held.clear()

    def shot(self, path=None):
        if not self.frames:
            raise RuntimeError('no video frame received')
        im = Image.fromarray(self.frames[-1])
        if path:
            im.save(path)
        return im

    def ram(self):
        address = self.L.retro_get_memory_data(2)
        size = self.L.retro_get_memory_size(2)
        return (ctypes.c_uint8 * size).from_address(address)


def serialize(e, path):
    n = e.L.retro_serialize_size()
    buf = ctypes.create_string_buffer(n)
    ok = e.L.retro_serialize(buf, n)
    Path(path).write_bytes(buf.raw)
    return n, ok


def deserialize(e, path):
    data = Path(path).read_bytes()
    buf = ctypes.create_string_buffer(data, len(data))
    return e.L.retro_unserialize(buf, len(data))
