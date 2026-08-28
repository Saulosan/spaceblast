#!/usr/bin/env python3
# Harness fceumm p/ Space Blast (recriavel: /tmp nao persiste)
import ctypes, numpy as np
from PIL import Image
BT = {0:0,1:1,'B':0,'Y':1,'SEL':2,'SELECT':2,'START':3,'UP':4,'DOWN':5,'LEFT':6,'RIGHT':7,'A':8}
class RGI(ctypes.Structure):
    _fields_ = [("path",ctypes.c_char_p),("meta",ctypes.c_void_p),("data",ctypes.c_char_p),("size",ctypes.c_size_t)]
class Emu:
    def __init__(self, so='/tmp/cb/fceumm_libretro.so', rom='/home/user/spaceblast/space-blast.nes'):
        L=self.L=ctypes.CDLL(so)
        L.retro_get_memory_data.restype=ctypes.c_void_p
        L.retro_get_memory_size.restype=ctypes.c_size_t
        self.fw,self.fh=256,240; self.frames=[]; self.held=set()
        CF=ctypes.CFUNCTYPE
        self._ve=CF(None,ctypes.c_void_p,ctypes.c_uint,ctypes.c_uint,ctypes.c_size_t)(self._video)
        self._ae=CF(ctypes.c_size_t,ctypes.POINTER(ctypes.c_int16),ctypes.c_size_t)(self._audio)
        self._ie=CF(None)(lambda:None)
        self._ip=CF(ctypes.c_int16,ctypes.c_uint,ctypes.c_uint,ctypes.c_uint,ctypes.c_uint)(self._input)
        self._env=CF(ctypes.c_bool,ctypes.c_uint,ctypes.c_void_p)(self._envcb)
        L.retro_set_environment(self._env); L.retro_set_video_refresh(self._ve)
        L.retro_set_audio_sample_batch(self._ae); L.retro_set_input_poll(self._ie)
        L.retro_set_input_state(self._ip)
        L.retro_init(); L.retro_load_game(ctypes.byref(RGI(rom.encode(),None,None,0)))
    def _envcb(self,cmd,data):
        if cmd==10: return True
        if cmd in (11,16,17): return True
        return False
    def _video(self,buf,w,h,pitch):
        if not buf: return
        a=np.frombuffer(ctypes.string_at(buf,pitch*h),dtype=np.uint8).reshape(h,pitch)[:,:w*4].reshape(h,w,4)
        self.frames.append(a[:,:,[2,1,0]].copy())  # XRGB8888 LE = bytes B,G,R,X -> reverse to RGB
        if len(self.frames)>4: self.frames.pop(0)
    def _audio(self,buf,n): return n
    def _input(self,port,dev,idx,btn): return 1 if (port==0 and btn in self.held) else 0
    def run(self,n=1,keys=()):
        if isinstance(keys,BT.__class__): pass
        kd={BT[k] if isinstance(k,str) else k for k in keys}
        for _ in range(n):
            self.held=self.held|kd; self.L.retro_run()
        self.held-={d for d in kd}
    def shot(self,path=None):
        im=Image.fromarray(self.frames[-1])
        if path: im.save(path)
        return im
    def ram(self):
        a=self.L.retro_get_memory_data(2); n=self.L.retro_get_memory_size(2)
        return (ctypes.c_uint8*n).from_address(a)

def serialize(e, path):
    import ctypes
    n = e.L.retro_serialize_size()
    buf = ctypes.create_string_buffer(n)
    ok = e.L.retro_serialize(buf, n)
    open(path,'wb').write(buf.raw)
    return n, ok

def deserialize(e, path):
    data = open(path,'rb').read()
    buf = ctypes.create_string_buffer(data, len(data))
    return e.L.retro_unserialize(buf, len(data))
