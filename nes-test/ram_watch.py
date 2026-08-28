import ctypes, os, sys
core = ctypes.CDLL('/tmp/fceumm_libretro.so')
ENVF = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
VIDF = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)
AUDF = ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)
AUDB = ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
INPF = ctypes.CFUNCTYPE(None)
INSF = ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)
def envf(cmd, data):
    if cmd == 10: ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value = 1; return True
    if cmd == 11: ctypes.cast(data, ctypes.POINTER(ctypes.c_bool)).contents.value = True; return True
    if cmd in (16,17): return True
    return False
def vidf(d,w,h,p): pass
def audf(l,r): pass
def audb(d,n): return n
def inpf(): pass
def insf(a,b,c,d): return 0
_cb_env = ENVF(envf); _cb_vid = VIDF(vidf); _cb_aud = AUDF(audf); _cb_audb = AUDB(audb); _cb_inp = INPF(inpf); _cb_ins = INSF(insf)
class RGI(ctypes.Structure):
    _fields_ = [('path', ctypes.c_char_p), ('data', ctypes.c_void_p), ('size', ctypes.c_size_t), ('meta', ctypes.c_char_p)]
core.retro_set_environment(_cb_env); core.retro_set_video_refresh(_cb_vid)
core.retro_set_audio_sample(_cb_aud); core.retro_set_audio_sample_batch(_cb_audb)
core.retro_set_input_poll(_cb_inp); core.retro_set_input_state(_cb_ins)
core.retro_init()
gi = RGI(os.path.abspath(sys.argv[1]).encode(), None, 0, None)
print('load:', core.retro_load_game(ctypes.byref(gi)), flush=True)
core.retro_get_memory_data.restype = ctypes.c_void_p
warm = int(sys.argv[2]) if len(sys.argv) > 2 else 20
steps = int(sys.argv[3]) if len(sys.argv) > 3 else 200
for i in range(warm): core.retro_run()
ram = (ctypes.c_ubyte * 2048).from_address(core.retro_get_memory_data(2))
prev = None
for f in range(steps):
    core.retro_run()
    snap = tuple(int(ram[a]) for a in [0x36,0x37,0x38,0x39,0x42,0x43,0x48,0x3a,0x3b,0x44,0x45,0x49,0x3d,0x3e,0x46,0x47,0x4a,0x4d,0x4e,0x31])
    if snap != prev:
        print(f'f{f:3d} tick={snap[17]} cnt={snap[0]:2d} | ch1 i=${snap[1]:02x} n={snap[2]:2d} c={snap[3]} f=${snap[5]:02x}{snap[4]:02x} v=${snap[6]:02x} | ch2 i=${snap[7]:02x} n={snap[8]:2d} f=${snap[10]:02x}{snap[9]:02x} v=${snap[11]:02x} | ch3 i=${snap[12]:02x} n={snap[13]:2d} f=${snap[15]:02x}{snap[14]:02x} v=${snap[16]:02x} | mode={snap[18]} tim={snap[19]}', flush=True)
        prev = snap
